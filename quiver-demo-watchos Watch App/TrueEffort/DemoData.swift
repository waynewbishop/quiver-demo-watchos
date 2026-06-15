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
    // steep-downhill, power-hike, and uphill-running rows earn the classifier
    // its place: heart rate alone misreads them, and only the full kinematic
    // signature — grade, pace, cadence, vertical oscillation — recovers the
    // true effort. Note how uphill running and power hiking share a steep grade
    // yet read apart on cadence: the runner still strides, the hiker grinds.
    //                  hr  pace  cad  grade vertOsc  alt   label
    static let history: Run = [
        Segment(hr: 130, pace: 6.5, cadence: 165, grade:  0.0, vertOsc: 8.5, altitude: 1600, label: 0), // Easy — flat, slow
        Segment(hr: 135, pace: 6.2, cadence: 168, grade:  0.0, vertOsc: 8.3, altitude: 1610, label: 0), // Easy — flat
        Segment(hr: 128, pace: 6.8, cadence: 162, grade: -1.0, vertOsc: 9.0, altitude: 1620, label: 0), // Easy — gentle downhill, HR relaxed
        Segment(hr: 131, pace: 6.6, cadence: 164, grade:  0.0, vertOsc: 8.7, altitude: 1605, label: 0), // Easy — flat, settling in
        Segment(hr: 127, pace: 7.0, cadence: 160, grade:  0.0, vertOsc: 9.1, altitude: 1615, label: 0), // Easy — relaxed cruise
        Segment(hr: 133, pace: 6.4, cadence: 166, grade:  0.5, vertOsc: 8.6, altitude: 1625, label: 0), // Easy — flat, gentle rise
        Segment(hr: 129, pace: 6.7, cadence: 163, grade: -0.5, vertOsc: 8.9, altitude: 1635, label: 0), // Easy — flat, slight dip
        Segment(hr: 132, pace: 5.0, cadence: 158, grade: -6.0, vertOsc: 11.0, altitude: 1630, label: 3), // Hard — steep downhill, eccentric load (HR low, legs working)
        Segment(hr: 130, pace: 5.2, cadence: 156, grade: -5.5, vertOsc: 10.8, altitude: 1640, label: 3), // Hard — steep downhill, eccentric load (HR low, legs working)
        Segment(hr: 165, pace: 9.5, cadence: 145, grade:  9.0, vertOsc: 6.5, altitude: 1700, label: 3), // Hard — power hike, steep climb (HR honest, pace slow)
        Segment(hr: 168, pace: 9.8, cadence: 142, grade: 10.0, vertOsc: 6.3, altitude: 1715, label: 3), // Hard — power hike, steep climb (HR honest, pace slow)
        Segment(hr: 172, pace: 5.8, cadence: 178, grade:  5.0, vertOsc: 7.4, altitude: 1690, label: 3), // Hard — running uphill, still striding (high cadence, HR honest)
        Segment(hr: 176, pace: 6.0, cadence: 176, grade:  6.0, vertOsc: 7.2, altitude: 1705, label: 3), // Hard — running uphill, still striding (high cadence, HR honest)
        Segment(hr: 150, pace: 5.5, cadence: 172, grade:  1.0, vertOsc: 8.0, altitude: 1660, label: 1), // Steady — slight climb
        Segment(hr: 148, pace: 5.8, cadence: 170, grade:  0.5, vertOsc: 8.1, altitude: 1670, label: 1), // Steady — rolling
        Segment(hr: 155, pace: 5.3, cadence: 174, grade:  1.5, vertOsc: 7.9, altitude: 1690, label: 2), // Tempo — climbing
        Segment(hr: 158, pace: 5.0, cadence: 176, grade:  1.0, vertOsc: 7.6, altitude: 1700, label: 2), // Tempo — fast
        Segment(hr: 170, pace: 4.8, cadence: 180, grade:  0.0, vertOsc: 7.0, altitude: 1720, label: 3), // Hard — fast, flat
        Segment(hr: 178, pace: 4.6, cadence: 181, grade:  0.0, vertOsc: 6.9, altitude: 1725, label: 3), // Hard — sustained threshold, racing a parkrun (HR honest at race pace)
        Segment(hr: 175, pace: 4.5, cadence: 182, grade:  0.5, vertOsc: 6.8, altitude: 1730, label: 3), // Hard — fast, slight climb
        Segment(hr: 172, pace: 4.6, cadence: 178, grade:  0.0, vertOsc: 7.1, altitude: 1740, label: 3), // Hard — fast, flat
    ]

    // A simulated live run — unlabeled, the way HealthKit delivers it. In a real
    // app these come from the watch during a run, reading barometric altitude
    // alongside the other signals. Two random phases — easy warmup, then hard
    // tempo with varied terrain — are shuffled for realistic transitions, then
    // scripted episodes are appended so the demo reliably reaches the cases it
    // exists to show: a steep downhill, a power hike, a stretch of uphill
    // running, a set of hill repeats, and a long easy run where heart rate
    // drifts up — each a place where heart rate and true effort can disagree.
    // Altitude climbs from roughly 1600 m to 1750 m, so the baseline has real
    // elevation variation.
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

        // Phase 2: hard tempo — high HR, fast cadence, varied terrain, higher on
        // the climb. Heart rate alone cannot rank these moments: steep grades and
        // changing footing shift the true effort independently of HR.
        for i in 60..<120 {
            let altitude = start + gain * (Double(i) / 120.0)
            results.append(Segment(
                hr: .random(in: 155...178), pace: .random(in: 4.5...5.5),
                cadence: .random(in: 172...184), grade: .random(in: -3.0...4.0),
                vertOsc: .random(in: 6.8...7.6), altitude: altitude))
        }

        // Shuffle only the random phases, then append the scripted episodes so
        // each arrives as a coherent stretch rather than scattered single
        // moments. These mirror the steep-downhill and power-hike fingerprints
        // in `history`, so the classifier calls them Hard while the HR-zone
        // screen disagrees — the disagreement the demo is built to surface.
        results.shuffle()

        // Steep downhill: HR low, pace fast, steep negative grade, high vertical
        // oscillation from braking footstrikes. HR reads easy; the legs work hard.
        for i in 0..<8 {
            let altitude = (start + gain) - 6.0 * Double(i)   // dropping fast
            results.append(Segment(
                hr: .random(in: 128...136), pace: .random(in: 4.9...5.3),
                cadence: .random(in: 154...160), grade: .random(in: -6.5...(-5.0)),
                vertOsc: .random(in: 10.6...11.2), altitude: altitude))
        }

        // Power hike: HR high but honest, pace very slow, steep positive grade,
        // low cadence, low vertical oscillation. HR reads hard; the grind up the
        // grade is the fuller story the classifier reads.
        for i in 0..<8 {
            let altitude = (start + gain) + 5.0 * Double(i)   // climbing steeply
            results.append(Segment(
                hr: .random(in: 162...170), pace: .random(in: 9.3...10.0),
                cadence: .random(in: 140...146), grade: .random(in: 8.5...10.5),
                vertOsc: .random(in: 6.2...6.7), altitude: altitude))
        }

        // Uphill running: a runnable climb, not a hike. Pace is moderate and
        // cadence stays high — the runner keeps striding — so HR and effort
        // agree here. The contrast with the power hike above is the point: same
        // steep grade, but cadence tells the classifier these are different.
        for i in 0..<8 {
            let altitude = (start + gain) + 40.0 + 4.0 * Double(i)
            results.append(Segment(
                hr: .random(in: 170...180), pace: .random(in: 5.6...6.2),
                cadence: .random(in: 174...180), grade: .random(in: 4.5...6.0),
                vertOsc: .random(in: 7.0...7.6), altitude: altitude))
        }

        // Hill repeats: hard climbing surges alternating with easy recovery
        // jogs, the interval pattern applied to a hill. The abrupt swings drive
        // the score's variance and transition terms, so a set of repeats costs
        // more than the same minutes run steadily — what the structure is for.
        let repeatTop = start + gain + 80.0
        for rep in 0..<4 {
            // Hard surge up the hill.
            for _ in 0..<4 {
                results.append(Segment(
                    hr: .random(in: 172...182), pace: .random(in: 5.5...6.0),
                    cadence: .random(in: 176...182), grade: .random(in: 6.0...8.0),
                    vertOsc: .random(in: 7.0...7.5), altitude: repeatTop))
            }
            // Easy recovery jog back down.
            for _ in 0..<4 {
                results.append(Segment(
                    hr: .random(in: 130...145), pace: .random(in: 6.5...7.2),
                    cadence: .random(in: 158...166), grade: .random(in: -7.0...(-5.0)),
                    vertOsc: .random(in: 10.4...11.0), altitude: repeatTop - 8.0 * Double(rep)))
            }
        }

        // Long easy run with cardiac drift: pace, cadence, and grade are held
        // flat and easy throughout, but heart rate creeps up across the stretch
        // — dehydration and thermal load making the same easy pace cost more as
        // the run wears on. The workload never changes, so the Ridge baseline
        // keeps predicting the same expected HR; the ResidualModel watches the
        // gap widen and crosses into "running hot." This is the long-run cost
        // an HR-zone screen cannot see — the easy pace still reads as a low
        // zone, while the residual shows the effort climbing. "Long is hard."
        for i in 0..<24 {
            let driftHR = 130.0 + 1.1 * Double(i)   // 130 → ~155 over the stretch
            results.append(Segment(
                hr: driftHR, pace: .random(in: 6.3...6.6),
                cadence: .random(in: 163...167), grade: .random(in: -0.5...0.5),
                vertOsc: .random(in: 8.4...8.8), altitude: start + 20.0 + Double(i)))
        }

        return results
    }
}
