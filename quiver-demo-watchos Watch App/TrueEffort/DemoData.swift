// Copyright 2026 Wayne W Bishop. All rights reserved.
// Licensed under the Apache License, Version 2.0.

import Foundation

// MARK: - Demo data

// Sample inputs for the demo, kept apart from the True Effort Score algorithm
// so the model reads as a single self-contained struct. In a real app the
// labeled history comes from a runner's confirmed efforts and the live session
// comes from HealthKit; here both are generated so the demo runs with no device
// and no data entry. Nothing here is part of the algorithm.
enum DemoData {

    // The runner's labeled history — the Run that TES fits on. Each moment
    // carries its confirmed effort label, so the baseline learns expected HR
    // from the workload and the classifier learns the effort levels. The
    // downhill rows earn the classifier its place: high heart rate, fast pace,
    // steep negative grade, yet labeled Easy because every other signal says so.
    //                  hr  pace  cad  grade vertOsc  alt   label
    static let history: Run = [
        Segment(hr: 130, pace: 6.5, cadence: 165, grade:  0.0, vertOsc: 8.5, altitude: 1600, label: 0), // Easy — flat, slow
        Segment(hr: 135, pace: 6.2, cadence: 168, grade:  0.0, vertOsc: 8.3, altitude: 1610, label: 0), // Easy — flat
        Segment(hr: 128, pace: 6.8, cadence: 162, grade: -1.0, vertOsc: 9.0, altitude: 1620, label: 0), // Easy — downhill
        Segment(hr: 160, pace: 6.5, cadence: 165, grade: -3.0, vertOsc: 9.2, altitude: 1630, label: 0), // Easy — steep downhill (HR inflated)
        Segment(hr: 158, pace: 6.8, cadence: 163, grade: -2.5, vertOsc: 9.4, altitude: 1640, label: 0), // Easy — steep downhill (HR inflated)
        Segment(hr: 150, pace: 5.5, cadence: 172, grade:  1.0, vertOsc: 8.0, altitude: 1660, label: 1), // Steady — slight climb
        Segment(hr: 148, pace: 5.8, cadence: 170, grade:  0.5, vertOsc: 8.1, altitude: 1670, label: 1), // Steady — rolling
        Segment(hr: 155, pace: 5.3, cadence: 174, grade:  1.5, vertOsc: 7.9, altitude: 1690, label: 2), // Tempo — climbing
        Segment(hr: 158, pace: 5.0, cadence: 176, grade:  1.0, vertOsc: 7.6, altitude: 1700, label: 2), // Tempo — fast
        Segment(hr: 170, pace: 4.8, cadence: 180, grade:  0.0, vertOsc: 7.0, altitude: 1720, label: 3), // Hard — fast, flat
        Segment(hr: 175, pace: 4.5, cadence: 182, grade:  0.5, vertOsc: 6.8, altitude: 1730, label: 3), // Hard — fast, slight climb
        Segment(hr: 172, pace: 4.6, cadence: 178, grade:  0.0, vertOsc: 7.1, altitude: 1740, label: 3), // Hard — fast, flat
    ]

    // A simulated live run — unlabeled, the way HealthKit delivers it. In a real
    // app these come from the watch during a run, reading barometric altitude
    // alongside the other signals. Two phases — easy warmup, then hard tempo with
    // varied terrain — shuffled to create realistic transitions. Altitude climbs
    // from roughly 1600 m to 1750 m, so the baseline has real elevation variation.
    static func simulatedSession() -> Run {
        var results: Run = []
        let start = 1600.0, gain = 150.0   // metres climbed over the session

        // Phase 1: easy warmup — low HR, relaxed cadence, slow pace, lower route.
        for i in 0..<60 {
            let altitude = start + gain * (Double(i) / 120.0)
            results.append(Segment(
                hr: .random(in: 125...142), pace: .random(in: 6.0...6.8),
                cadence: .random(in: 162...170), grade: .random(in: -0.5...0.5),
                vertOsc: .random(in: 8.2...9.0), altitude: altitude))
        }

        // Phase 2: hard tempo — high HR, fast cadence, varied terrain (including
        // steep downhills that inflate HR above true effort), higher on the climb.
        for i in 60..<120 {
            let altitude = start + gain * (Double(i) / 120.0)
            results.append(Segment(
                hr: .random(in: 155...178), pace: .random(in: 4.5...5.5),
                cadence: .random(in: 172...184), grade: .random(in: -3.0...4.0),
                vertOsc: .random(in: 6.8...7.6), altitude: altitude))
        }

        return results.shuffled()
    }
}
