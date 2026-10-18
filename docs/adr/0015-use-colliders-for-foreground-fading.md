---
status: accepted
date: 2026-10-19
---

# Use active colliders for foreground fading and remove generated occluders

Lighting already uses authored colliders, leaving the generated artwork polygons useful only for an unnecessarily precise foreground-fade query and debug overlay. Use active wall/door colliders for fading too, and remove the alpha-derived geometry pipeline, generated data, loader, dependencies, and shared SpriteGeometry module. This deliberately trades silhouette precision for a smaller implementation with one authored source of base geometry.

## Eligibility and shared opacity

Keep existing local wall/door, mounted-artwork, and supporting-cap associations. Each fade unit retains its canonical `type`, original `base` and `sprites` references, and an array of active world-space `colliders` from its wall/door members. Neighboring columns remain independent; do not combine a connected wall into one group. Orphan caps have no colliders and cannot trigger fading.

For each visible actor, a single collider must satisfy all these conditions:

- Its bottom Y is strictly below the actor's ground Y (world Y grows north).
- It contains the actor's center X, including the left edge and excluding the right.
- Its world width is strictly greater than the actor's scaled visible body width.
- The actor is less than 32 world pixels north of its top edge.

The supporting base must draw after the actor. At least one member drawn after the actor must cross its feet-to-head center line with positive vertical overlap, using the full anchored sprite rectangle. Artwork width does not replace collider width, and different multipart colliders cannot supply different parts of eligibility. Transparent padding can count as artwork overlap; no pixels or generated outlines are consulted.

The distance is `max(actor.y - collider.top, 0)`. Keep [ADR-0006](0006-simplified-foreground-fading.md)'s cubic smoothstep and lerp, 25% wall minimum, 75% door minimum, and bounded 16-tick fade-out/32-tick restoration. Select the lowest target across eligible collider/actor pairs. Shared sprites receive the lowest unit opacity once, multiplying authored alpha on a copy.

Room prepares collider arrays during construction and refreshes them on door state changes, using the same active open/closed colliders as movement and lighting. Units and sprite references remain stable, preserving opacity histories. A door with no qualifying open collider restores normally; empty groups stay opaque or restore from prior fading. No per-frame geometry rebuild, new Tiled property, map edit, or height model is introduced.

## Removed pipeline and diagnostics

Remove generated occluder JSON, its generator and runtime loader, atlas fingerprints/grid checks, source-local polygon metadata, and SpriteGeometry. ForegroundFade owns only the small anchored-rectangle helpers it needs. Remove `assets:occluders`, `assets:test`, and direct RGeo, ChunkyPNG, and Minitest dependencies; GEOS is no longer a setup requirement. Existing machine-local installations/configuration are left alone.

B retains physics/actor/spawn bounds, green light-source markers, and the player's red visibility polygon. Magenta artwork outlines are removed. Lighting, receiver tinting, FPS display, Pixuf, and HD-off remain as implemented.

This supersedes the alpha/polygon decisions in [ADR-0007](0007-alpha-derived-scenery-bounds.md), [ADR-0008](0008-occupied-spans-for-foreground-fading.md), [ADR-0011](0011-generated-tile-occluders.md), and [ADR-0012](0012-continuous-occluder-queries.md), and replaces ADR-0006's footprint geometry while retaining its math/timing. ADR-0009's shared-geometry extraction is retired; its other retained rendering changes and ADR-0010's simple sorting remain applicable. Historical measurements of the old geometry do not establish performance for this version.

## Verification

Native regressions cover collider direction, strict width/X/radius boundaries, actor scaling, multipart eligibility, strongest contributions, rectangle anchors, local groups and mounted artwork, active door transitions with stable histories, opacity timing, import without asset reads, diagnostics, and render integration. Verification on 2026-10-19: all 173 native tests pass, along with RuboCop and `git diff --check`. A six-state offscreen software-rendered capture was inspected for near-wall fading, retreat, closed/open/reclosed doors, and diagnostics; this does not establish transition feel or displayed FPS. Human playtesting should walk behind southern walls/doors, open and close a door during fading, retreat beyond the collider range, and check neighboring caps remain independent; judge the shorter thin-base range and rectangle approximation visually.
