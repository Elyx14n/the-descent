# Rendering preparation benchmark samples

The accepted problems, solutions, trade-offs, and measurement gate live in
[ADR-0009](../adr/0009-measured-render-preparation.md). This note retains
reproduction details and raw observations.

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

## After room collection caching

```text
RENDER_BENCH_COUNTS copies=1 sprites=151 visible=69 units=38 lights=6 regions=500
RENDER_BENCH copies=1 operation=room_data iterations=1200 median_us=0.578 min_us=0.535 max_us=0.633 samples_us=0.578,0.576,0.599,0.535,0.5629999999999999,0.626,0.633
RENDER_BENCH copies=1 operation=camera iterations=1200 median_us=333.028 min_us=312.424 max_us=376.877 samples_us=333.028,338.628,335.94,376.877,326.088,312.424,323.374
RENDER_BENCH copies=1 operation=animations iterations=1200 median_us=4.063 min_us=3.86 max_us=4.514 samples_us=4.514,4.235,3.86,4.035,3.898,4.063,4.158
RENDER_BENCH copies=1 operation=fade iterations=1200 median_us=226.851 min_us=223.401 max_us=251.073 samples_us=251.073,239.714,238.045,225.832,224.508,223.401,226.851
RENDER_BENCH copies=1 operation=frame iterations=1200 median_us=986.838 min_us=961.0 max_us=994.997 samples_us=986.838,994.997,978.303,988.8150000000001,967.7329999999999,961.0,994.835
RENDER_BENCH_COUNTS copies=3 sprites=451 visible=69 units=114 lights=18 regions=1500
RENDER_BENCH copies=3 operation=room_data iterations=1200 median_us=0.58 min_us=0.549 max_us=0.677 samples_us=0.578,0.596,0.553,0.549,0.58,0.677,0.598
RENDER_BENCH copies=3 operation=camera iterations=1200 median_us=299.333 min_us=292.873 max_us=315.707 samples_us=299.333,292.873,306.798,295.128,299.329,302.371,315.707
RENDER_BENCH copies=3 operation=animations iterations=1200 median_us=10.882 min_us=10.235 max_us=12.799 samples_us=10.235,10.603,10.528,10.882,12.799,12.495,11.395
RENDER_BENCH copies=3 operation=fade iterations=1200 median_us=641.85 min_us=625.3819999999999 max_us=653.811 samples_us=641.85,646.551,648.228,641.111,653.811,634.297,625.3819999999999
RENDER_BENCH copies=3 operation=frame iterations=1200 median_us=2171.98 min_us=2116.035 max_us=2280.03 samples_us=2116.035,2214.676,2177.761,2170.136,2147.179,2171.98,2280.03
```

## After camera drawing snapshots

```text
RENDER_BENCH_COUNTS copies=1 sprites=151 visible=69 units=38 lights=6 regions=500
RENDER_BENCH copies=1 operation=room_data iterations=1200 median_us=0.531 min_us=0.5 max_us=1.252 samples_us=0.588,1.252,0.531,0.524,0.5,0.528,0.5679999999999999
RENDER_BENCH copies=1 operation=camera iterations=1200 median_us=160.95 min_us=144.778 max_us=207.724 samples_us=144.778,149.938,152.972,160.95,207.724,197.36,164.659
RENDER_BENCH copies=1 operation=animations iterations=1200 median_us=4.147 min_us=3.854 max_us=8.343999999999999 samples_us=4.957,3.899,8.343999999999999,3.854,4.142,4.147,4.368
RENDER_BENCH copies=1 operation=fade iterations=1200 median_us=241.89 min_us=226.046 max_us=270.678 samples_us=264.272,270.678,241.89,237.828,246.445,241.199,226.046
RENDER_BENCH copies=1 operation=frame iterations=1200 median_us=808.303 min_us=774.654 max_us=900.6559999999999 samples_us=833.348,809.958,774.654,806.919,808.303,900.6559999999999,783.377
RENDER_BENCH_COUNTS copies=3 sprites=451 visible=69 units=114 lights=18 regions=1500
RENDER_BENCH copies=3 operation=room_data iterations=1200 median_us=0.538 min_us=0.507 max_us=0.672 samples_us=0.672,0.522,0.538,0.544,0.528,0.543,0.507
RENDER_BENCH copies=3 operation=camera iterations=1200 median_us=154.916 min_us=151.022 max_us=162.735 samples_us=154.916,157.705,159.936,151.022,154.257,152.527,162.735
RENDER_BENCH copies=3 operation=animations iterations=1200 median_us=10.368 min_us=10.3 max_us=11.732 samples_us=10.917,10.902,10.3,10.368,11.732,10.338,10.331
RENDER_BENCH copies=3 operation=fade iterations=1200 median_us=671.3150000000001 min_us=634.698 max_us=3395.989 samples_us=3395.989,652.764,689.15,634.698,689.77,671.3150000000001,639.576
RENDER_BENCH copies=3 operation=frame iterations=1200 median_us=1999.803 min_us=1976.07 max_us=2163.349 samples_us=2073.559,2163.349,1998.209,2020.071,1999.803,1976.07,1981.618
```

## After skipping unchanged light artwork

```text
RENDER_BENCH_COUNTS copies=1 sprites=151 visible=69 units=38 lights=6 regions=500
RENDER_BENCH copies=1 operation=room_data iterations=1200 median_us=0.527 min_us=0.523 max_us=0.618 samples_us=0.618,0.524,0.5679999999999999,0.523,0.527,0.524,0.578
RENDER_BENCH copies=1 operation=camera iterations=1200 median_us=153.477 min_us=148.004 max_us=169.227 samples_us=148.004,154.796,153.477,152.815,154.305,169.227,149.296
RENDER_BENCH copies=1 operation=animations iterations=1200 median_us=2.721 min_us=2.632 max_us=2.889 samples_us=2.638,2.721,2.769,2.889,2.853,2.632,2.653
RENDER_BENCH copies=1 operation=fade iterations=1200 median_us=230.302 min_us=224.836 max_us=252.809 samples_us=226.551,230.302,226.609,224.836,239.339,252.809,232.444
RENDER_BENCH copies=1 operation=frame iterations=1200 median_us=796.138 min_us=763.318 max_us=890.529 samples_us=788.053,890.529,807.376,796.138,763.318,778.658,804.033
RENDER_BENCH_COUNTS copies=3 sprites=451 visible=69 units=114 lights=18 regions=1500
RENDER_BENCH copies=3 operation=room_data iterations=1200 median_us=0.528 min_us=0.518 max_us=0.984 samples_us=0.518,0.523,0.531,0.528,0.546,0.519,0.984
RENDER_BENCH copies=3 operation=camera iterations=1200 median_us=153.202 min_us=147.911 max_us=159.909 samples_us=153.202,153.614,154.203,147.911,159.909,149.92,150.271
RENDER_BENCH copies=3 operation=animations iterations=1200 median_us=6.968 min_us=6.583 max_us=12.903 samples_us=7.27,6.858,12.903,6.879,6.583,7.181,6.968
RENDER_BENCH copies=3 operation=fade iterations=1200 median_us=643.908 min_us=636.913 max_us=660.298 samples_us=647.308,643.908,653.0309999999999,638.779,638.575,636.913,660.298
RENDER_BENCH copies=3 operation=frame iterations=1200 median_us=1981.993 min_us=1923.372 max_us=4943.5 samples_us=1981.993,1923.372,1968.468,4943.5,1982.023,1944.883,2037.767
```
