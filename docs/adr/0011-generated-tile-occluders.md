---
status: superseded
superseded_by: 0012-continuous-occluder-queries.md
date: 2026-10-17
---

# Generate simplified tile occluders outside the game

[ADR-0012](0012-continuous-occluder-queries.md) replaces the sampled rectangle representation and debug overlay described below. It retains the generation pipeline, approved simplification policy, and loading/freshness checks.

Room loading scanned sprite alpha and decomposed exact occupied pixels into rectangles for foreground fading. Those rectangles solve overlap queries but would introduce unnecessary internal edges if used directly for future raycasting. Generate simplified polygon boundaries with RGeo/GEOS in a Rake task, retain disconnected pieces, and use those polygons as the shared source for runtime geometry.

This replaces the runtime pixel scanning in [ADR-0007](0007-alpha-derived-scenery-bounds.md), the exact-alpha representation in [ADR-0008](0008-occupied-spans-for-foreground-fading.md), and the exact-hole-preservation constraint in [ADR-0009](0009-measured-render-preparation.md#sequence-outcome-and-lighting-constraints). Supporting footprints, strict occupied-width eligibility, unit grouping, fade timing, and collision remain unchanged. The stateless shared geometry module remains useful.

## Build once after artwork changes

`bin/rake assets:occluders` reads the existing room JSON's embedded tilesets and PNG atlases, unions nonzero-alpha pixel cells, fills interior holes, unions the filled areas, and simplifies the complete tile with topology preservation. This keeps exposed components separate and removes redundant boundaries inside already-filled areas. The user approved a **two-source-pixel tolerance** after inspecting both previews. Do not replace disconnected pieces with one enclosing polygon: that discarded separate wall/cap artwork in the first trial. No small-component threshold is applied.

Write `mygame/data/occluders.json` and include it with the game. Process every cell in each referenced atlas, so door states and animation frames are available without discovering them at runtime. Tile placement, class, and collision remain authored in Tiled; this task generates visual occlusion geometry only.

RGeo and GEOS perform geometry work in ordinary development Ruby; ChunkyPNG decodes alpha; Minitest tests the build task. DragonRuby loads none of those libraries. HTML previews and their encoding code were removed after the user accepted the outlines.

## One geometry source, two useful representations

Each tile record contains counterclockwise `polygons`, overall `bounds`, and derived `regions`, in crop-local bottom-left pixel coordinates. Rings omit a repeated closing point. Disconnected pieces remain separate.

Polygons provide the exposed boundaries that future raycasting can consume through `SpriteGeometry.polygons`. Lighting is not implemented, and its blocker selection remains separate from foreground fading.

To keep fading simple, the build task intersects the simplified polygon union with horizontal lines at source-row centers. It turns each resulting interval into a one-pixel-high rectangle and merges identical intervals in consecutive rows. These `regions` are derived from the polygons, not independently from the original pixels. The existing actor-center and strict local-width checks therefore continue to distinguish an L's broad arm, narrow arm, and empty corner without adding a runtime polygon-intersection algorithm. Sampling is an approximation near sloped edges; it does not promise exact polygon/pixel coverage. Filled internal holes intentionally block fading queries as part of the coarser silhouette.

`SpriteGeometry` transforms bounds, regions, and polygons using the active sprite's anchor, scale, and flips. Door/light artwork changes replace the geometry alongside the crop, retaining sprite identity. `B` still shows the actual fade regions in the room preview; the removed previews are the standalone HTML asset galleries.

## Loading, regeneration, and limits

`TiledDeserializer.deserialize(data, path:, occluders:)` accepts prepared data explicitly. Room loading validates format, atlas fingerprints, and crop-grid metadata; missing or outdated data reports `bin/rake assets:occluders`. A shared FNV-1a checksum detects changed PNG files without decoding pixel arrays. It is a freshness check, not a security mechanism.

After rebuilding assets, press R to reload the room. Automatic polling continues to watch map JSON, not generated files. Failed reloads retain the last valid room. There is no runtime fallback to pixel scanning and no persistent transformed-geometry cache.

This is an architectural change, not a measured FPS optimization. It trades exact alpha detail and automatic measurement during reload for explicit asset regeneration, controlled polygon complexity, and reusable light-blocking boundaries. Current tests establish deterministic generation and runtime behavior; the new silhouettes still need gameplay playtesting around corners and open doors. Research and the discarded prototype policies are retained in the [investigation notes](../notes/alpha-contour-generation.md).

## Verification

Eight generation tests pass (38 assertions), including repeatable export, disconnected pieces, filled holes, and removal of an island boundary inside an already-filled area. All 152 native game tests and RuboCop pass. Every generated tile forms valid geometry, with 867 exposed contours and no redundant component boundaries. These checks do not establish a frame-time improvement or replace gameplay playtesting.
