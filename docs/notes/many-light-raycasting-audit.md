# Many-light raycasting audit

2026-10-18. Audit, measured experiments, and proposals; no production lighting changes. Baseline: `3459b34b1bdec3e2d4e93049e24af32e92f55180`, plus the user's explanatory comments in `raycasting.rb`, preserved unchanged. See [algorithm research and primary sources](many-light-raycasting-research.md).

Later integration note (2026-10-19): the measurements below used projected visual outlines, radius 96, square range boundaries, and an unfilled scene. Current RoomPreview uses collider bases, player radius 64 / room fallback 48, circular boundaries, filled floor lighting, and fixed-room polygon reuse under [ADR-0014](../adr/0014-use-collider-bases-for-lighting.md). The opt-in audit probes now read current collider inputs/defaults but retain square boundaries and bypass filled lighting to isolate casting stages; reruns are different workloads. Use the [integrated checkpoint](raycast-lighting.md#wired-learning-checkpoint-2026-10-19) for current measurements.

## Finding

The raycaster is a substantial bottleneck itself, rather than a small downstream symptom of expensive room preparation. However, calling it again for unchanged light inputs is the largest architectural waste found. Debug-line conversion/submission is a separate, substantial downstream cost. These call for different remedies.

The current production preview only solves the **player lamp**, and only with B diagnostics enabled. Six room sources are exposed and drawn as markers, but their polygons are not solved. Consequently, ordinary debug-off FPS does not measure lighting capacity.

## Method and workload

Native DragonRuby 7.21 Standard on Linux, `hd=false`, native 320 × 180 raster. CPU probes use one warm-up and seven samples of three operations, reporting median time per operation; GC runs before each sample. Playback uses offscreen OpenGL with software rendering, 30 warm-up frames and 60 measured frames per case. No other benchmark ran concurrently. These are local observations, not predictions of hardware FPS.

The existing room provides six enabled emitters plus the player lamp, 78 blocker sprites and 383 world-space edges. Room emitters have authored radius zero; the probe applies the guide's **96 world-unit fallback** and each source's `ignore_owner_ids`. The player keeps radius 96. Blocker selection uses each light's square bounds independently of the camera, retaining all edges from selected sprites and adding four border segments. This adapts the existing query to the intended all-source semantics, rather than treating zero radius as a valid lighting workload. Other lights' artwork remains blocking.

All seven influence bounds overlap the camera at the dense test position. A lower camera position reduces that to five, so influence culling helps elsewhere but cannot solve this measured dense case. The full-room tests deliberately include all seven.

## CPU measurements

Three complete runs produced these medians, rounded to show host variation. The final confirmation followed lint cleanup in the probe (including an equivalent owner-ID membership check):

| Stage | Time (ms) | Interpretation |
| --- | ---: | --- |
| Fresh `Room#render_data` | 0.75–0.93 | All blocker transforms and other frame data, once per frame |
| Select blockers and convert endpoints for seven lights | 1.00–1.31 | Additional preparation outside raycasting |
| Same selection with endpoints shared within the frame | 0.79–0.97 | Only about 0.2–0.34 ms saved |
| Solve seven polygons with existing buckets | 31.7–34.0 | Main repeated computation |
| Bucket construction alone | 2.76–3.00 | **Included** in polygon solving above |
| Endpoint collection, uniqueness, and ray angles | 5.48–5.66 | Also included in solving; measured in the last two runs |
| Build 1,941 outline lines | 1.30–1.38 | Debug output construction |
| `Render.draw` with those lines | 9.38–10.35 | Ruby preparation/submission, not GPU completion |
| `Render.draw` without those lines | 0.52–0.62 | Same scene, camera, sorting and fading |
| Complete fresh CPU frame with seven outlines | 47.3–52.5 | Direct whole-path measurement; separate medians need not sum |

Per-source input and candidate counts at the fixed position:

| Source | Segments including border | Rays | Bucket candidate pairs | Solve time, second run (ms) |
| --- | ---: | ---: | ---: | ---: |
| 6 | 149 | 315 | 4,077 | 5.16 |
| 7 | 149 | 315 | 4,065 | 5.17 |
| 8 | 114 | 237 | 2,071 | 3.37 |
| 9 | 114 | 240 | 2,142 | 3.57 |
| 121 | 113 | 240 | 3,611 | 4.71 |
| 122 | 113 | 240 | 3,557 | 4.26 |
| Player | 149 | 354 | 4,070 | 5.52 |

The bucketed loop attempts **23,593** pairs instead of **255,234** for scanning every selected segment per ray: about **90.8% fewer**. This explains why removing buckets hurts. They nevertheless rebuild around each origin and offer no near-to-far stopping rule. Repeating these same real query positions 16 and 32 times took approximately **78–81 ms** and **156–183 ms**. That is a synthetic source-count test with repeated positions, not a larger-map or distinct-layout benchmark; it shows roughly linear growth in the number of uncached queries.

Removing exactly duplicate ray angles would save only 111 candidate tests here, under 0.5%. It is not a promising primary optimization. Endpoint generation itself is more substantial, but an index will not automatically eliminate that work.

## Reuse experiment

A 180-frame trace compared complete query inputs after animation updates. This is an exact-content diagnostic oracle, not a proposed production hashing scheme.

| Scenario | Queries | Changed inputs requiring a solve | Unchanged |
| --- | ---: | ---: | ---: |
| Stationary player; flames animate | 1,260 | 82 | 93.5% |
| Moving player; flames animate | 1,260 | 242 | 80.8% |
| Moving player; door opens; light disabled then enabled | 1,230 | 242 | 80.3% |

With movement, the player changes all 180 times. The six room lights together change only 62 times out of 1,080 queries. Some stationary lights still change because nearby flames change their occluding silhouettes. The interaction trace is evidence that input changes are observable, not proof of a future invalidation implementation.

Playback kept normal game updates, animation, camera and scene rendering. It replaced diagnostics in the probe process to isolate polygon calculation and polygon outlines. “Cached” compares freshly assembled complete segment arrays, reusing a polygon only when identical. It still pays input preparation and comparison. No production cache was installed.

| Case | 640 × 360 median / p95 CPU (ms) | FPS | 1920 × 1080 median / p95 CPU (ms) | FPS |
| --- | ---: | ---: | ---: | ---: |
| Scene, no casts | 3.0 / 4.3 | 62.5 | 3.0 / 3.9 | 65.6 |
| Player solve, no outlines | 8.7 / 12.6 | 62.5 | 8.2 / 10.0 | 63.6 |
| Seven solves, no outlines | 38.4 / 53.3 | 13.5* | 35.4 / 41.3 | 26.9 |
| Seven solves and outlines | 49.2 / 57.9 | 19.4 | 46.9 / 57.7 | 19.9 |
| Frozen polygons, outlines only | 15.5 / 18.5 | 57.0 | 16.7 / 21.9 | 53.2 |
| Exact-input reuse, no outlines | 13.1 / 22.2 | 58.9 | 14.6 / 28.9 | 54.6 |
| Exact-input reuse and outlines | 23.2 / 36.1 | 38.3 | 28.7 / 46.9 | 31.7 |

Both reuse cases performed **78 solves instead of 420** during their 60 measured frames. The frozen case intentionally ignores geometry/origin changes and is only a downstream rendering calibration; it is not a valid caching strategy.

*The 640 all-compute sample includes a 2,031 ms CPU preparation outlier, reducing its average FPS sharply despite a 38.4 ms median. An earlier run had a long outlier in the other window size. The cause is unresolved: timing locates it inside preparation, but does not distinguish GC, scheduling or another cause. Do not infer a resolution-dependent rendering bottleneck from those averages. Scripts print means, maxima and loop durations to expose this. Longer on-hardware traces and attribution of these stalls remain necessary before claiming stable 60 FPS. Even excluding the outlier, ordinary seven-light solves exceed a frame budget; caching also leaves animation-change spikes above 16.7 ms.

Filled lighting, falloff and compositing are unimplemented and unmeasured. Debug outline performance cannot establish their eventual cost.

## Standards

No hard standards violation was found in the inspected lighting path or the user's comment-only working diff. Four architectural hypotheses were identified:

1. **Eager geometry preparation:** `Room#render_data` builds every blocker's world edges even when diagnostics are off ([Room](../../mygame/app/room.rb), lines 43–49, 115–118). It runs once per frame, not once per light. Fresh snapshots are deliberate under ADR-0005. Measurements now put this below 1 ms, so it is not the principal cause.
2. **Repeated unchanged computation:** the preview rebuilds and solves the lamp query every diagnostic frame ([RoomPreview](../../mygame/app/room_preview.rb), lines 114–150). Extending this directly to stationary room sources repeats expensive identical work. Reuse is the strongest measured architectural opportunity, with explicit invalidation required.
3. **Possible duplicated conversion:** world edges become endpoint hashes per source and then numeric bucket records ([Raycasting](../../mygame/app/raycasting.rb), lines 87–111). Sharing source-independent endpoints saved only about 0.2 ms here; this does not justify a new framework or rewriting frame ownership.
4. **Possible duplicated angular work:** endpoint angles are computed for rays and again for bucket spans. Consolidation is a candidate, not a demonstrated gain; bookkeeping could outweigh savings.

Earlier [ADR-0009](../adr/0009-measured-render-preparation.md) rejected a geometry cache for a different workload, and [ADR-0010](../adr/0010-prefer-simple-visible-group-sorting.md) rejected retained ordering after a small gain. The current scene-only measurements likewise give no reason to rewrite Y sorting or fading.

## Spec

No regression or scope creep was found in the user's comment-only diff. Two prototype gaps and two optimization constraints matter:

1. **Coverage gap:** the guide ultimately includes room emitters, but runtime diagnostics currently solve the player only. Debug-off FPS solves none. The all-source probes address measurement coverage without claiming production integration.
2. **Input gap:** room emitters need the agreed radius fallback and owner exclusions. The current player-only helper does not apply those exclusions. The probe applies both, including mounted host groups; production all-source integration must do so too.
3. **Geometry correctness constraint:** flame variants, doors and toggles change blocking geometry. Stationary emitters cannot be cached indefinitely, and other lights' silhouettes cannot silently be excluded for speed.
4. **Visibility constraint:** select lights by influence overlap with the viewport, retaining offscreen sources whose light reaches it. Select their blockers by light range, not screen visibility. Camera movement alone should not invalidate world-space polygons.

Review summary: Standards — 0 hard violations, 4 architectural hypotheses; strongest concern is repeated unchanged solves. Spec — 0 new regressions, 2 prototype gaps and 2 constraints; largest coverage gap is player-only diagnostic casting.

## Proposed sequence

1. **Keep buckets and add per-light polygon reuse first.** A small lighting consumer should own world-space results; Room should expose geometry changes without giving the renderer gameplay knowledge. Key geometry results by source position/radius/exclusions and relevant blocker changes; color/intensity affect composition separately. Begin with conservative invalidation, measure misses, and refine locality using old and new changed-blocker bounds only when needed. A global room revision is simpler but will invalidate many lights whenever flames animate, so do not assume it achieves the exact-input oracle's hit rate. Clear retained data on room replacement/reload. Reuse alone demonstrably removes most solves, but cannot guarantee a 60 FPS worst case.
2. **Benchmark a shared uniform grid with Amanatides–Woo DDA for remaining solves.** Keep the reference endpoint rays, intersection semantics, angle ordering and square border. Store world segments in cells shared by every source; walk each ray's cells near-to-far and stop once no unvisited cell can beat the closest hit. Unlike directional buckets, nearby blockers can prevent testing distant ones in the same direction. First compare shared range selection plus existing buckets, then compare DDA ray queries independently, including index maintenance. Try cell widths of one, two and four tiles. This is the most promising established algorithm to test, not a demonstrated speedup in this Ruby runtime. See the [original paper](https://www.eecs.yorku.ca/~amana/research/grid.pdf) and [research note](many-light-raycasting-research.md).
3. **Keep rendering measurements separate.** Draw all outlines only when inspecting them; consider selecting one light for detailed diagnostics. Measure the eventual polygon fill/composition pass independently. Preserve world-space cache results across camera moves. Small endpoint-sharing or static-transform caches are lower priority at the measured costs.

A grid needs stable segment identities, deduplication across visited cells, conservative boundary handling, per-source exclusions and variant updates. Retain a hit found in a later cell and stop only when traversal has reached its distance. Test against the flat reference for vertical/horizontal rays, negative coordinates, cell edges/corners, long crossing edges, source-on-segment cases, concave/disconnected outlines, changed doors/lights and reload. An acceleration structure preserves existing endpoint-sampling limitations; it does not fix missing visibility events at segment crossings.

Compare total update/build/query/render costs, median and p95/maximum frames, and 1/7/16/32-source workloads with distinct layouts/radii as well as the repeated-position control. Keep current buckets as the correctness/performance control. If uneven density or empty-cell traversal defeats the grid, a static BVH is the next candidate; a dynamic tree and GPU redesign are premature. Rotational sweep remains excluded.

## Reproduction and validation

Opt-in probes do not run in ordinary gameplay or the default test suite:

```sh
bin/rake test tests/lighting_audit_benchmark.rb HEADLESS=1
SDL_VIDEODRIVER=offscreen SDL_AUDIODRIVER=dummy LIBGL_ALWAYS_SOFTWARE=1 bin/rake run -- --eval tests/lighting_audit_playback.rb
```

The benchmark asserts equivalent per-source inputs for shared endpoint preparation and valid polygon output. The full native suite passed **168 tests**; the opt-in audit passed separately. Manual playtesting on the user's hardware and final lighting composition remain outstanding. HD stays disabled.
