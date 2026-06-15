// Copyright 2026 Wayne W Bishop. All rights reserved.
// Licensed under the Apache License, Version 2.0.

import Foundation
import Quiver

// PersonalBaseline drives the demo's heart-rate-zone screen — the deliberately
// naive comparison the True Effort Score is built to improve on. It builds
// zones from the runner's own heart-rate distribution using Quiver's
// `percentile()`, not a one-size-fits-all `220 − age` formula.
//
// This is intentionally a single-signal model: it knows only heart rate. The
// demo shows it alongside the multi-signal classifier so the two can disagree
// — the downhill where the HR zone reads "hard" but the full model reads
// "easy" is exactly the case the score exists to catch.
struct PersonalBaseline {
    let readings: [Double]

    // Percentile thresholds unique to this runner (20/40/60/80).
    let thresholds: [Double]

    // Build zone thresholds from historical HR readings.
    init(readings: [Double]) {
        self.readings = readings
        self.thresholds = [20, 40, 60, 80].compactMap { readings.percentile($0) }
    }

    // Assign a 0–4 zone by where the value falls in personal history.
    func classify(_ value: Double) -> Int {
        for (index, threshold) in thresholds.enumerated() where value < threshold {
            return index
        }
        return thresholds.count
    }
}
