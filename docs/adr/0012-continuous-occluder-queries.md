---
status: superseded
superseded_by: 0015-use-colliders-for-foreground-fading.md
date: 2026-10-17
---

# Query and display the generated occluder polygons directly

Retired by [ADR-0015](0015-use-colliders-for-foreground-fading.md): active colliders replace all alpha-derived fade geometry, and the generated pipeline and magenta overlay are removed. The remaining text records the historical decision.

Playtesting confirmed the generated occluders worked, but debug mode showed the many horizontal rectangles derived from them. Those rectangles retained unnecessary geometry and obscured the approved polygon simplification. Use the generated polygons directly for foreground-fade queries and debug outlines. The user accepted small eligibility changes along slopes caused by removing row-center sampling.

This supersedes [ADR-0011](0011-generated-tile-occluders.md)'s runtime representations and debug overlay. Its build pipeline, two-source-pixel tolerance, retained disconnected components, filled holes, atlas freshness checks, and explicit regeneration/reload workflow remain in effect. Collision remains authored independently in Tiled.

## Shared geometry, consumer-specific selection

Lighting's geometry policy was subsequently resolved in [ADR-0014](0014-use-collider-bases-for-lighting.md): it uses authored collider bases rather than these projected visual outlines. The generated polygons and the fading/debugging decisions below remain unchanged.

Each generated tile contains counterclockwise polygon rings and overall bounds in crop-local bottom-left coordinates. Rings omit the repeated closing vertex. Format 4 removes `regions`; loading older formats requests regeneration. `SpriteGeometry.polygons` transforms the active sprite's vertices, and `edges` emits exactly one segment per vertex, closing each ring independently. Anchors, unequal scale, flips, door variants, and light animation still follow the live sprite.

`fade_units` retains its narrow meaning: sprite references grouped to share opacity, with a supporting base, footprint, and fade type. It uses a subset of available occluder geometry. It neither owns the polygon source nor selects future lighting blockers. Props outside fade units still have geometry available to other consumers. See the [glossary](../../GLOSSARY.md#rendering).

## Continuous local-width queries

`SpriteGeometry.crosses_span?` first rejects using occupied bounds, then examines each polygon independently. Split the actor's vertical interval at polygon vertex heights. Within each resulting band, crossing edges form ordered left/right pairs whose X coordinates vary linearly with height. Intersect the height intervals satisfying all three conditions: left edge at or left of actor center, right edge strictly right of center, and span strictly wider than the actor. Require positive overlapping height; touching a horizontal boundary alone does not qualify.

This preserves concave notches, disconnected gaps, the half-open center convention, and strict width eligibility without storing strips or reconstructing rectangle edges. Checking only endpoints or a midpoint is insufficient: a sloped shape can satisfy all conditions only within a narrow interior slice. Existing base direction, drawing order, distance falloff, opacity sharing, and transition timing remain in `ForegroundFade`.

The helper remains stateless. Hand-built sprites without polygon metadata retain the existing occupied/frame-bounds fallback; explicitly empty polygons remain empty. No lighting implementation or transformed-geometry cache is introduced.

## Debugging and verification

B shows magenta polygon edges for visible scenery, selected independently of fade units. Blue borders still show fade-unit footprints. Whole sprites are culled before edge preparation; individual polygon edges are preserved and the render target clips them. Both line endpoints receive camera translation.

The accepted atlas data contains 5,416 edges across 867 contours. Its former 9,828 rectangles contributed 39,312 border edges before visibility filtering. These totals cover all atlas tiles, not one rendered room or viewport. The checked-in format migration preserves every previously approved polygon vertex and bound. Regeneration with this machine's GEOS 3.15 produced slightly different outlines in two environment atlas tiles; those unrelated silhouette changes were excluded. Generation remains deterministic within the tested installation, not guaranteed identical across GEOS versions.

All 157 native tests, eight asset-generation tests (34 assertions), and RuboCop pass. Regression checks cover continuous slopes, boundary contacts, concave notches, disconnected pieces, scaling/flips, atlas-wide edge-count parity, and debug camera/door integration. Manual playtesting should check fade onset along slopes and corners, open doors, and the readability of the revised overlay.

## Performance evidence

A temporary native comparison ran the rectangle implementation from `8f11e58` alongside the polygon implementation, using the same Ritual Gate room, accepted polygons, player actor, full drawing order, viewport, and fade histories. Each case used seven samples of 1,200 calls after 120 warm-up calls, with GC before each sample. Results are median Ruby fade-evaluation time in microseconds on this macOS DragonRuby 7.21 installation:

| Player position | Previous rectangles | Continuous polygons |
| --- | ---: | ---: |
| (144, 68) | 81.507 | 94.922 |
| (176, 80) | 73.099 | 66.902 |
| (208, 94) | 68.645 | 68.363 |

These limited stationary cases do not establish an overall CPU or displayed-FPS improvement. Continuous intersection has more arithmetic per edge; the first case costs about 13 microseconds more. The demonstrated gains are removing redundant geometry and making shared boundaries and diagnostics match the approved polygons. The existing opt-in render benchmark now reports polygon-edge counts instead of removed region counts.
