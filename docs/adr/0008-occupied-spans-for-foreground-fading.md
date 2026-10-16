---
status: accepted
date: 2026-10-15
---

# Test occupied spans when fading irregular scenery

An L-shaped tile exposes the limitation of the single alpha rectangle in [ADR-0007](0007-alpha-derived-scenery-bounds.md): its empty corner counts as artwork, and its narrow arm inherits the full tile width. Replace that rectangle as the fade eligibility shape with contiguous nonzero-alpha horizontal spans, merging identical spans on consecutive rows into rectangles. One occupied rectangle must both cross the actor's feet-to-head center line and be strictly wider than the actor's scaled body.

This supersedes ADR-0007's single-rectangle eligibility rule; retain its loading, transforms, supporting footprints, and actor dimensions. Imported sprites keep their overall `occlusion_bounds` and add source-local `occlusion_regions`; empty crops have an empty region array. Both are measured and cached together per crop during each load, and replaced together by door and light variants. `SpriteGeometry.alpha_regions` transforms regions into world coordinates with the same scale, anchors, and flips as `alpha_bounds`. Hand-built sprites without regions retain their existing rectangle fallback.

The B overlay shows the occupied regions in magenta. This adds stored geometry and region checks, while avoiding per-frame atlas reads and rejecting transparent holes exactly. Fade timing, minimum opacity, shared-unit fading, drawing order, and collision are unchanged. Actor center-line eligibility remains an approximation of visual obstruction; a single overlapping broad row can still qualify.

Native regressions cover an L's empty corner, narrow arm, broad arm, all four flip combinations, exact body-edge contact, separated spans, scaled/anchored transforms, empty crops, reloads, and door-state replacement. Visual readability around corners still requires playtesting.

[ADR-0009](0009-measured-render-preparation.md) moves the stateless geometry transforms out of ForegroundFade; this decision's geometry and fade rules remain unchanged.
