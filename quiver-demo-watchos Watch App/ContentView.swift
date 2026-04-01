// Copyright 2026 Wayne W Bishop. All rights reserved.
// Licensed under the Apache License, Version 2.0.

import SwiftUI

struct ContentView: View {
    @State private var vm = RunningModel()

    // Zone colors: cyan for recovery (not pure blue — easier to read on dark),
    // green, yellow, orange, red. Standard 5-zone convention.
    private let zoneColors: [Color] = [.cyan, .green, .yellow, .orange, .red]

    var body: some View {
        TabView {
            zoneScreen
            effortScreen
        }
        .tabViewStyle(.verticalPage)
        .onAppear { vm.start() }
        .onDisappear { vm.stop() }
    }

    // MARK: - Screen 1: HR Zones
    // Clean mid-run glance — BPM and zone only.
    // No stats clutter. Runners at pace need two things: number and color.

    private var zoneScreen: some View {
        VStack(spacing: 8) {

            // Zone bar — thicker for glanceability at running speed
            HStack(spacing: 2) {
                ForEach(0..<5, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 3)
                        .fill(zoneColors[index])
                        .opacity(index == vm.zone ? 1.0 : 0.2)
                        .frame(height: 10)
                }
            }

            // Hero BPM number — the one thing a runner glances at
            // Zone 3 (yellow) uses white text for readability on dark backgrounds
            Text("\(vm.bpm)")
                .font(.system(size: 52, weight: .bold))
                .foregroundColor(bpmColor)
                .monospacedDigit()

            Text("BPM")
                .font(.system(size: 10))
                .foregroundColor(.secondary)

            // Zone name — colored to match the bar
            Text(vm.zoneName)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(zoneColors[min(vm.zone, 4)])
        }
        .padding(.horizontal, 8)
    }

    // MARK: - Screen 2: True Effort
    // The Quiver differentiator. Hero effort label is the answer.
    // HR vs Effort comparison is secondary context below.
    // Warm (orange) = single-signal HR. Cool (cyan) = Quiver's multi-signal intelligence.

    private var effortScreen: some View {
        VStack(spacing: 10) {

            // The answer — big, bold, unmissable
            Text(vm.effortLabel)
                .font(.system(size: 34, weight: .bold))
                .foregroundColor(.cyan)

            Text("TRUE EFFORT")
                .font(.system(size: 9, design: .monospaced))
                .foregroundColor(.secondary)

            // Comparison cards — warm = HR, cool = multi-signal
            HStack(spacing: 8) {
                card("HR Zone", vm.hrLabel, .orange)
                card("Sensors", vm.effortLabel, .cyan)
            }

            // When HR zone and true effort disagree, any of the four
            // dimensions could be the cause:
            //   Elevation — inflates HR uphill, deflates effort downhill
            //   Pace — fast pace with low HR means cardiac lag
            //   Cadence — low cadence + high HR means grinding uphill
            //   HR — the lagging indicator everyone else relies on alone
            // Future: compare the current segment against matched KNN
            // neighbors to identify which dimension drove the disagreement
            // and display a specific message (e.g. "Terrain inflating HR",
            // "HR lagging effort", "Cadence masking effort").
            HStack(spacing: 4) {
                Image(systemName: vm.disagrees
                      ? "exclamationmark.triangle.fill"
                      : "checkmark.circle.fill")
                    .font(.system(size: 10))
                    .foregroundColor(vm.disagrees ? .yellow : .green)
                Text(vm.disagrees ? "HR and effort disagree" : "HR matches effort")
                    .font(.system(size: 10))
                    .foregroundColor(vm.disagrees ? .yellow : .green)
            }
        }
        .padding(.horizontal, 8)
    }

    // MARK: - Helpers

    private func card(_ title: String, _ value: String, _ color: Color) -> some View {
        VStack(spacing: 2) {
            Text(title)
                .font(.system(size: 8, design: .monospaced))
                .foregroundColor(.secondary)
            Text(value)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(color)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 5)
        .background(color.opacity(0.12))
        .cornerRadius(8)
    }

    // Zone 3 (yellow) is hard to read on dark backgrounds —
    // use white text for the BPM number, yellow for the zone bar and name
    private var bpmColor: Color {
        let zoneIndex = min(vm.zone, 4)
        if zoneIndex == 2 { return .white }
        return zoneColors[zoneIndex]
    }
}

#Preview {
    ContentView()
}
