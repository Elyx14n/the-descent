---
status: accepted
date: 2026-10-17
---

# Prefer general visible-group sorting over a cached scenery-order protocol

Update: [ADR-0015](0015-use-colliders-for-foreground-fading.md) retires the shared SpriteGeometry module and alpha/polygon fade geometry. Other retained preparation changes and the simple sorting decision still apply; measurements below describe their historical workload.

Cached scenery ordering reduced measured Ruby preparation time but added more interface and implementation complexity than the current game warrants. Retain the general stable sort of visible groups and remove the sorted-prefix hint, validation, and actor-merge path. This supersedes the cached-ordering acceptance recorded in [ADR-0009](0009-measured-render-preparation.md) at commit `691b6cb`; its other rendering decisions remain in force.

## Original problem and evaluated solution

After early culling, the renderer still sorted 20–31 visible groups per draw. Commit `691b6cb` sorted room scenery once during loading and added `ordered_group_count` to frame data. Render partitioned visible groups into the ordered scenery prefix and appended actors, checked the prefix, sorted the actor tail, and merged the lists. A fallback preserved general sorting for missing or stale hints.

The optimization worked in its measured scope. The question is whether that saving justified the extra concepts maintained across Room, frame assembly, and Render.

## Evidence and practical value

Seven paired native benchmark batches compared the implementation against `4fb5a3f`. Values below are median milliseconds per operation; setup was outside the timer. The larger fixture loads three copies of the room's scenery with the same viewport.

| Ruby measurement | Ritual Gate before → candidate | Three-copy workload before → candidate |
| --- | --- | --- |
| Visible-group ordering | 0.082233 → 0.016122 | 0.083738 → 0.017433 |
| Full render preparation and submission | 0.714609 → 0.656265 | 1.204396 → 1.108700 |
| Full-preparation saving | 0.058344 ms | 0.095696 ms |

The approximately 80% ordering improvement was real, but the corresponding full-preparation savings were small in absolute terms. The current-room saving is about 0.35% of a 16.67 ms budget for 60 FPS; this puts the benchmark result in context, without establishing actual gameplay frame time or FPS improvement. Input handling, gameplay collision, engine drawing, and GPU execution were outside this measurement. The targeted ordering test and full-preparation test also used different workloads: stationary visible groups versus a scripted sequence with movement and state changes. Their savings need not match exactly.

The game had no demonstrated sorting-induced frame-deadline problem. [Historical raw samples](../notes/rendering-benchmarks.md#cached-scenery-ordering-and-actor-merge--reverted) remain available; the revert does not invalidate the measurements.

## Decision and consequences

Revert `691b6cb`, as done in `5c8309f`. Room retains its cached collection membership and shared sprite references. Render culls groups, then performs one general stable depth sort with source-index ties. No sorted-prefix field or separate actor-merge protocol remains.

This accepts the measured CPU cost of general sorting in exchange for a smaller frame interface and one ordering path. Maintainers no longer need to reason about prefix counts, prefix validity, fallback behavior, or rebuilding prepared order when scenery membership/depth changes. This trade-off fits the current room size and a small amateur team's preference for understandable code.

The shared stateless sprite-geometry helper and the other accepted rendering changes are retained. Future lighting can consume alpha geometry without this ordering protocol. Early culling's separate full-scene fade-order metadata also remains; this decision does not reverse that change.

Passing a targeted speed threshold is evidence that an optimization is faster, not sufficient reason to retain it. Future decisions must also weigh absolute frame-preparation savings, demonstrated gameplay pressure, interface complexity, and maintenance cost. Small local changes can remain worthwhile for modest savings; adding a protocol across callers needs stronger justification.

Revisit cached ordering only if representative gameplay profiling shows sorting materially contributes to missed frame deadlines or consumes needed CPU budget, and a simpler approach is insufficient. More scenery or planned lighting alone does not establish that need. No runtime code changes are made by this record; the user already performed the revert.
