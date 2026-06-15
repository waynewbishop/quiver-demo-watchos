// Copyright 2026 Wayne W Bishop. All rights reserved.
// Licensed under the Apache License, Version 2.0.

import Foundation

// Segment is one moment of a run — the model's unit of input. Every reading
// the watch produces at a single instant becomes a Segment, and the two
// computed properties below split those six signals into the two views the
// model's two halves consume.
//
// Heart rate is special: it is the value the baseline PREDICTS, so it never
// appears in `baselineFeatures` (a model cannot use its own target as an
// input). It does appear in `classifierFeatures`, where the classifier reads
// it as one signal among several rather than as the answer.
//
// The six signals are raw sensor readings, never a derived effort number.
// Running power is deliberately excluded: it is itself a model's output,
// computed from pace, grade, and body weight, so feeding it in would wrap a
// pre-cooked effort estimate inside our own rather than reading effort from
// what the body actually produces.
struct Segment {
    let hr: Double           // bpm — the baseline's target, never an input
    let pace: Double         // min/km
    let cadence: Double      // spm
    let grade: Double        // % (signed: negative = downhill)
    let vertOsc: Double      // cm — vertical oscillation
    let altitude: Double     // meters

    // The confirmed effort level (0 Easy … 3 Hard), present on the moments of a
    // runner's labeled history and nil on live samples the model has yet to
    // score. The classifier trains only on the labeled moments.
    var label: Int? = nil

    // What the BASELINE sees: every workload signal except HR, which is the
    // target. Grade is the rate of elevation change; altitude is position —
    // both carry independent information, so both earn a slot.
    var baselineFeatures: [Double] { [pace, cadence, grade, vertOsc, altitude] }

    // What the CLASSIFIER sees: the kinematic signature that separates terrain
    // regimes. KNN tolerates the correlation the baseline cannot.
    var classifierFeatures: [Double] { [hr, pace, cadence, grade, vertOsc] }
}
