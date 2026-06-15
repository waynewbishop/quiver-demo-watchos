// Copyright 2026 Wayne W Bishop. All rights reserved.
// Licensed under the Apache License, Version 2.0.

import Foundation

// EffortLevel is the four-class effort taxonomy the model speaks in. The KNN
// classifier predicts one of these for every moment, and the score reads each
// level's `weight` to turn a sequence of labeled moments into a number.
//
// The raw values 0...3 are the labels the classifier trains and predicts on;
// the `weight` is the per-second stress each level contributes to the score.
enum EffortLevel: Int, CaseIterable {
    case easy = 0, steady = 1, tempo = 2, hard = 3

    // Display label for the watch face.
    var label: String {
        switch self {
        case .easy: return "Easy"; case .steady: return "Steady"
        case .tempo: return "Tempo"; case .hard: return "Hard"
        }
    }

    // Per-second stress multiplier. Time in a level is the level's weight
    // times its duration, so the score already accounts for time in zone.
    // Tempo is the threshold anchor: one hour held there scores about 100.
    var weight: Double {
        switch self {
        case .easy: return 0.25; case .steady: return 0.50
        case .tempo: return 0.75; case .hard: return 1.00
        }
    }

    // Clamp an arbitrary integer into the valid effort range. The classifier
    // returns a raw Int label, so this keeps an out-of-range prediction safe.
    init(clamping raw: Int) { self = EffortLevel(rawValue: max(0, min(3, raw))) ?? .easy }
}
