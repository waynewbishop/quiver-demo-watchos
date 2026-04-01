# Quiver Demo for watchOS

Most fitness watches classify effort by heart rate alone — dividing the HR range into five zones based on age-based formulas. But a heart rate of 160 BPM means different things depending on context. Running uphill at a slow pace is genuinely hard. Jogging downhill at the same heart rate is recovery. The watch doesn't know the difference.

This demo uses [Quiver](https://github.com/waynewbishop/quiver) to solve that problem. `PersonalBaseline` builds zones from the runner's own data using `percentile()` — not factory defaults. Then `KNearestNeighbors` trained on four sensor signals (heart rate, cadence, pace, and elevation) classifies true effort by finding the closest matching situations in training history. When a hill inflates HR, the model sees the full picture and classifies it as "Easy" — something basic HR zones cannot do.

## Run it

1. Clone this repo
2. Open in Xcode 26+
3. Run on the watchOS simulator

## Screens

**HR Zones** — Live BPM with personalized zone classification. Each reading is ranked against the runner's own history with `percentileRank(of:)` and checked for outliers via z-score.

**True Effort** — HR Zone vs True Effort displayed side by side. When the two disagree, the screen highlights the difference — "Hill inflating HR."

## Quiver APIs used

- `mean()`, `std()`, `percentile()`, `percentileRank(of:)` — personal statistics
- `KNearestNeighbors.fit()`, `predict()` — multi-signal classification
- `FeatureScaler.fit()`, `transform()` — normalizing sensor inputs

## Learn more

- [Quiver](https://github.com/waynewbishop/quiver) — the framework
- [Quiver Cookbook](https://github.com/waynewbishop/quiver-cookbook) — 42 interactive recipes
- [Quiver Documentation](https://waynewbishop.github.io/quiver/documentation/quiver/) — API reference and conceptual guides
- [Swift Algorithms & Data Structures](https://waynewbishop.github.io/swift-algorithms/) — the companion book
