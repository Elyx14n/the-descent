# Rendering preparation benchmarks

Measured on 2026-10-16 with DragonRuby 7.21 Standard, Linux, offscreen SDL,
software rendering, 1024 × 576 display, HD enabled, 320 × 180 logical viewport.
These timings measure Ruby preparation and output submission, **not engine draw
execution, GPU time, or displayed FPS**. Debug overlays are excluded.

Run `bin/rake test tests/render_benchmark.rb HEADLESS=1`. This opt-in native test
is deliberately excluded from the normal suite. It uses `Time.now`, as the SDK
benchmark does, without rounding batches to milliseconds. Each operation warms
up for 120 iterations, then measures seven batches of 1,200 iterations with fresh
room/state and GC before each timed batch. Microseconds are per operation;
`frame` includes actor preparation, animations, room collections, camera follow,
fade, culling, sorting, translation, output clearing/submission, and deterministic
door/light changes. It excludes file polling and gameplay collision. The fixed
120-frame sequence includes stationary, fade/reversal, and pan phases.

The larger fixture repeats the authored room three times horizontally, remapping
object IDs and mounted references. It is a scaling workload, not a playable map.
`camera` translates the initial visible batch during a pan; `fade` measures a
stationary actor behind the southern wall. `animations` advances lit frames.
Setup/import and explicit GC are outside timers; allocations/GC during measured
work remain part of the cost.

Gate: at least 5% lower targeted median, exceeding observed timing variation,
with no repeatable overall-preparation regression. Report raw samples and ranges;
repeat noisy comparisons. Do not claim frame-rate improvements from these data.
Run correctness tests and lint before committing each accepted optimization.

## Baseline — affb8d8

All 140 native tests passed before optimization. Timings vary substantially,
especially full preparation; interpret small differences cautiously.

```text
RENDER_BENCH_COUNTS copies=1 sprites=151 visible=69 units=38 lights=6 regions=500
RENDER_BENCH copies=1 operation=room_data iterations=1200 median_us=53.5 min_us=52.686 max_us=62.882 samples_us=54.266,52.912,52.686,53.5,62.882,56.636,53.386
RENDER_BENCH copies=1 operation=camera iterations=1200 median_us=311.181 min_us=300.35 max_us=339.167 samples_us=306.661,323.337,311.181,339.167,334.953,301.265,300.35
RENDER_BENCH copies=1 operation=animations iterations=1200 median_us=4.132 min_us=3.841 max_us=4.223 samples_us=4.132,4.17,4.07,3.841,3.959,4.223,4.193
RENDER_BENCH copies=1 operation=fade iterations=1200 median_us=282.167 min_us=258.983 max_us=358.893 samples_us=263.112,299.608,258.983,282.167,272.093,303.595,358.893
RENDER_BENCH copies=1 operation=frame iterations=1200 median_us=1078.534 min_us=1046.023 max_us=1431.993 samples_us=1431.993,1312.008,1053.068,1059.482,1078.534,1141.179,1046.023
RENDER_BENCH_COUNTS copies=3 sprites=451 visible=69 units=114 lights=18 regions=1500
RENDER_BENCH copies=3 operation=room_data iterations=1200 median_us=169.096 min_us=161.233 max_us=186.291 samples_us=186.291,161.233,169.096,182.553,161.448,184.24,164.901
RENDER_BENCH copies=3 operation=camera iterations=1200 median_us=340.806 min_us=313.055 max_us=392.878 samples_us=330.125,313.055,316.5,340.806,392.878,364.627,353.731
RENDER_BENCH copies=3 operation=animations iterations=1200 median_us=11.408 min_us=10.535 max_us=13.313 samples_us=11.809,13.313,11.408,12.038,10.535,11.168,10.807
RENDER_BENCH copies=3 operation=fade iterations=1200 median_us=721.8099999999999 min_us=700.329 max_us=797.563 samples_us=700.329,720.783,760.965,797.563,731.269,721.8099999999999,714.761
RENDER_BENCH copies=3 operation=frame iterations=1200 median_us=2686.271 min_us=2492.429 max_us=5665.317 samples_us=2492.429,2680.572,2686.271,2493.868,2770.368,3252.748,5665.317
```
