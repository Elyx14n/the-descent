---
status: superseded
superseded_by: 0015-use-colliders-for-foreground-fading.md
date: 2026-10-14
---

# Reject scenery padding and narrow occluders with measured bounds

Retired by [ADR-0015](0015-use-colliders-for-foreground-fading.md): active colliders replace all alpha-derived fade geometry, and the generated pipeline and magenta overlay are removed. The remaining text records the historical decision.

The single-rectangle fade eligibility rule below was superseded by [ADR-0008](0008-occupied-spans-for-foreground-fading.md) after L-shaped sprites demonstrated false positives. [ADR-0011](0011-generated-tile-occluders.md) subsequently replaces runtime pixel loading and exact-alpha geometry with generated simplified occluders. Supporting footprints, actor dimensions, and the strict width rule remain in force; the measurement workflow below is historical.

An outside-room playtest found that the vertical side walls and closed side doors faded when the actor's center line crossed transparent frame padding. Their artwork occupies a six-pixel strip inside a 32-pixel-wide tile. Measure a tight rectangle around each used tile's nonzero-alpha pixels during deserialization, and require that rectangle to be wider than the actor as well as intersecting its center line before it triggers [foreground fading](0006-simplified-foreground-fading.md).

## Data and loading

`TiledDeserializer.load(gtk, path:)` supplies DragonRuby's `get_pixels` through an `image_loader` callable. `deserialize(data, path:, image_loader:)` accepts that dependency explicitly, allowing native tests to supply deterministic pixel data. Its per-call context loads each atlas once and scans each distinct source crop once, including both door-state variants. The temporary image arrays and measurement cache do not become Room state. Rebuilding a room remeasures its artwork; no global cache persists across reloads.

Every imported sprite carries `occlusion_bounds`, a rectangle in source pixels relative to the crop's bottom-left corner. It includes the offset as well as width and height. Alpha greater than zero contributes to the rectangle, regardless of the sprite's authored opacity. An entirely transparent crop carries `occlusion_bounds: nil`. Missing or out-of-range image data rejects loading rather than silently falling back to frame bounds.

The drawing rectangle and atlas crop remain unchanged. `SpriteGeometry.alpha_bounds` transforms the local measurement into world coordinates, accounting for sprite anchors, scaling, and horizontal/vertical flips. Door state changes replace the measurement together with the artwork while retaining the original sprite reference. Hand-built primitives lacking `occlusion_bounds` use their drawing rectangle; an explicitly measured empty sprite has no occluding rectangle.

## Fade behavior

This replaces the full-frame member-intersection rule in [ADR-0006](0006-simplified-foreground-fading.md#eligibility-and-prepared-geometry). Keep the supporting base's original horizontal span and drawing order as eligibility gates, then require a later-drawn member's measured visible rectangle to intersect the actor's feet-to-head center line with positive height and have world-space width strictly greater than the actor's scaled `occlusion_width`. Equal-width and narrower artwork cannot trigger fading. The same member must satisfy both tests; a broad nonintersecting member cannot make a narrow intersecting member qualify. A ceiling cap or mounted prop can qualify through its own visible artwork; the base need not have visible pixels at the same X. A qualifying member still causes the whole unit to share opacity, including narrower associated pieces.

The user reported the padding fix was almost perfect, then selected this width gate because crossing a thin visible strip still faded scenery while the actor remained readable. Actor supplies stable measured body dimensions, excluding frame padding:

| Actor | Source-pixel width | Source-pixel height |
| --- | --- | --- |
| Player | 14 | 26 |
| Enemy | 60 | 54 |

Width is the maximum per-frame nonzero-alpha extent within the existing feet-to-head body interval across Player's idle/walk lamp variants and Enemy's walking frames, including all facings. The measured Player widths range from 12 to 14; Enemy poses range from 30 to 60. Fixed maxima avoid eligibility changing with animation or facing. Both dimensions scale with the actor; scenery width is compared after its source bounds are transformed to world space. An unscaled Enemy therefore requires a member wider than 60 world pixels; adjacent 32-pixel units do not combine into one blocker.

Room association and the stable supporting footprint still use the original placement rectangles. The footprint's top edge continues to supply vertical-gap distance; smoothstep, minimum opacities, and the bounded `towards` approach remain as recorded in ADR-0006. Collision data and Tiled classifications do not change.

The B preview overlay adds measured rectangles in magenta beside the blue footprints and existing collision diagnostics. Use R after Ruby or atlas changes to rebuild persistent room data; automatic preview polling still checks JSON contents.

## Alternatives and limits

Collider width cannot reliably represent visual obstruction: some decorative walls have no colliders, and artwork can extend beyond its ground collider. Do not add movement blockers or reinterpret decoration solely to fix fading.

The selected rectangle removes outer transparent padding exactly, but it may enclose transparent holes or irregular corners. Open side-door variants already span their full 32×32 source bounds. Per-column occupied intervals remain the next option if playtesting demonstrates false positives inside those bounds. The actor center line and visible body height also remain an approximation of the actor silhouette; this is not per-pixel composited occlusion.

## Verification

Native regressions cover the real side-wall/closed-door padding case and rejection even when their narrow artwork crosses the actor center, strict width equality, actor/scenery scaling, same-member width/intersection eligibility, source offsets, unequal scaling, flips, anchors, alpha=1 pixels, transparent crops, atlas reuse, rebuild freshness, door-state measurements, and stable supporting footprints. Existing fade timing, sorting, shared-alpha, viewport, reload, and frame-immutability tests remain in force. Manual playtesting must check narrow walls/caps, closed/open side doors, broader southern caps, and exit/reentry transitions. Enemy readability with the maximum-width threshold still needs a scenario supplying Enemy actors; the preview currently contains only Player.

Implementation: [deserializer](../../mygame/app/tiled_deserializer.rb), [fade geometry](../../mygame/app/foreground_fade.rb), and [preview diagnostics](../../mygame/app/room_preview.rb). Tests: [pixel-data and door regressions](../../mygame/tests/tiled_opacity_test.rb) and [renderer regressions](../../mygame/tests/render_test.rb). SDK reference: `$DRAGONRUBY_HOME/docs/api/runtime.md`, `get_pixels` (top-left pixel arrays containing ABGR values).

[ADR-0009](0009-measured-render-preparation.md) moves the stateless geometry transforms out of ForegroundFade; this decision's geometry and fade rules remain unchanged.
