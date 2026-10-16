---
status: accepted
date: 2026-10-05
updated: 2026-10-11
---

# Render the camera into a viewport-sized target

The previous camera drew the entire world into a texture sized to the world's far edges, then cropped and magnified a window from that texture. This tied texture dimensions to both map size and map origin. Use DragonRuby's camera-space/world-space sample pattern: filter artwork in world space, translate visible primitives into a viewport-sized target, then display that target.

The camera uses `Grid.w` and `Grid.h` as the logical target dimensions. `Geometry.find_all_intersect_rect` selects primitives whose artwork intersects the viewport, including anchored sprites that are only partly visible. Coordinate conversion changes placement without rescaling destination dimensions, atlas crops, or anchors. World origin and map extent do not determine texture size; negative world coordinates work through translation.

Follow the player's fractional world position immediately. Clamp the camera center to map bounds on each axis; center a world axis that is smaller than the view. Snap the world camera center and the screen center to physical display pixels using `Grid.render_scale`, then subtract them to obtain the shared translation. Snap artwork world positions to that same grid before translation. Preserve fractional gameplay and authored coordinates, and use the same translation for every world primitive, inverse conversion, and viewport culling. At an edge, the camera stops and the player moves across the screen.

The confirmed configuration is **HD on, pixel-art sampling, and camera/artwork drawing alignment**. Coordinates stay logical, while rounding follows the native raster: at render scale 5.5, one rounding step is one display pixel, or about 0.182 logical units. With HD off, the same calculation correctly rounds to a coarser one-logical-pixel step, which is then enlarged into approximately five or six display pixels. HD makes the drawing grid finer; it does not make previously incorrect arithmetic correct, and font glyphs do not participate in the camera calculation. See the [rendering glossary](../../GLOSSARY.md#rendering).

## Drawing investigation, 2026-10-11

| Step | Evidence and outcome |
| --- | --- |
| Fractional translation based on the SDK camera sample | Sprite atlas rendering exposed intermittent tile-edge lines that the earlier solid-shape playground had not revealed. |
| Snap the camera to whole logical pixels | Initially reduced lines, but fractional player movement against the snapped camera introduced diagonal player wobble. |
| Snap artwork as well, using `to_draw_space` | Kept the followed player stable. Enlarged-window lines and occasional whole-room diagonal jumps remained. This helper predates the final display-pixel fix. |
| Divide target dimensions and destination geometry by the HD scale | Passed coordinate checks and a static capture, but caused widespread sprite wobble in playtesting. Reverted. |
| Compare rendering paths and samplers | F3 direct versus target made no meaningful difference. The user reported a 5.5× render scale and found that F4 pixel-art sampling removed most lines; the remaining flashes coincided with whole-room diagonal jumps. |
| Probe an atlas matching the real floor sheet | Reproduced neighbouring-tile colour when logical snapping placed tile boundaries between physical display pixels. A simpler power-of-two atlas probe had stayed clean and had not reproduced this case. |
| Snap camera, screen center, and artwork to display pixels | Removed the reproduced edge bleed; 64 renderer captures and multi-scale coordinate tests passed. The user subsequently confirmed that the fix worked perfectly. |

Whole-logical-pixel rounding makes camera steps 5.5 display pixels at that scale, and some tile boundaries fall halfway through a physical pixel. Rounding X and Y independently at this coarse resolution can stagger diagonal steps. Aligning to the physical raster permits smaller camera steps while keeping tile boundaries aligned.

A PNG probe matching the floor atlas's 544 × 544 dimensions and crop (224, 512, 32, 32) reproduced neighbouring-tile colour on those half-pixel edges with the pixel-art sampler. Moving the same geometry onto physical display pixels eliminated that colour in all 16 tested offsets. The production camera then passed 64 fractional-offset captures across direct and target rendering at 4.25× and 5.5×. This replaces logical-pixel snapping with display-pixel snapping; it does not resize targets, scale sprite geometry inversely, or change source crops. Automated verification comprised 62 passing native tests, clean RuboCop, and actual OpenGL renderer captures; the user's subsequent playtest confirmed the visual result.

The camera and artwork share a half-pixel rounding rule, including negative coordinates. The screen center is snapped as well because an odd-height native canvas has its geometric center between display pixels. Coordinate conversion remains reversible, while raster placement is a separate `to_draw_space` operation. Draw space uses the same logical units as screen space: it is our name for preparing rounded sprite positions, rather than an additional render target or SDK coordinate system. The [SDL pixel-art shader](https://github.com/libsdl-org/SDL/blob/main/src/render/opengl/SDL_shaders_gl.c) filters texture boundaries; the probe demonstrates why atlas boundaries need display-aligned geometry here.

The initial mistake was treating a logical artwork pixel as the native raster pixel under HD. Numeric tests proved adjacency in logical coordinates but did not establish GPU sampling at fractional display scales. Enlarged-window renderer probes should have accompanied the initial rounding change. This policy is a project addition derived from reproduction and playtesting; the SDK sample supplies the camera conversion and target pattern, not this snapping implementation.

HD mode also enlarges render targets: a nominal 320 × 180 target becomes 1360 × 765 physical pixels at a 4.25× render scale. During the investigation, F3 temporarily bypassed the intermediate target while preserving sprite placement, cropping, and order. The user reported the same artifacts in both paths. Normal rendering retains the target and HD HUD text. The F3/F4 comparison switches were removed on 2026-10-12; rendering always composites the target and sampling inherits game metadata.

The user completed sequential game playtests with pixel-art sampling throughout:

| Configuration | Reported result |
| --- | --- |
| HD off; camera and artwork rounding | No visible gaps, atlas bleed, or tile seams; occasional very mild diagonal camera jitter. |
| HD off; camera rounding, screen-space-only artwork | Floors stayed clean; player-sprite jitter and occasional severe blur/low fidelity. |
| HD on; camera and artwork rounding restored | All jitter gone; no visible gaps, atlas bleed, or tile seams. Selected configuration. |

HD off did not make per-sprite rounding dispensable in the tested pixel-art-sampled configuration. Restoring HD with drawing alignment resolved the remaining reported movement issues; the native grid's finer steps provide a coherent explanation, while the selected combination is supported by the actual playtest. These observations do not claim identical behaviour on every display or driver.

The camera performs translation only. Display magnification belongs to the reference-resolution configuration in [ADR-0002](0002-reference-resolution-and-ui-fonts.md). Draw HUD labels and world annotations directly to the screen above the scene; use the camera conversion to position world annotations. R reloads the room and resets the player to Spawn.

## Consequences

- Target dimensions are bounded by the logical viewport rather than the world. The SDK controls HD target enlargement. This removes the full-world texture growth problem; it does not establish a measured GPU speedup.
- Visible primitives require coordinate conversion and new hashes. The renderer now culls groups before final ordering, reuses prepared scenery order, and preserves full-scene fade-order metadata; its linear scans still grow with scene size. See [ADR-0009](0009-measured-render-preparation.md) for the measured changes and trade-offs, and the [rendering research](../notes/rendering-optimizations.md) for other options.
- Camera following, edge clamping, small-world centering, source crops, partial visibility, fractional gameplay coordinates, display-pixel placement at multiple scales, and equivalent direct-render placement remain covered by native tests. Game feel and rasterized motion still require playtesting.

## Implementation and sources

- [Camera](../../mygame/app/camera.rb), [renderer](../../mygame/app/render.rb), and [sprite geometry](../../mygame/app/sprite.rb). Target setup and compositing now belong to Render; the camera's coordinate calculations remain unchanged. See [ADR-0005](0005-render-data-and-room-preview.md).
- [Camera regression tests](../../mygame/tests/camera_test.rb) and [player sprite tests](../../mygame/tests/player_sprite_test.rb).
- Installed SDK reference: `$DRAGONRUBY_HOME/samples/07_advanced_rendering/16_camera_space_world_space_simple/app/main.rb`. Its `Camera` is example code, not an SDK helper class.
- That sample converts fractional positions without display-pixel snapping and renders scattered square sprites; it does not demonstrate this tightly packed atlas or its failure case.
- SDK APIs: `$DRAGONRUBY_HOME/docs/api/geometry.md`, `find_all_intersect_rect`; `$DRAGONRUBY_HOME/docs/api/outputs.md`, render targets and output order. These references were inspected in DragonRuby 7.21.
