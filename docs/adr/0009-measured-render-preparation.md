---
status: accepted
date: 2026-10-16
---

# Reuse rendering work at the lifetime of its inputs

Room rendering rebuilt fixed collections and repeatedly calculated the same camera values for each sprite. Native measurements showed avoidable Ruby preparation cost, without establishing a displayed-FPS or GPU bottleneck. Cache room membership until reload and camera drawing values for one draw, accepting each optimization separately only after measurable improvement and regression checks.

This refines implementation under [ADR-0005](0005-render-data-and-room-preview.md); its plain frame interface and responsibility boundaries remain. The snapping math, HD, sampling, and viewport-sized target from [ADR-0001](0001-viewport-sized-camera.md) remain in force.

## Measurement and acceptance

Use the opt-in [native benchmark](../../mygame/tests/render_benchmark.rb), run with `bin/rake test tests/render_benchmark.rb HEADLESS=1`. It measures the real Ritual Gate room and a deterministic three-copy workload with the same viewport. Measure targeted operations and complete Ruby preparation/submission separately, including stationary views, camera pans, fade reversal, and door/light changes. Warm up, then collect seven batches from equivalent initial state with diagnostics off.

Keep an optimization when its targeted median improves by at least 5%, exceeding observed variation, and whole preparation has no repeatable regression. Run targeted regressions, the full native suite, and `bin/rubocop` before committing. Stop the sequence for review if a candidate fails or remains inconclusive; remove only that candidate's changes. Each accepted optimization is a separate commit with its evidence.

[Benchmark samples and methodology](../notes/rendering-benchmarks.md) retain exact timings, ranges, workload counts, and environment. These measurements exclude engine draw execution and GPU work. They do not establish FPS improvements or visual correctness. Full-preparation differences include allocation/GC effects and host noise; avoid attributing every change to one method's execution time.

## 1. Prepare room collection membership once

**Original problem.** `Room#render_data` concatenated floor arrays, filtered mounted objects, allocated a group hash per root object, and rebuilt every mounted sprite list on every call. The authored membership and scenery depths do not change during a room's lifetime. Door and light changes update existing sprite hashes in place rather than replacing their references.

**Decision and mechanism.** Prepare the floor sprite list and scenery groups after resolving mounted relationships during Room initialization. `render_data` duplicates outer floor/group/ceiling/fade-unit arrays so a consumer can append or clear entries without changing room membership. Nested groups and their sprite lists remain room-owned, read-only structural data. Door/light `replace` updates remain visible through their shared sprite references. Reload creates fresh collections and groups.

**Trade-off.** Retaining group structure uses a small amount of room-lifetime storage and makes its ownership explicit. A future mechanic that changes scenery membership or depth must rebuild affected structures; mutating a nested group returned in a frame is unsupported. Rebuilding everything each frame was simpler but repeated work proportional to room size. Returning the room's mutable outer arrays directly would let appending actors leak into later frames.

**Evidence.** Relative to the original baseline:

| Ruby operation, median µs | Ritual Gate before → after | Three-copy workload before → after |
| --- | --- | --- |
| Room render data | 53.500 → 0.578 (98.9% lower) | 169.096 → 0.580 (99.7% lower) |
| Complete preparation | 1,078.534 → 986.838 | 2,686.271 → 2,171.980 |

Targeted sample ranges are separated. All 141 native tests and RuboCop passed. Added coverage verifies outer collection isolation, mounted membership, live door/light artwork, and fresh room rebuilds.

## 2. Capture camera values for one draw

**Original problem.** Each visible sprite recalculated screen-center and camera-center snapping, render scale, and translation offsets. Separate visibility queries also rebuilt viewport hashes. Those inputs are constant throughout one draw, but display scale can change between draws even if the camera does not move.

**Decision and mechanism.** `Camera#for_drawing` returns a camera copy containing one snapshot of dimensions, render scale, snapped offsets, and screen/world viewports. `Render.draw` uses one snapshot across all sprite, border, and marker batches. Standalone array conversions take one snapshot per batch, including nested arrays; ordinary point conversions on the original camera remain live. Cached viewport hashes are read-only inputs.

**Trade-off.** One camera copy and a few small hashes replace repeated arithmetic for every sprite. Refreshing each draw avoids a display-change invalidation mechanism and leaves the original camera uncached. Persisting these values until `follow` would become stale on display changes without movement. The drawing snapshot is disposable and must not be followed or retained across frames.

**Evidence.** Relative to the accepted collection-cache implementation:

| Ruby operation, median µs | Ritual Gate before → after | Three-copy workload before → after |
| --- | --- | --- |
| Camera batch | 333.028 → 160.950 (51.7% lower) | 299.333 → 154.916 (48.2% lower) |
| Complete preparation | 986.838 → 808.303 | 2,171.980 → 1,999.803 |

Targeted sample ranges are separated; neither full-preparation workload regressed. All 142 native tests and RuboCop passed. Added coverage checks scale changes without following, independent snapshots, and nested batches; existing tests cover fractional raster placement, negative coordinates, culling, stable ordering, and renderer output.

## 3. Copy light artwork only when its appearance changes

**Original problem.** Each light selected its animation frame and copied the selected sprite hash on every tick, although current frames last nine ticks. Disabled lights also repeatedly copied the same unlit artwork. Neither operation changed the visible result on most ticks.

**Decision and mechanism.** Skip the artwork update when the selected lit-frame reference is unchanged. Remember the last applied variant on the Light entry and skip `replace` when it is already active. Keep selecting the global lit frame while disabled, so enabling immediately joins the last supplied tick, including after skips or rewinds. No internal animation clock is added; enabled changes still use the explicit setter and preserve sprite identity.

**Trade-off.** A retained variant reference and identity checks replace redundant copying. The variant templates are room-owned data; appearance changes go through the room setters. This avoids introducing a last-tick cache or a separate disabled-light timing path merely to eliminate a small frame-selection calculation.

**Evidence.** Relative to the accepted camera-snapshot implementation:

| Ruby operation, median µs | Ritual Gate before → after | Three-copy workload before → after |
| --- | --- | --- |
| Light animation update | 4.147 → 2.721 (34.4% lower) | 10.368 → 6.968 (32.8% lower) |
| Complete preparation | 808.303 → 796.138 | 1,999.803 → 1,981.993 |

All seven targeted real-room samples and six of seven larger-fixture samples are below their respective previous minimum; one larger-fixture outlier is retained in the raw data. Full-preparation differences are within noise, with no repeatable regression. All 142 native tests and RuboCop passed, including disabled-to-enabled transitions, initial disabled state, unequal frame durations, tick boundaries, rewinds, mounted artwork, and reloads. No additional rendering-output test was added to duplicate this existing coverage.

## Remaining candidates and lighting constraints

The remaining agreed sequence is shared/prepared alpha geometry, fade bookkeeping and early rejection, earlier culling, then cached stationary scenery order. These are candidates, not implemented decisions or measured benefits. Reassess each against the latest accepted baseline and record its problem, mechanism, trade-offs, and evidence here when evaluated.

Prepare shared alpha geometry with future raycasting in mind. Preserve exact occupied regions for fading; lighting can later derive boundary segments from the same alpha source by removing internal edges and merging contiguous collinear edges. Do not fill holes or replace occupied regions with one bounding rectangle. A lighting blocker policy covering all non-floor scenery is agreed for the future prototype; raycasting, boundary extraction, lighting compositing, and spatial indexing are not implemented by this decision.

Variant `replace` keeps sprite references current, but does not automatically refresh separately derived bounds, regions, or segments. Any geometry cache must account for active door/light appearance, placement, scale, anchors, and flips. Avoid tying lighting blockage to temporary fade opacity.

## Human verification

Visual playtesting remains outstanding. At the usual enlarged window size, walk and sneak diagonally across camera clamps and room edges, inspect seams and actor/scenery ordering, approach/retreat/reenter faded columns, toggle doors and mounted lights, and reload. Unit tests establish data and coordinate behavior; they do not establish motion quality, appearance, or readability.
