# Quiver Demo for watchOS

Most platforms capture heart rate, cadence, pace, and elevation — but process them through separate proprietary algorithms. A heart rate of 160 BPM means different things depending on context. Running uphill at a slow pace is genuinely hard. Jogging downhill at the same heart rate is recovery.

This demo uses [Quiver](https://github.com/waynewbishop/quiver) to compute a **True Effort Score (TES)** that keeps all six signals — heart rate, pace, cadence, grade, vertical oscillation, and altitude — together as a single feature vector, rather than collapsing the workout to one number. The companion article, [Building an Effort Model](https://waynewbishop.github.io/quiver/documentation/quiver/building-an-effort-model), walks through the design this app implements.

## What changed in 1.4.0

The 1.4.0 release rebuilt TES around `ResidualModel`, a Quiver primitive that wraps a fitted regressor and reports the gap between observed and predicted values. TES now runs **two models on separate jobs** instead of a single classifier:

- A **`Ridge` baseline** predicts the heart rate the external workload *should* produce. A **`ResidualModel`** wraps it and reports the **residual** — observed minus expected heart rate. A positive residual means the heart is running hotter than the work explains: the signature of an *inflating* effect like heat, cardiac drift, or altitude.
- A **`KNearestNeighbors` classifier**, bundled with its scaler in a **`Pipeline`**, labels each moment Easy, Steady, Tempo, or Hard by its resemblance to past efforts. It catches the *masking* effects the residual cannot — a downhill where heart rate stays high while the legs coast lands near other downhill samples and is labeled Easy regardless.

The score itself stays a returned **value**: a time-weighted load anchored so one hour held at threshold reads about `100`, climbing with both intensity and time with no ceiling. The residual is a parallel **diagnostic** displayed alongside the score — it never feeds into it.

## How TES works

`TrueEffortScore` follows Quiver's model idiom — `fit` returns a finished, immutable value, and we `score` runs against it:

```swift
import Quiver

// Fit once from the runner's labeled history, then score a run against it.
let model = try TrueEffortScore.fit(history: pastRuns)
let result = model.score(for: todaysRun)

result.value             // ≈100 — one hour held at threshold effort
result.residual          // observed − expected HR for the latest moment
result.expectedHeartRate // what the workload predicts for that moment
```

Each `Segment` is one moment of a run, split into the two views the two halves consume. Heart rate is the baseline's *target*, so it never appears in the baseline's features — only in the classifier's:

- **Baseline features** — `[pace, cadence, grade, vertOsc, altitude]` → predicts expected heart rate.
- **Classifier features** — `[hr, pace, cadence, grade, vertOsc]` → predicts the effort label.

We fit `Ridge` rather than plain least squares because the workload signals overlap; the L2 penalty keeps the on-device fit from going singular. A `StandardScaler` is mandatory — the signals live on wildly different scales (cadence near `170`, grade between roughly `−3` and `+4`, altitude in the hundreds of metres). We fit the scaler once on the history and reuse it on every live sample. The fitted baseline reads back as inspectable math via `asExpression` — the anti-black-box.

Re-fitting as the runner logs more sessions is the same `fit(history:)` call on a longer history. Everything runs on the wrist in pure Swift with zero dependencies.

## Run it

1. Clone this repo
2. Open in Xcode 26+
3. Run on the watchOS simulator

## Screens

**HR Zones** — Live BPM with personalized zone classification. `PersonalBaseline` builds zones from the runner's own heart-rate distribution with `percentile()` — not a `220 − age` formula. This is the deliberately naive single-signal model TES is built to improve on.

**True Effort** — The multi-signal effort label and the running session Score, side by side with the HR-zone read. When the two disagree — the downhill that inflates heart rate while true effort is Easy — the screen flags it.

**Effort Residual** — Observed heart rate against the `Ridge` baseline's expected heart rate, with the signed gap between them. Near zero means heart rate matches the work; a large positive gap means running hot, pointing to heat, drift, or altitude.

## Quiver APIs used

- `Ridge.fit()` — penalized regression for the expected-heart-rate baseline
- `ResidualModel(model:)`, `residual(features:observed:)`, `expected()` — the observed-minus-expected diagnostic
- `StandardScaler.fit()`, `transform()` — standardizing the six workload signals
- `KNearestNeighbors` inside `Pipeline.fit()` / `predict()` — multi-signal effort classification with its scaler bundled in
- `percentile()`, `variance()` — personal statistics for the HR zones and the session variance term
- `asExpression()` — rendering the fitted baseline as readable math

## Learn more

- [Building an Effort Model](https://waynewbishop.github.io/quiver/documentation/quiver/building-an-effort-model) — the worked example this app implements
- [Quiver](https://github.com/waynewbishop/quiver) — the framework
- [Quiver Cookbook](https://github.com/waynewbishop/quiver-cookbook) — interactive recipes
- [Quiver Documentation](https://waynewbishop.github.io/quiver/documentation/quiver/) — API reference and conceptual guides
- [Swift Algorithms & Data Structures](https://waynewbishop.github.io/swift-algorithms/) — the companion book
