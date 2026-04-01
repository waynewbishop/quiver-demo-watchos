// Copyright 2026 Wayne W Bishop. All rights reserved.
// Licensed under the Apache License, Version 2.0.

import Foundation
import Quiver

// Quiver Demo — Multi-Signal Running Simulation
//
// Most fitness watches classify effort by heart rate alone.
// Quiver uses K-Nearest Neighbors (KNN) trained on four sensor
// signals — heart rate, cadence, pace, and elevation — to
// classify true effort. This reveals when a hill inflates HR
// beyond the actual effort: HR 160 on a downhill is "Easy,"
// not "Tempo." PersonalBaseline provides the statistical
// foundation using percentile(), mean(), and std() to build
// zones from the runner's own history instead of generic formulas.
// All computation runs on-device in under 2 MB with zero dependencies.

struct Segment {
    let hr: Double, cadence: Double, pace: Double, elevation: Double
}

// PersonalBaseline builds zones from the runner's own data —
// not age-based formulas or factory defaults. Quiver's percentile()
// creates thresholds unique to each individual, and percentileRank()
// tells exactly where each reading falls in personal history.
struct PersonalBaseline: Codable {
    let readings: [Double]
    let mean: Double
    let std: Double
    let thresholds: [Double]

    // Build a personal baseline from historical readings using Quiver's
    // mean(), std(), and percentile() — unique to each runner
    init(readings: [Double]) {
        self.readings = readings
        self.mean = readings.mean() ?? 0
        self.std = readings.std() ?? 0
        self.thresholds = [20, 40, 60, 80].compactMap { readings.percentile($0) }
    }

    // Assign a zone (0-4) based on where the value falls relative
    // to the personalized percentile thresholds
    func classify(_ value: Double) -> Int {
        for (index, threshold) in thresholds.enumerated() {
            if value < threshold { return index }
        }
        return thresholds.count
    }

    // How many standard deviations from the runner's personal mean —
    // values beyond ±2 are statistical outliers
    func zScore(_ value: Double) -> Double {
        guard std > 0 else { return 0 }
        return (value - mean) / std
    }
}

@MainActor
@Observable
final class RunningModel {

    var bpm: Int = 0
    var zone: Int = 0
    var zoneName: String { Self.zones[min(zone, 4)] }
    var pctRank: Double = 0
    var zScore: Double = 0

    var hrLabel: String = "---"
    var effortLabel: String = "---"
    var disagrees: Bool = false

    var isRunning = false

    private var baseline: PersonalBaseline?
    private var effortKnn: KNearestNeighbors?
    private var effortScaler: FeatureScaler?
    private var segments: [Segment] = []
    private var readingIndex = 0
    private var task: Task<Void, Never>?

    static let zones = ["Recovery", "Warm-up", "Aerobic", "Threshold", "Peak"]
    static let efforts = ["Easy", "Moderate", "Tempo", "Hard"]

    // Initialize the simulation, build the PersonalBaseline from
    // simulated HR data, and train the multi-signal KNN effort model
    func start() {
        segments = simulate()
        let heartRates = segments.map(\.hr)

        // Zones derived from the runner's actual distribution —
        // no fixed 220-minus-age formula like traditional watches
        let newBaseline = PersonalBaseline(readings: heartRates)
        baseline = newBaseline

        // Quiver trains a multi-signal classifier on 4 inputs simultaneously.
        // Traditional watches use HR alone — Quiver sees cadence, pace,
        // and elevation together, distinguishing a hard flat effort
        // from an easy downhill at the same heart rate.
        let train: [[Double]] = [[130,165,6.5,0],[135,168,6.2,0],[128,162,6.8,-1],[150,172,5.5,1],[155,174,5.3,1.5],[148,170,5.8,0.5],[160,165,6.5,-3],[158,163,6.8,-2.5],[162,167,6.2,-2],[170,180,4.8,0],[175,182,4.5,0.5],[172,178,4.6,0]]

        // FeatureScaler normalizes all signals to the same range —
        // without it, HR (130-175) would dominate cadence (162-182)
        let scaler = FeatureScaler.fit(features: train)
        effortScaler = scaler
        effortKnn = KNearestNeighbors.fit(
            features: scaler.transform(train),
            labels: [0,0,0,1,1,1,0,0,0,3,3,3], k: 3)

        readingIndex = 0; isRunning = true
        task = Task {
            while !Task.isCancelled {
                process()
                try? await Task.sleep(for: .milliseconds(1500))
            }
        }
    }

    // End the simulation loop
    func stop() { task?.cancel(); task = nil; isRunning = false }

    // Process each simulated reading — classify by HR zone using
    // PersonalBaseline, then classify by true effort using multi-signal KNN
    private func process() {
        guard let baseline else { return }
        let segment = segments[readingIndex % segments.count]
        readingIndex += 1
        bpm = Int(segment.hr)

        // Personal percentile rank — not a generic population chart,
        // but where this reading falls in this runner's own history
        pctRank = baseline.readings.percentileRank(of: segment.hr)
        zScore = baseline.zScore(segment.hr)
        zone = baseline.classify(segment.hr)

        let hrZone = min(zone, Self.efforts.count - 1)
        hrLabel = Self.efforts[hrZone]

        // Multi-signal classification — the key Quiver differentiator.
        // FeatureScaler normalizes the 4 sensor inputs to the same range,
        // then KNN finds the 3 closest training examples in that scaled
        // space and votes on effort level. Because the model sees pace
        // and elevation alongside HR, it classifies HR 160 on a downhill
        // as "Easy" — something single-signal HR zones cannot do.
        if let scaler = effortScaler, let model = effortKnn {
            let scaled = scaler.transform([[segment.hr, segment.cadence, segment.pace, segment.elevation]])
            let effort = model.predict(scaled)[0]
            effortLabel = Self.efforts[effort]
            disagrees = (hrZone != effort)
        }
    }

    // Simulated sensor data for demo purposes — in a real app,
    // these readings would come from HealthKit (heart rate, cadence,
    // running speed, elevation) during a live workout session.
    // Two phases mimic a typical run: easy warmup and hard tempo
    // with varied terrain, shuffled to create realistic transitions.
    private func simulate() -> [Segment] {
        var results: [Segment] = []
        for _ in 0..<60 { results.append(Segment(hr: .random(in: 125...142), cadence: .random(in: 162...170), pace: .random(in: 6.0...6.8), elevation: .random(in: -0.5...0.5))) }
        for _ in 0..<60 { results.append(Segment(hr: .random(in: 155...178), cadence: .random(in: 172...184), pace: .random(in: 4.5...5.5), elevation: .random(in: -3.0...4.0))) }
        return results.shuffled()
    }
}
