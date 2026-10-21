# Precedents for paired diagonal camera stepping

Investigated 2026-10-21 against the current [CameraScroll](../../mygame/app/camera_scroll.rb), [ADR-0018](../adr/0018-pair-diagonal-camera-pixel-steps.md), [camera framing decision](../adr/0017-keep-preview-camera-on-player.md), and [HD-off constraint](../adr/0013-keep-hd-disabled.md). This note records the investigation before replacement; the user subsequently requested and authorized the published implementation, now adopted under [ADR-0019](../adr/0019-use-direction-aware-camera-rounding.md). The segment-based comparisons below are historical. Coordinate terminology follows the [glossary](../../GLOSSARY.md#rendering).

## Finding

The underlying solution is established: choose pixel placement using the direction of travel so that independent coordinate rounding does not turn a straight diagonal into alternating horizontal/vertical steps. There are original descriptions from 2011 and published community implementations for Godot and Unity. These are community techniques, not evidence that engine pixel-perfect cameras conventionally include this behavior.

Our exact segment-origin implementation is a related project adaptation. The sources below do not establish its particular combination of cumulative distance, nearest previous-position reanchoring, pause retention, reset threshold, and restriction to 45-degree motion as a standard camera algorithm. This search cannot establish that no identical implementation exists elsewhere.

## Primary precedents

### Direction-aware pixel rounding, 2011

In [Ilmari Karonen's original answer](https://gamedev.stackexchange.com/questions/18787/how-does-one-avoid-the-staircase-effect-in-pixel-art-motion#18801), the algorithm rounds the dominant coordinate, moves along the velocity direction to that grid line, then rounds the other coordinate. For Y-dominant motion:

```text
draw_y = round(y)
draw_x = round(x + (draw_y - y) * velocity_x / velocity_y)
```

For straight 45-degree motion, the coordinate difference or sum stays constant, so the formula advances both axes together. This is our algebraic inference, assuming a consistent nearest-rounding convention; exact ties and floating-point boundaries still need explicit checks when porting.

The discussion reports backwards jumps during slow curved motion; the author suggests retaining a closer previous rounded point. This is a sprite-motion algorithm, not a documented engine camera facility. [Original discussion](https://gamedev.stackexchange.com/questions/18787/how-does-one-avoid-the-staircase-effect-in-pixel-art-motion#18801).

### Unity rendering implementation, 2023

[fnnbrr's SmoothPixelPerfectRenderer](https://gist.github.com/fnnbrr/4938adc5439ab70c55430b020790b531) implements that same direction-aware formula for a child renderer used with Unity's Pixel Perfect Camera. It estimates velocity from the parent's current and previous precise positions, writes the rounded result only to the child transform, and supports slopes beyond 45 degrees. At rest it rounds both absolute coordinates independently. It explicitly credits the 2011 answer and an earlier Godot implementation. The [GitHub API record](https://api.github.com/gists/4938adc5439ab70c55430b020790b531) contains the complete source and creation timestamp, 2023-09-05.

This is a particularly relevant reusable precedent: physics remains precise while presentation follows a direction-aware quantizer. It is not Unity's built-in Pixel Perfect Camera implementation, and it does not use our segment-origin state or preserve the moving quantization phase on stopping.

### Godot implementation and phase alignment

The [2019 Godot author's post and code](https://www.reddit.com/r/godot/comments/cvn6qn/ive_figured_out_a_way_to_smooth_out_jittery/) implements the same dominant-axis formula for eight-way movement. However, the posted code modifies a kinematic body's position, and the discussion reports collision problems. Its existence establishes reuse of the direction-aware idea, not suitability of modifying our gameplay positions.

A [separate 2023 Godot author's report](https://www.reddit.com/r/godot/comments/16lft93/fix_for_pixelperfect_diagonal_movement_causing/) describes the exact mismatched X/Y phase symptom and solves it by rounding gameplay position when input changes. It avoids rounding on release because that produced a visible snap. This is close to our phase-reanchoring motivation, but our implementation keeps gameplay fractional and stores presentation history instead. The report is first-person community evidence, not official Godot guidance or a formal guarantee.

### Explicit equal-phase suggestion

An original [Lexaloffle discussion](https://www.lexaloffle.com/bbs/?tid=147734) includes an October 2025 suggestion to align the fractional parts of X/Y during 45-degree movement so both coordinates round together. This independently states the phase-pairing idea. The main March 2025 cartridge instead buffers whole-pixel gameplay movement and approximates normalized speeds; it is not our algorithm. The comment proposes the equal-phase idea without supplying our stateful camera implementation.

### Camera integration is not automatically interchangeable

The original author of the [CrossCode staircase-effect mod](https://github.com/Unarelith/cc-staircase-effect-fix) reports trying the 2011 direction-aware rounding method and retaining it as an optional reference, but finding camera integration problematic. The released default uses camera smoothing and timer precision changes instead, with camera lag as a stated consequence. This is first-party evidence about that mod, not a claim about all cameras. It cautions against treating a shared mathematical idea as a drop-in engine-independent implementation.

## What the engine implementations conventionally do

There is no single engine-independent camera algorithm covering all pixel-art motion preferences. The inspected built-in implementations and official examples establish several reusable building blocks:

| Primary implementation | Observed behavior | Comparison with this game |
| --- | --- | --- |
| [Unity URP PixelPerfectCamera source](https://github.com/Unity-Technologies/Graphics/blob/master/Packages/com.unity.render-pipelines.universal/Runtime/2D/PixelPerfectCamera.cs) | `RoundToPixel` rounds absolute X/Y/Z independently; `PixelSnap` uses that result in the camera matrix. | Our nearest cardinal placement is comparable. The direction-dependent segment history in CameraScroll is an addition. |
| [Godot pixel snapping](https://docs.godotengine.org/en/stable/classes/class_projectsettings.html#class-projectsettings-property-rendering-2d-snap-snap-2d-transforms-to-pixel) | Rendering can snap positions while logical positions remain fractional; the docs explicitly warn that movement can become less smooth. | We follow the separation between precise gameplay and drawing placement. These settings do not document our paired-step policy. |
| [raylib smooth-pixelperfect example](https://github.com/raysan5/raylib/blob/master/examples/core/core_smooth_pixelperfect.c) | Rasterizes against an integer camera, then applies its scaled fractional remainder when presenting onto a larger framebuffer. | Our native 320 × 180 main framebuffer cannot reproduce that finer final positioning simply by shifting a texture within it. |

The [Godot resolution guide](https://docs.godotengine.org/en/stable/tutorials/rendering/multiple_resolutions.html#stretch-settings) likewise distinguishes low-resolution viewport rendering followed by enlargement from rendering 2D directly at the target resolution. It recommends integer enlargement for uniform pixel-art scaling. That output-grid choice is separate from coordinating motion on the existing native grid.

The installed DragonRuby 7.21 camera-space/world-space sample (`$DRAGONRUBY_HOME/samples/07_advanced_rendering/16_camera_space_world_space_simple/app/main.rb`) supplies reversible coordinate transforms, culling, and a viewport target. Its conversions preserve fractional coordinates and it has no direction-aware stepping history. Our coordinate structure follows it; CameraScroll extends it.

These are source observations, not evidence that one default engine setting guarantees the user's preferred diagonal motion. The 2011/community technique is a relevant published alternative to the default independent rounding.

## Where our implementation differs

Inspection of the earlier CameraScroll implementation established the following before the re-adaptation:

| Aspect | Earlier segment-based project implementation | Direction-aware 2011/Unity implementation |
| --- | --- | --- |
| Shared rounding quantity | Distance from the start of a diagonal segment | Absolute dominant-axis coordinate |
| Direction support | Cardinal and equal-magnitude X/Y movement | General nonzero slopes |
| Stationary frames | Keep the previous raster result | Unity example returns to ordinary nearest rounding |
| Turns | Start a new segment from the previous precise position and its nearest pixel | Use the current local velocity; no segment origin |
| History | Previous point, segment origin, direction, raster base/result | Previous point only when needed to estimate velocity |
| Gameplay | Unchanged fractional positions | Unity child renderer also preserves parent gameplay positions |

Our rounding phase is history-dependent: reaching the same precise point through another route can yield another nearby raster point. A diagonal segment holds that phase through stops and speed changes. It bounds each coordinate's error to approximately one raster pixel, rather than ordinary nearest rounding's half-pixel bound. Reanchoring uses `nearest(previous precise position)`, not necessarily the previous raster result, so turning can still cause a one-pixel correction.

Straight-segment travel is computed from displacement, not by counting callbacks, so changing callback frequency does not change its intended speed. Direction detection and reanchoring use observed consecutive samples, though; sampling across a turn can change which segments are observed. The `4 * scale` per-axis jump guard is also a project policy rather than part of the cited algorithm. These are reasons to keep turn, stop, collision-slide, reset, and irregular-sampling checks when comparing implementations.

## Interpretation

It is accurate to say our implementation independently rediscovered an established family of direction-aware pixel placement, then added a project-specific segment policy. Calling it unprecedented would be incorrect. Calling the exact class a standard engine camera solution would also exceed the evidence.

The strongest conventional candidate for a comparison is the short dominant-axis formula, applied only to camera presentation. It offers broader slope support and less state. It should be measured against our confirmed straight-diagonal fix and stop/turn behavior before replacement; source precedent alone does not establish that its rest-phase snap or turning corrections are acceptable here. Higher-resolution final presentation is a separate conventional approach, already examined in the [broader rendering research](conventional-pixel-art-rendering-sources.md), and would change the current native-raster policy.

The user prefers conventional, reusable solutions first. Evaluate the published algorithm against the existing native-grid constraints before expanding the specialized implementation. Preserve only local policy needed to pass the established motion scenarios, and document any deviation. No runtime or test changes were made for this investigation.


## Published implementation adopted

The user requested re-adaptation to the published implementation. CameraScroll now uses dominant-axis projection for general slopes and stores only the previous precise position for inferred direction. The segment origin/base, 45-degree branch, epsilon, pause retention, and four-world-pixel reset threshold are removed. RoomPreview supplies its current fixed-step displacement during interpolated drawing, using the simulation-velocity input explicitly permitted by the source Unity example. This avoids the noisy render-frame dominant-axis changes measured in the first port. Ordinary nearest placement at rest is retained, including its possible one-pixel settling correction. DragonRuby adaptations are native render scale and the existing shared rounding-tie convention. See [ADR-0019](../adr/0019-use-direction-aware-camera-rounding.md) for the decision and verification.

Implementation verification: all 199 native tests and RuboCop pass. Normal-speed user playtesting of stopping and turning remains pending.
