---
status: accepted
date: 2026-10-05
---

# Render the camera into a viewport-sized target

The previous camera drew the entire world into a texture sized to the world's far edges, then cropped and magnified a window from that texture. This tied texture dimensions to both map size and map origin. Use DragonRuby's camera-space/world-space sample pattern: filter artwork in world space, translate visible primitives into a viewport-sized target, then display that target.

The camera uses `Grid.w` and `Grid.h` for the target dimensions. `Geometry.find_all_intersect_rect` selects primitives whose artwork intersects the viewport, including anchored sprites that are only partly visible. The conversion changes positions without changing sprite dimensions, source crops, or anchors. World origin and map extent do not determine texture size; negative world coordinates work through translation.

Follow the player's fractional world position immediately. Clamp the camera center to map bounds on each axis; center a world axis that is smaller than the view. Preserve fractional sprite positions through the same coordinate conversion instead of rounding the camera and sprite independently. This keeps the followed player's screen position constant while the camera can move freely. At an edge, the camera stops and the player moves across the screen. Rasterization can still produce visible pixel steps; the coordinate rules do not promise artifact-free motion at every display size.

The camera performs translation only. Display magnification belongs to the reference-resolution configuration in [ADR-0002](0002-reference-resolution-and-ui-fonts.md). Draw HUD labels and world annotations directly to the screen above the scene; use the camera conversion to position world annotations. Hot reload refreshes edited map bounds without resetting the player.

## Consequences

- Target dimensions are bounded by the viewport rather than the world. This removes the full-world texture growth problem; it does not establish a measured GPU speedup.
- Visible primitives require coordinate conversion and new hashes. The current renderer still builds all primitives and sorts all entities before filtering, so CPU preparation continues to grow with the object count. See the [rendering optimization notes](../notes/rendering-optimizations.md) for possible later changes.
- Camera following, edge clamping, small-world centering, source crops, partial visibility, and fractional coordinate behavior remain covered by native tests. Game feel and rasterized motion still require playtesting.

## Implementation and sources

- [Camera](../../mygame/app/camera.rb), [render loop](../../mygame/app/collision_playground.rb), and [sprite geometry](../../mygame/app/sprite.rb).
- [Camera regression tests](../../mygame/tests/camera_test.rb) and [player sprite tests](../../mygame/tests/player_sprite_test.rb).
- Installed SDK reference: `$DRAGONRUBY_HOME/samples/07_advanced_rendering/16_camera_space_world_space_simple/app/main.rb`. Its `Camera` is example code, not an SDK helper class.
- SDK APIs: `$DRAGONRUBY_HOME/docs/api/geometry.md`, `find_all_intersect_rect`; `$DRAGONRUBY_HOME/docs/api/outputs.md`, render targets and output order. These references were inspected in DragonRuby 7.21.
