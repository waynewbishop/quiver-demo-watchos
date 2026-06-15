// Copyright 2026 Wayne W Bishop. All rights reserved.
// Licensed under the Apache License, Version 2.0.

import Foundation
import Quiver

// RunningModel is the app's view-model — the glue between the True Effort Score
// algorithm and the SwiftUI views. It is not part of the model itself: it owns
// the live session loop, fits the two TES models at launch, and publishes the
// readouts the watch face binds to.
//
// On `start()` it builds both baselines and the classifier, then streams
// simulated samples on a timer; `process()` runs each sample through the model
// and updates the published outputs. In a real app the stream would come from
// HealthKit instead of `DemoData`, but nothing else here would change.
@MainActor
@Observable
final class RunningModel {

    // -- Outputs the views read (UI contract) -------------------------------

    var bpm: Int = 0
    var zone: Int = 0
    var zoneName: String { Self.zones[min(zone, 4)] }

    var hrLabel: String = "---"
    var effortLabel: String = "---"
    var disagrees: Bool = false

    // Residual screen: observed HR, the baseline's expected HR, and the gap
    // between them. The gap is the headline diagnostic — a positive gap (HR
    // running hotter than the workload explains) points to an inflating effect
    // like heat, drift, or altitude; a negative gap means HR is running cooler
    // than the work, as on a steep downhill where the legs carry the load.
    var expectedBpm: Int = 0
    var residual: Int = 0

    // The session's True Effort Score so far. Anchored so one hour held at
    // threshold reads about 100; the number climbs with intensity and time.
    var score: Int = 0

    var isRunning = false

    // -- Internals ----------------------------------------------------------
    // These are not view-bound, so they sit outside observation tracking.
    // The views read the published outputs above, never these directly.

    @ObservationIgnored private var hrBaseline: PersonalBaseline?
    @ObservationIgnored private var tes: TrueEffortScore? = nil
    @ObservationIgnored private var segments: Run = []
    @ObservationIgnored private var liveRun: Run = []
    @ObservationIgnored private var readingIndex = 0
    @ObservationIgnored private var task: Task<Void, Never>?

    static let zones = ["Recovery", "Warm-up", "Aerobic", "Threshold", "Peak"]

    // Fit the effort model from the runner's history, then start streaming a
    // simulated live run against it.
    func start() {
        segments = DemoData.simulatedSession()

        // HR zones from the runner's own distribution (zone screen).
        hrBaseline = PersonalBaseline(readings: segments.map(\.hr))

        // Fit the model once from the runner's labeled history — Quiver's
        // fit-returns-an-immutable-value idiom. The baseline learns expected HR
        // from the workload; the classifier learns effort from the labeled
        // moments. Re-fitting later is the same call on a larger history.
        tes = try? TrueEffortScore.fit(history: DemoData.history)

        liveRun = []; readingIndex = 0; isRunning = true
        task = Task {
            while !Task.isCancelled {
                process()
                try? await Task.sleep(for: .milliseconds(1500))
            }
        }
    }

    // End the simulation loop.
    func stop() { task?.cancel(); task = nil; isRunning = false }

    // Process each simulated reading: append it to the live run, re-score the
    // run so far against the fitted model, and publish the readouts the views
    // bind to.
    private func process() {
        guard let hrBaseline, let tes else { return }
        let segment = segments[readingIndex % segments.count]
        readingIndex += 1
        liveRun.append(segment)
        bpm = Int(segment.hr)

        // HR-zone classification (zone screen).
        zone = hrBaseline.classify(segment.hr)
        let hrEffort = min(zone, EffortLevel.allCases.count - 1)
        hrLabel = EffortLevel(clamping: hrEffort).label

        // True effort for this moment, for the effort screen and disagreement.
        let trueEffort = tes.effort(for: segment)
        effortLabel = trueEffort.label

        // Score the run so far. The result carries the True Effort Score and
        // the latest moment's residual diagnostic — observed HR against the
        // rate the workload predicts.
        let result = tes.score(for: liveRun)
        score = Int(result.value.rounded())
        expectedBpm = Int(result.expectedHeartRate.rounded())
        residual = bpm - expectedBpm

        // Disagreement: HR zone says one thing, the multi-signal model says
        // another — the case the demo is built to show. A steep downhill reads
        // easy by HR while the legs work hard; a power hike reads hard by HR
        // while the slow grind up a steep grade tells the fuller story.
        disagrees = (hrEffort != trueEffort.rawValue)
    }
}
