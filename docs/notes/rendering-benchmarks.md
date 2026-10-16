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

## Rejected transformed-geometry cache candidate

Candidate removed; see ADR-0009 for the failed gate and trade-offs.

```text
RENDER_BENCH_COUNTS copies=1 sprites=151 visible=69 units=38 lights=6 regions=500
RENDER_BENCH copies=1 operation=room_data iterations=1200 median_us=0.624 min_us=0.513 max_us=1.04 samples_us=0.758,0.538,0.92,1.04,0.624,0.542,0.513
RENDER_BENCH copies=1 operation=camera iterations=1200 median_us=155.533 min_us=149.859 max_us=175.792 samples_us=154.908,149.859,155.533,175.792,151.647,167.81,160.509
RENDER_BENCH copies=1 operation=animations iterations=1200 median_us=8.484 min_us=8.141 max_us=10.213 samples_us=10.213,8.141,8.324,8.433,8.56,8.484,9.259
RENDER_BENCH copies=1 operation=fade iterations=1200 median_us=227.572 min_us=225.852 max_us=261.107 samples_us=261.107,242.923,259.474,225.852,227.572,227.091,225.958
RENDER_BENCH copies=1 operation=frame iterations=1200 median_us=773.26 min_us=752.343 max_us=799.035 samples_us=783.274,799.035,752.343,773.26,779.948,759.248,758.412
RENDER_BENCH_COUNTS copies=3 sprites=451 visible=69 units=114 lights=18 regions=1500
RENDER_BENCH copies=3 operation=room_data iterations=1200 median_us=0.518 min_us=0.499 max_us=0.6 samples_us=0.54,0.536,0.513,0.516,0.499,0.6,0.518
RENDER_BENCH copies=3 operation=camera iterations=1200 median_us=149.28 min_us=146.279 max_us=155.318 samples_us=150.159,146.279,153.758,148.271,155.318,149.28,147.953
RENDER_BENCH copies=3 operation=animations iterations=1200 median_us=25.81 min_us=24.516 max_us=30.193 samples_us=25.81,24.708,26.657,24.71,30.193,26.403,24.516
RENDER_BENCH copies=3 operation=fade iterations=1200 median_us=626.965 min_us=611.4059999999999 max_us=3607.629 samples_us=611.4059999999999,3607.629,625.691,619.228,628.533,626.965,723.472
RENDER_BENCH copies=3 operation=frame iterations=1200 median_us=2025.028 min_us=1902.625 max_us=2164.319 samples_us=2025.028,2164.319,2128.351,2040.071,1985.941,1921.833,1902.625
```

## Stateless helper refactor comparison

A fresh separate-process baseline and helper run are retained below. The first
helper attempt was rejected because `Time.now` went backwards during one camera
batch (`-1350.383` µs/operation); the harness failed its positive-duration check.
The retry completed but unchanged camera/animation operations also became slower,
so these separate-process timings cannot isolate the refactor's effect.

A subsequent temporary paired runner loaded the original `ForegroundFade` source
from commit `0ac278c` as `BenchmarkBaselineFade`, then alternated that implementation
and the helper consumer in the same process. It used the committed harness's
unchanged fixtures and `benchmark_step`, `fade`/`frame` workloads, 120 warmup
iterations per implementation, and seven fresh-state batches of 1,200 iterations.
The first implementation alternated each pair. Source module selection, fixture
setup and explicit GC were outside the timer. Only the fade implementation changed;
Render, Room, Camera, state sequences, and output queues were identical. Temporary
baseline/comparison source is removed after the experiment rather than shipping a
second fade implementation. These were exploratory checks; the helper was subsequently accepted as an
architectural decision independently of timing results.

### Fresh baseline

```text
RENDER_BENCH_COUNTS copies=1 sprites=151 visible=69 units=38 lights=6 regions=500
RENDER_BENCH copies=1 operation=room_data iterations=1200 median_us=0.546 min_us=0.499 max_us=0.626 samples_us=0.5590000000000001,0.626,0.499,0.533,0.546,0.581,0.545
RENDER_BENCH copies=1 operation=camera iterations=1200 median_us=167.698 min_us=152.007 max_us=202.793 samples_us=167.814,186.093,202.793,159.833,167.698,152.007,163.889
RENDER_BENCH copies=1 operation=animations iterations=1200 median_us=2.607 min_us=2.565 max_us=2.78 samples_us=2.584,2.565,2.607,2.761,2.597,2.773,2.78
RENDER_BENCH copies=1 operation=fade iterations=1200 median_us=225.721 min_us=223.803 max_us=245.035 samples_us=226.221,224.508,225.721,245.035,232.01,223.803,224.298
RENDER_BENCH copies=1 operation=frame iterations=1200 median_us=766.102 min_us=755.6079999999999 max_us=803.473 samples_us=782.158,803.473,759.646,766.102,755.6079999999999,780.36,758.495
RENDER_BENCH_COUNTS copies=3 sprites=451 visible=69 units=114 lights=18 regions=1500
RENDER_BENCH copies=3 operation=room_data iterations=1200 median_us=0.509 min_us=0.496 max_us=0.596 samples_us=0.509,0.502,0.509,0.523,0.511,0.596,0.496
RENDER_BENCH copies=3 operation=camera iterations=1200 median_us=151.402 min_us=147.424 max_us=152.456 samples_us=152.456,151.402,152.405,152.428,147.469,147.424,148.096
RENDER_BENCH copies=3 operation=animations iterations=1200 median_us=6.762 min_us=6.587 max_us=7.357 samples_us=6.662,6.771,6.762,6.587,7.357,6.594,6.795
RENDER_BENCH copies=3 operation=fade iterations=1200 median_us=638.833 min_us=626.386 max_us=670.044 samples_us=633.814,670.044,638.833,626.386,628.365,650.5940000000001,651.343
RENDER_BENCH copies=3 operation=frame iterations=1200 median_us=1970.233 min_us=1931.628 max_us=2225.447 samples_us=1940.921,1970.342,1931.628,1960.383,1970.233,2118.393,2225.447
```

### Separate helper retry (host variation)

```text
RENDER_BENCH_COUNTS copies=1 sprites=151 visible=69 units=38 lights=6 regions=500
RENDER_BENCH copies=1 operation=room_data iterations=1200 median_us=0.655 min_us=0.582 max_us=3.665 samples_us=0.8100000000000001,3.665,0.733,0.582,0.618,0.655,0.609
RENDER_BENCH copies=1 operation=camera iterations=1200 median_us=189.535 min_us=167.093 max_us=208.262 samples_us=197.356,189.535,206.837,208.262,167.093,170.681,177.081
RENDER_BENCH copies=1 operation=animations iterations=1200 median_us=2.859 min_us=2.798 max_us=2.961 samples_us=2.859,2.843,2.961,2.798,2.946,2.905,2.812
RENDER_BENCH copies=1 operation=fade iterations=1200 median_us=251.278 min_us=244.823 max_us=255.972 samples_us=244.823,252.532,251.278,255.972,248.06,248.411,253.11
RENDER_BENCH copies=1 operation=frame iterations=1200 median_us=916.807 min_us=852.831 max_us=1080.165 samples_us=860.426,852.831,898.833,1048.455,1070.945,916.807,1080.165
RENDER_BENCH_COUNTS copies=3 sprites=451 visible=69 units=114 lights=18 regions=1500
RENDER_BENCH copies=3 operation=room_data iterations=1200 median_us=0.613 min_us=0.589 max_us=0.785 samples_us=0.613,0.6919999999999999,0.608,0.681,0.785,0.611,0.589
RENDER_BENCH copies=3 operation=camera iterations=1200 median_us=229.417 min_us=198.722 max_us=302.538 samples_us=302.538,215.241,246.906,216.381,297.888,198.722,229.417
RENDER_BENCH copies=3 operation=animations iterations=1200 median_us=8.503 min_us=7.233 max_us=15.213 samples_us=11.757,15.213,8.503,8.688000000000001,7.687,7.79,7.233
RENDER_BENCH copies=3 operation=fade iterations=1200 median_us=883.177 min_us=718.186 max_us=960.278 samples_us=830.943,883.177,738.114,951.819,718.186,910.018,960.278
RENDER_BENCH copies=3 operation=frame iterations=1200 median_us=2837.523 min_us=2519.698 max_us=3062.068 samples_us=2519.698,2837.523,3062.068,2838.225,2720.791,3016.991,2796.098
```

### Paired comparison

```text
GEOMETRY_PAIR copies=1 operation=fade version=baseline median_us=299.357 samples_us=344.768,324.326,315.187,274.233,260.116,252.962,299.357
GEOMETRY_PAIR copies=1 operation=fade version=helper median_us=311.573 samples_us=312.974,311.573,331.077,342.793,279.363,258.461,253.806
GEOMETRY_PAIR copies=1 operation=frame version=baseline median_us=925.269 samples_us=1029.095,889.447,925.269,991.912,1023.163,919.867,890.758
GEOMETRY_PAIR copies=1 operation=frame version=helper median_us=979.352 samples_us=1087.263,981.38,895.284,937.388,1026.26,979.352,921.508
GEOMETRY_PAIR copies=3 operation=fade version=baseline median_us=937.8390000000001 samples_us=998.913,937.8390000000001,930.8440000000001,942.253,965.088,868.102,857.9400000000001
GEOMETRY_PAIR copies=3 operation=fade version=helper median_us=968.091 samples_us=3445.885,946.473,968.091,962.25,1114.863,930.665,995.937
GEOMETRY_PAIR copies=3 operation=frame version=baseline median_us=2417.889 samples_us=2728.733,2914.679,4824.287,2417.889,2399.884,2368.532,2102.133
GEOMETRY_PAIR copies=3 operation=frame version=helper median_us=2416.119 samples_us=2416.119,2786.408,2791.188,2723.591,2331.346,2409.124,2011.498
```

### Repeated full-preparation pairs

```text
GEOMETRY_PAIR copies=1 operation=frame version=baseline median_us=1058.898 samples_us=993.713,1173.438,1099.758,881.523,938.7430000000001,1296.21,1058.898
GEOMETRY_PAIR copies=1 operation=frame version=helper median_us=960.071 samples_us=833.867,961.86,901.2380000000001,942.213,960.071,2354.827,1087.862
GEOMETRY_PAIR copies=3 operation=frame version=baseline median_us=2008.038 samples_us=2283.936,2008.038,1975.719,1990.741,1987.08,2153.942,2079.674
GEOMETRY_PAIR copies=3 operation=frame version=helper median_us=2043.124 samples_us=2089.473,2066.876,1951.253,1992.849,1991.984,4486.447,2043.124
```

These exploratory comparisons varied in direction across runs/workloads. The
stateless helper was subsequently accepted explicitly as an architectural
decision, independently of performance. See ADR-0009 for its rationale and
correctness verification. No further timing gate applies to this extraction.
