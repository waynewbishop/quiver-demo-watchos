// Copyright 2026 Wayne W Bishop. All rights reserved.
// Licensed under the Apache License, Version 2.0.

import Foundation
import Quiver

// Quiver Demo — True Effort Score (TES)
//
// Most platforms reduce a workout to one signal — heart rate — and a
// formula. TES keeps the signals together and asks a different question:
// given everything the body is doing, how does this moment compare to what
// THIS runner's own baseline would expect?
//
// Two Quiver models, each owning a different way heart rate misleads:
//   • Ridge BASELINE predicts expected HR from the external workload. A
//     ResidualModel wraps that baseline and reports the residual
//     (observed − expected), catching the INFLATING effects — heat, cardiac
//     drift, altitude — that push HR up without more effort.
//   • KNN CLASSIFIER labels each moment Easy/Steady/Tempo/Hard. It catches
//     the MASKING effects — a downhill keeps HR high while the legs
//     coast, and the sample lands near past downhill efforts regardless.
//
// Ridge (not plain least-squares) because the workload signals are
// correlated; the L2 penalty keeps the on-device fit from going singular.
// StandardScaler is mandatory — the signals live on wildly different scales.
// Everything runs on the wrist in pure Swift with zero dependencies.

// A run is a sequence of recorded moments — the unit TES fits on and scores.
typealias Run = [Segment]

// What `score(for:)` returns: the True Effort Score itself, plus the residual
// diagnostic that reads heart rate in context alongside it.
struct ScoreResult {
    // The True Effort Score: a time-weighted load anchored so one hour held at
    // threshold reads about 100. Climbs with intensity and time; no ceiling.
    let value: Double

    // The most recent moment's residual — observed minus expected HR. Positive
    // means HR is running hotter than the workload explains. A diagnostic
    // displayed alongside the score, not an input to it.
    let residual: Double

    // The most recent moment's expected HR from the baseline, for display.
    let expectedHeartRate: Double
}

// TES follows Quiver's model idiom: `fit` returns a finished, immutable value,
// you `score` runs against it, and you re-`fit` on a grown history as new runs
// land. The baseline and classifier are trained on separate supervision signals
// (expected heart rate and confirmed effort labels), so each is fit on its own;
// the models never fuse.
struct TrueEffortScore {

    // PERSONALIZED BASELINE, wrapped so the residual is one call. The Ridge
    // model predicts expected HR from the standardized workload; ResidualModel
    // holds it and reports observed − predicted. Both are immutable once fit.
    private let residualModel: ResidualModel<Ridge>?
    private let baselineScaler: StandardScaler?

    // EFFORT CLASSIFIER. Bundled with its scaler in a Pipeline so the two are
    // applied together and can never drift apart.
    private let classifier: Pipeline<KNearestNeighbors>?

    // Private memberwise init — a model is only created through `fit`, which
    // guarantees both halves are trained before the value exists.
    private init(residualModel: ResidualModel<Ridge>?,
                 baselineScaler: StandardScaler?,
                 classifier: Pipeline<KNearestNeighbors>?) {
        self.residualModel = residualModel
        self.baselineScaler = baselineScaler
        self.classifier = classifier
    }

    // Fit a trained model from a runner's recorded history. Following Quiver's
    // model idiom, this returns a finished, immutable value with no unfitted
    // window to misuse. Call it again on a larger history to re-fit as the
    // runner logs more runs.
    //
    // The baseline trains on every moment's HR; the classifier trains on the
    // moments that carry a confirmed effort label. A history with no labeled
    // moments still yields a working baseline, with the classifier absent until
    // confirmed efforts arrive.
    static func fit(history: Run, lambda: Double = 1.0, k: Int = 3) throws
        -> TrueEffortScore {

        // Personalized baseline: Ridge over the standardized workload signals,
        // wrapped in a ResidualModel so the residual is a single call.
        var fittedResidual: ResidualModel<Ridge>?
        var fittedScaler: StandardScaler?
        if !history.isEmpty {
            let features = history.map(\.baselineFeatures)
            let heartRates = history.map(\.hr)
            let scaler = StandardScaler.fit(features: features)
            fittedScaler = scaler
            let baseline = try Ridge.fit(
                features: scaler.transform(features),
                targets: heartRates, lambda: lambda)
            fittedResidual = ResidualModel(model: baseline)
        }

        // Effort classifier: trains only on the labeled moments. Its Pipeline
        // fits its own StandardScaler so queries are scaled the same way.
        let labeled = history.filter { $0.label != nil }
        var fittedClassifier: Pipeline<KNearestNeighbors>?
        if !labeled.isEmpty {
            fittedClassifier = Pipeline<KNearestNeighbors>.fit(
                features: labeled.map(\.classifierFeatures),
                labels: labeled.map { $0.label ?? 0 }, k: k)
        }

        return TrueEffortScore(
            residualModel: fittedResidual,
            baselineScaler: fittedScaler,
            classifier: fittedClassifier)
    }

    // Score a run against this fitted model. Each moment is classified and
    // accumulated into the time-weighted load; the result carries the final
    // score plus the last moment's residual diagnostic.
    func score(for run: Run, sampleInterval: Double = 1.5) -> ScoreResult {
        var session = Session()
        for sample in run {
            session.record(effort(for: sample), deltaTime: sampleInterval)
        }
        let last = run.last
        return ScoreResult(
            value: session.adjustedScore,
            residual: last.map { residual(for: $0) } ?? 0,
            expectedHeartRate: last.map { expectedHeartRate(for: $0) } ?? 0)
    }

    // -- Per-moment reads ---------------------------------------------------

    // Expected HR for one sample — what this runner's baseline predicts for
    // these conditions. Returns the observed HR (residual 0) before training.
    func expectedHeartRate(for s: Segment) -> Double {
        guard let residualModel, let scaler = baselineScaler else { return s.hr }
        return residualModel.expected(scaler.transform([s.baselineFeatures]))[0]
    }

    // observed − expected, read through the ResidualModel wrapper. Positive
    // means HR is running hotter than the workload explains — an inflating
    // effect (heat, drift, altitude).
    func residual(for s: Segment) -> Double {
        guard let residualModel, let scaler = baselineScaler else { return 0 }
        let scaled = scaler.transform([s.baselineFeatures])[0]
        return residualModel.residual(features: scaled, observed: s.hr)
    }

    // The classifier's effort label for one moment, with a coarse HR-only
    // fallback before the classifier exists.
    func effort(for s: Segment) -> EffortLevel {
        if let classifier {
            return EffortLevel(clamping: classifier.predict([s.classifierFeatures])[0])
        }
        return EffortLevel(clamping: Int(s.hr / 45))
    }

    // Render the fitted baseline as readable math — the anti-black-box.
    var baselineExpression: String? {
        residualModel.map { $0.coefficients.asExpression(form: .inline) }
    }
}

// MARK: - Session accumulator

// The streaming side of TES: a session grows one classified moment at a time
// and turns the sequence into a score. Kept separate from the trained model so
// the model stays a pure immutable value and the mutable run state lives here.
private struct Session {

    // The threshold anchor: one hour held at threshold defines a score of 100.
    // Tempo is that level, and the reference is one hour in seconds.
    private static let thresholdWeight = EffortLevel.tempo.weight
    private static let anchorSeconds = 3600.0

    // Samples to skip before reading effort variance, so the warmup ramp isn't
    // read as surginess. A full implementation skips ~5 minutes of stabilizing
    // heart rate; scaled here to the demo's shorter session.
    private static let warmupSamples = 10

    // One classified moment: its effort level and how long it lasted.
    private struct Moment { let level: EffortLevel; let deltaTime: Double }
    private var log: [Moment] = []

    // Record one classified moment into the running session.
    mutating func record(_ level: EffortLevel, deltaTime: Double) {
        guard deltaTime > 0 else { return }
        log.append(Moment(level: level, deltaTime: deltaTime))
    }

    // The base load: each moment's effort weight times how long it lasted, so a
    // hard second counts for more than an easy one and a long stretch counts
    // for more than a brief one.
    private var accumulatedLoad: Double {
        log.reduce(0) { $0 + $1.level.weight * $1.deltaTime }
    }

    // The raw True Effort Score: the base load expressed against a fixed
    // one-hour-at-threshold reference, so one hour held at threshold reads 100.
    // Climbs with intensity and time and has no ceiling.
    var currentScore: Double {
        (accumulatedLoad / (Self.thresholdWeight * Self.anchorSeconds)) * 100.0
    }

    // The effort level of each logged moment, as a number from 0 (Easy) to
    // 3 (Hard). The three session-level terms below all read from this.
    private var effortClasses: [Double] {
        log.map { Double($0.level.rawValue) }
    }

    // Variance term: intervals cost more than a steady run of equal average
    // intensity. The warmup samples are dropped so the opening ramp is not
    // read as surginess. Capped so a varied session cannot run away.
    private var varianceMultiplier: Double {
        let steadyState = Array(effortClasses.dropFirst(Self.warmupSamples))
        let variance = steadyState.variance() ?? 0
        return 1.0 + min(0.35, variance * 0.25)
    }

    // Duration term: a gentle, capped fatigue surcharge that only begins past
    // forty-five minutes, so intensity carries the main load.
    private var durationFactor: Double {
        let minutes = log.reduce(0) { $0 + $1.deltaTime } / 60
        guard minutes > 45 else { return 1.0 }
        return 1.0 + 0.1 * Foundation.log(minutes / 45)
    }

    // Transition term: an abrupt surge — a jump of two or more effort levels
    // between consecutive moments — carries a neuromuscular cost a smooth
    // change does not. Sum the size of every such jump.
    private var transitionLoad: Double {
        let jumps = zip(effortClasses, effortClasses.dropFirst())
            .map { abs($1 - $0) }
        return jumps.filter { $0 >= 2 }.reduce(0, +)
    }

    // The adjusted score folds the three session-level terms onto the base
    // load: costs that exist across the whole sequence, not in any one sample.
    var adjustedScore: Double {
        guard !log.isEmpty else { return 0 }
        return currentScore * varianceMultiplier * durationFactor + transitionLoad * 0.1
    }
}
