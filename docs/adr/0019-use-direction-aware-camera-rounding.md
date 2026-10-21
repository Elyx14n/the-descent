---
status: accepted
date: 2026-10-21
---

# Use published direction-aware camera rounding

The user prefers conventional, reusable solutions and explicitly requested replacing the project-specific diagonal segment algorithm with the [published direction-aware approach](https://gamedev.stackexchange.com/a/18801), also used by [fnnbrr's Unity rendering component](https://gist.github.com/fnnbrr/4938adc5439ab70c55430b020790b531). Adopt that algorithm for camera drawing placement. This supersedes the segment-distance policy in [ADR-0018](0018-pair-diagonal-camera-pixel-steps.md), preserving its native target dimensions and separate precise actor placement.

Round the dominant movement coordinate to the native pixel grid, project along the movement direction to that grid line, then round the other coordinate. The same formula handles cardinal, diagonal, shallow, and steep motion. At rest, use ordinary nearest placement, following the Unity example. CameraScroll retains only the previous precise world position for callers that infer direction; it has no segment origin, cumulative distance, 45-degree test, epsilon threshold, pause-retention rule, jump threshold, or scale-change history rule.

The published implementation permits supplying simulation velocity instead of estimating it from rendering frames. RoomPreview supplies the current fixed-step displacement when presenting an interpolated position; only the direction ratio is needed, so displacement per step is equivalent here. This avoids dominant-axis switches caused by small numeric differences between interpolated samples. Other Camera consumers can omit velocity and infer it from consecutive precise positions. Camera drawing copies share the helper; existing preview resets discard its previous-position history for reloads, teleports, respawns, and discarded clock intervals.

Adaptation to DragonRuby uses `Grid.render_scale` and the camera's existing nearest rounding convention, `(value * scale + 0.5).floor / scale`, consistently for both coordinates. This preserves the project's tie convention rather than importing Unity's rounding API. The algorithm affects only drawing placement: gameplay/collision remain fractional, the followed player uses the precise camera and final artwork-bound alignment, and scenery/lightmap targets stay 320 × 180 at `(0, 0)`. HD remains off under [ADR-0013](0013-keep-hd-disabled.md).

The published rest behavior can settle by a pixel when motion stops; without supplied velocity, initialization also needs a moving sample before direction is known. Slow curves and direction changes remain subject to the limitations discussed by the original author. No additional motion heuristics are introduced to conceal those differences. Manual normal-build playtesting should check walking/sneaking diagonally, stopping, turning, and wall sliding.

Native regressions cover four diagonal directions and walking/sneaking, positive/negative fractional phases, shallow/steep slopes, supplied simulation direction, first/stationary placement, turns/sliding, resets, display-grid changes, interpolation copies, and centered direct actors. A 96-callback actual-room renderer playback completes with player anchors `(160, 66)` throughout. Tracing the supplied-velocity version removes the isolated two-pixel northwest step found with inferred render-frame direction; the remaining axis-only steps occur during collision/sliding transitions. Automated placement checks do not establish subjective smoothness. The [precedent comparison](../notes/diagonal-camera-stepping-precedents.md) records the source distinction between community practice and engine defaults.

Implementation verification: all 199 native tests and RuboCop pass. Normal-speed user playtesting of stopping and turning remains pending.
