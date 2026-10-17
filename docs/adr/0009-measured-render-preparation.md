---
status: accepted
date: 2026-10-16
updated: 2026-10-17
---

# Reuse rendering work at the lifetime of its inputs

Room rendering rebuilt fixed collections and repeatedly calculated the same camera values for each sprite. Native measurements showed avoidable Ruby preparation cost, without establishing a displayed-FPS or GPU bottleneck. Cache room membership until reload and camera drawing values for one draw, accepting each optimization separately only after measurable improvement and regression checks.

This refines implementation under [ADR-0005](0005-render-data-and-room-preview.md); its plain frame interface and responsibility boundaries remain. The snapping math, HD, sampling, and viewport-sized target from [ADR-0001](0001-viewport-sized-camera.md) remain in force.

## Measurement and acceptance

Use the opt-in [native benchmark](../../mygame/tests/render_benchmark.rb), run with `bin/rake test tests/render_benchmark.rb HEADLESS=1`. It measures the real Ritual Gate room and a deterministic three-copy workload with the same viewport. Measure targeted operations and complete Ruby preparation/submission separately, including stationary views, camera pans, fade reversal, and door/light changes. Warm up, then collect seven batches from equivalent initial state with diagnostics off.

Keep an optimization when its targeted median improves by at least 5%, exceeding observed variation, and whole preparation has no repeatable regression. Run targeted regressions, the full native suite, and `bin/rubocop` before committing. Stop the sequence for review if a candidate fails or remains inconclusive; remove only that candidate's changes. Each accepted optimization is a separate commit with its evidence.

[ADR-0010](0010-prefer-simple-visible-group-sorting.md) refines acceptance: passing this numerical gate establishes a speedup, but retention also depends on absolute savings, demonstrated gameplay need, and implementation/interface complexity. It supersedes the cached scenery-ordering acceptance; the other decisions below remain accepted.

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

## 4. Cache transformed fade geometry — rejected at the measurement gate

**Original problem.** Fade checks transform crop-local occupied regions and supporting-base bounds into world coordinates during rendering. Static placed artwork repeats the same transforms, suggesting a shared geometry helper and prepared world-space records that future lighting could also consume.

**Evaluated solution.** Extract the existing exact transforms into `SpriteGeometry`, prepare records shared by fade units at room load, and refresh affected records when a door or mounted light changes appearance. Retain fallback transforms for hand-built frame data, and keep prepared records outside sprite primitives. No silhouette simplification, boundary extraction, or raycasting was added.

**Result.** Relative to accepted changes 1–3:

| Ruby operation, median µs | Ritual Gate before → candidate | Three-copy workload before → candidate |
| --- | --- | --- |
| Foreground fade | 230.302 → 227.572 (1.2% lower) | 643.908 → 626.965 (2.6% lower) |
| Light animation update | 2.721 → 8.484 | 6.968 → 25.810 |
| Complete preparation | 796.138 → 773.260 | 1,981.993 → 2,025.028 |

Both targeted improvements are below 5% and their sample ranges overlap. Complete-preparation differences remain within observed variation; the larger-fixture median is slower. Recomputing geometry on animated appearance changes increased animation-update cost, offsetting some avoided render work. Cheap eligibility gates already reject most units before occupied-region transforms, so the repeated transform cost was smaller than the initial hypothesis suggested for these workloads.

**Decision.** Remove the prepared-geometry cache and its cache-specific regression test; keep the three accepted optimizations. Retain a stateless geometry extraction separately as described below. The corrected candidate passed 143 native tests and lint but failed the performance gate. Record the evidence and pause the sequence before fade bookkeeping, early culling, or cached scenery sorting. These later candidates have not been attempted.

The longer benchmark also caught invalid prepared records after repeated appearance changes using temporary-hash replacement; explicit field assignment passed the repeated sequence and GC checks. This was corrected before the complete candidate measurements above. It is an observation about the discarded implementation, not a change to SDK resources or a proven general SDK diagnosis.

A future attempt could precompute geometry for each immutable placed appearance variant rather than transform it on every appearance change, or first instrument how many transforms the actual fade queries execute. That is a new experiment, not an accepted optimization. The stateless extraction has an existing responsibility shared by fading and preview diagnostics; its value is assessed separately from the failed cache.

## 5. Share stateless sprite geometry — retained as a refactor

**Original problem.** `ForegroundFade` owned source-local to world-space geometry transforms as well as fade policy. Preview diagnostics called through the fade module to draw occupied regions. Bounds, anchors, scaling, and flips describe sprite placement independently of whether an actor should reveal scenery, so the existing callers depended on the wrong owner. The geometry-cache experiment bundled this ownership improvement with a performance hypothesis; rejecting that cache did not invalidate the extraction.

**Decision and mechanism.** Move the existing frame-bounds, alpha-bounds, occupied-region, and individual alpha-rectangle transforms into [`Descent::SpriteGeometry`](../../mygame/app/sprite_geometry.rb). Fading and preview diagnostics call that stateless module directly. Keep the fade loop's lazy region checks, original measurements, strict width rule, and exact transforms. Pixel scanning and per-crop measurement caching stay in the deserializer. No world-space cache, prepared records, variant lifecycle, boundary extraction, or lighting policy is introduced.

**Trade-off.** One small module and explicit geometry calls replace the accidental dependency on fading. This is an architectural decision with two current consumers, not a performance optimization. Acceptance depends on clear ownership and equivalent geometry; benchmark results and the 5% improvement gate do not govern this extraction. Future lighting can reuse these transforms while choosing its own boundary representation. Sprite changes are observed on the next call because nothing is retained.

**Verification.** All 144 native tests and RuboCop pass. Dedicated geometry tests cover crop-local offsets, anchors, unequal scaling, all flip combinations, movement between queries, input preservation, frame fallback, and explicitly empty measurements. Existing import/fade/render/preview tests retain coverage of holes, L-shaped artwork, door/light variants, sorting, and diagnostics. Exploratory timing runs are retained in the evidence note for transparency; they are not the rationale or acceptance criterion for this architectural decision.

## 6. Reduce fade bookkeeping and reject fully opaque targets early

**Original problem.** Each unit allocated an actor-contribution array, replaced its history hash, and ran transition math even when already at its target. Fully opaque frames still copied the world list, and tall artwork could run detailed geometry tests when its vertical gap already guaranteed full opacity.

**Decision and mechanism.** Compute the strongest contribution in a loop and stop at the type minimum. Reuse each unit's history record and perform transition math only when the target differs and elapsed time is positive. Reject geometry eligibility at or beyond the fade radius, while continuing history restoration. Avoid sprite-minimum arrays, skip the order-index scan when there are no actors, and return the original world list when no alpha copies are needed. Frame artwork remains unchanged.

**Trade-off.** Retain opaque unit histories and the active-unit pruning pass. Their timestamps preserve zero additional progression when eligibility changes during a repeated draw in the same tick, and the active set removes units immediately even in that tick. A sparse history scheme would need extra bookkeeping to preserve those semantics; eliminating its records is not necessary for the measured improvement. No prepared geometry or lighting policy is introduced.

**Evidence.** Seven paired batches against commit `1820b3b`, alternating implementation order within one process:

| Ruby operation, median µs | Ritual Gate before → after | Three-copy workload before → after |
| --- | --- | --- |
| Foreground fade | 231.357 → 173.395 (25.1% lower) | 644.485 → 475.922 (26.2% lower) |
| Complete preparation | 794.825 → 704.231 (11.4% lower) | 2,078.728 → 1,787.599 (14.0% lower) |

Targeted ranges are separated in both workloads. Full preparation improved in six of seven real-room pairs (one retained candidate outlier) and all seven larger-workload pairs. All 146 native tests and RuboCop passed. New regressions cover initially opaque repeated draws, eligibility changes within a tick, rewound ticks, restoration exactly at the radius with tall artwork, and same-tick removal of a unit. The user's earlier playtest covers changes through `1820b3b`; this optimization still needs visual confirmation.

## 7. Cull artwork before sorting and applying opacity

**Original problem.** Render sorted every group and applied fade alpha to the full world list before viewport filtering. Offscreen groups therefore paid sorting and preparation costs, especially in a larger room. Moving culling earlier naively would remove supporting bases and alter fade eligibility/history, including for partially visible actors.

**Decision and mechanism.** Preserve full logical drawing order in an object-ID table with comparable keys for floor, descending-depth groups with authored ties, member order, and ceiling. Keep a sprite's final occurrence if its reference appears more than once. Test each group's artwork for viewport intersection before sorting; a visible mounted member retains its group even if the base is offscreen. Cull the assembled artwork before alpha-copy creation and translation. Supply the full order table through the optional `ForegroundFade.apply(draw_order:)` keyword while continuing to evaluate all fade units and histories. Callers omitting that keyword retain the original flat-list integer indices.

**Trade-off.** The full scene still gets a linear order-table pass and fade-unit evaluation; comparable keys allocate each draw. This preserves offscreen supporting relationships and history without adding persistent geometry caches or coupling lighting to render visibility. Avoid sorting offscreen groups and copying their alpha, while retaining the existing frame contract and exact artwork-based culling. A group is tested by its members rather than collider/foot bounds or a potentially stale cached rectangle.

**Evidence.** Seven paired batches against commit `91661be`, alternating baseline/candidate renderer and fade implementations in one process:

| Ruby operation, median µs | Ritual Gate before → after | Three-copy workload before → after |
| --- | --- | --- |
| Render preparation/submission | 679.047 → 611.683 (9.9% lower) | 1,786.151 → 1,181.529 (33.9% lower) |
| Complete preparation | 704.174 → 681.913 (3.2% lower) | 1,738.878 → 1,204.597 (30.7% lower) |

Targeted ranges are separated in both workloads. Complete preparation improved in six of seven real-room pairs and all seven larger-workload pairs. `draw` uses a preassembled stationary frame, output clearing, fade state, and actual renderer submission; `frame` additionally includes the existing actor/animation/pan/variant sequence. All 150 native tests and RuboCop passed. New regressions cover offscreen supporting bases, mounted-only visibility, offscreen fade history for a partially visible actor, and repeated sprite references in differently ordered depth groups. Visual confirmation is still needed for changes after `1820b3b`.

## 8. Cached scenery ordering — superseded and reverted

The cached-ordering optimization accepted in this record at `691b6cb` passed its performance gate, but was reverted in `5c8309f` after reassessing maintenance cost. [ADR-0010](0010-prefer-simple-visible-group-sorting.md) records the replacement decision, the original problem and implementation, and the measured savings. The general stable sort of visible groups is current behavior. Historical measurements are preserved rather than treating the optimization as a failed speed experiment.

## Sequence outcome and lighting constraints

The sequence has been evaluated. Collection caching, camera snapshots, unchanged-light skipping, fade bookkeeping, and early culling remain. The transformed-geometry cache was rejected at the measurement gate; the stateless geometry helper is retained as an architectural decision. Cached scenery ordering was measured and then reverted for disproportionate complexity. It is not a pending implementation task.

Prepare shared alpha geometry with future raycasting in mind. Preserve exact occupied regions for fading; lighting can later derive boundary segments from the same alpha source by removing internal edges and merging contiguous collinear edges. Do not fill holes or replace occupied regions with one bounding rectangle. A lighting blocker policy covering all non-floor scenery is agreed for the future prototype; raycasting, boundary extraction, lighting compositing, and spatial indexing are not implemented by this decision.

Variant `replace` keeps sprite references current, but does not automatically refresh separately derived bounds, regions, or segments. Any geometry cache must account for active door/light appearance, placement, scale, anchors, and flips. Avoid tying lighting blockage to temporary fade opacity.

## Human verification

The user reported playtesting was fine through commit `1820b3b`, covering the three accepted optimizations and the stateless helper. Subsequent changes still need visual confirmation. At the usual enlarged window size, walk and sneak diagonally across camera clamps and room edges, inspect seams and actor/scenery ordering, approach/retreat/reenter faded columns, toggle doors and mounted lights, and reload. Unit tests establish data and coordinate behavior; they do not establish motion quality, appearance, or readability.
