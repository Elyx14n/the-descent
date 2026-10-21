---
status: accepted
date: 2026-10-14
---

# Use vertical-gap distance and bounded opacity approach for foreground fading

The working foreground fade already requires an actor's center X to cross its supporting base. Use that invariant to replace general point-to-rectangle distance with a vertical gap, express the existing spatial curve with cubic smoothstep and `Numeric#lerp`, and express temporal movement with `Numeric#towards`. This supersedes the Euclidean-distance calculation previously recorded in [ADR-0005](0005-render-data-and-room-preview.md#render-data-interface), while preserving its render-data interface and the eligible scenery's fade behavior.

## Eligibility and prepared geometry

[ADR-0015](0015-use-colliders-for-foreground-fading.md) replaces this decision's original footprint snapshots and later alpha geometry with active wall/door colliders. The math and transition rules below remain applicable, now measuring each qualifying collider separately.

Room constructs local units once, retaining base/member sprite references and active collider arrays. Door changes refresh colliders without replacing units or histories. Mounted artwork and supporting caps keep their local associations; orphan caps cannot trigger fading.

For a visible rendered actor, a single collider must start strictly south of its ground Y, contain its center X (left-inclusive/right-exclusive), exceed its scaled body width, and place its top less than 32 world pixels south of the actor. The base must draw after the actor, and a member drawn after the actor must cross its feet-to-head center line with positive height using full anchored artwork bounds.

Actor supplies scaled visible body dimensions: Player 14 × 26 source pixels and Enemy 60 × 54. Full animation-frame dimensions include empty padding and are unsuitable for the actor body interval. Continuous world Y allows a foreground collider in the actor's grid row to qualify.

## Spatial target: gap, smoothstep, and lerp

Eligibility guarantees zero horizontal distance from the actor to each qualifying collider. With its bottom below the actor, point-to-rectangle distance reduces to:

```ruby
distance = [actor[:y] - (collider[:y] + collider[:h]), 0].max
t = distance.fdiv(RADIUS).clamp(0, 1)
smooth_step = (3 * (t**2)) - (2 * (t**3))
target = min_opacity.lerp(1.0, smooth_step)
```

`multiplier` now computes this vertical-gap target; its caller establishes eligibility first. It is no longer a general distance query for arbitrary points outside the supporting column. The same collider must establish both horizontal eligibility and distance.

The 32-world-pixel radius starts at the collider's **top edge**, rather than its bottom-left origin. Feet inside the collider or at its top edge give a zero gap. Cubic smoothstep, `3t² - 2t³`, maps the normalized gap to an S-shaped progression with zero slope at both ends. Lerp then maps that progression from the type's minimum opacity to full opacity:

| Vertical gap | Normalized gap | Smoothstep | Wall target | Door target |
| --- | --- | --- | --- | --- |
| 0 | 0 | 0 | 0.25 | 0.75 |
| 16 | 0.5 | 0.5 | 0.625 | 0.875 |
| 32 or more | 1 | 1 | 1 | 1 |

These are distance targets before temporal smoothing. Walls use minimum opacity 0.25; doors use 0.75. Colliderless ceiling-only units remain opaque. Associated members inherit the supporting base's setting. The strongest eligible collider/actor pair supplies the unit's target; absent eligibility targets full opacity.

## Temporal approach: towards

The preview owns opacity history separately from frame artwork. `approach_opacity` reads the previous opacity and tick, chooses 16 ticks for decreasing opacity or 32 for increasing opacity, and computes:

```ruby
elapsed = [tick - previous[:tick], 0].max
duration = target < opacity ? FADE_OUT_TICKS : FADE_IN_TICKS
step = (1 - min_opacity) * elapsed.fdiv(duration)
opacity = opacity.towards(target, step)
```

`towards` moves by at most the absolute amount `step` and stops at the target without overshooting. Scaling the rate to the type's opacity range makes a full-range change take at most the configured duration for a fixed target; partial changes finish sooner. Newly encountered units start fully opaque and receive one tick of progress. Repeated draws within a tick receive zero additional progress.

Smoothstep shapes the relationship between distance and target opacity; `towards` limits how quickly displayed opacity follows that target. Leaving the column, leaving the viewport, or removing actors restores opacity through the same approach. Reentry reverses from the current opacity. Successful room rebuilds reset history, invalid exports preserve the last valid room and its history, and removed units are pruned.

The strongest unit multiplier is applied once per sprite, multiplying authored alpha on a copy. The original frame artwork remains unchanged. Equal-looking sprites retain distinct object identities and drawing-order positions.

## Alternatives and consequences

- A dot product against the vertical axis adds machinery to the existing Y comparison. Keep explicit interval comparisons for this axis-aligned geometry.
- Repeated fixed-factor lerp for temporal smoothing approaches the target by a fraction of the remaining difference. It changes settling and duration behavior; use lerp only to map the spatial target.
- DragonRuby 7.21's `Easing.smooth_step` mixes smooth-start and smooth-stop curves and does not reproduce the selected cubic polynomial. Retain the explicit formula.
- Additional Tiled fade flags, opacity overrides, or ownership references remain options for actual authoring exceptions. Global tuning stays in Ruby while automatic local association works.

This removes unnecessary horizontal-distance math and viewport bounds normalization; no performance improvement has been measured. Collision, gameplay sight, lighting, and camera placement retain their existing responsibilities. Center-line intersection approximates visible occlusion, and overlapping translucent artwork can still compound visual opacity.

## Verification and references

Preserve coverage for collider contact and edge distances, same-grid-row bases, side contacts, body padding, base/member drawing order, door variants, anchored viewport visibility, shared alpha, multiple actors, exit/reentry, and repeated draws within a tick. The runtime still rejects side columns through eligibility. The user confirmed the corrected implementation works; transition feel and enlarged-window appearance remain manual checks after future changes.

Implementation: [ForegroundFade](../../mygame/app/foreground_fade.rb), [Room](../../mygame/app/room.rb), [Actor](../../mygame/app/actor.rb), and [Render](../../mygame/app/render.rb). Research evidence, earlier playtest findings, and the manual scenario remain in the [foreground-fading note](../notes/foreground-fading.md).

Local SDK references: `$DRAGONRUBY_HOME/docs/oss/dragon/numeric.rb` (`towards` and `lerp`), `$DRAGONRUBY_HOME/docs/api/geometry.md` (anchor-aware rectangle intersection), and `$DRAGONRUBY_HOME/docs/oss/dragon/easing.rb` (`smooth_step`).
