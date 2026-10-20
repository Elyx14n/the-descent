---
status: accepted
date: 2026-10-21
---

# Pair diagonal camera pixel steps

After nearest sampling removed blur and continuous camera following removed player jitter, diagonal scenery movement still appeared to jitter in short bursts. Captures reproduced staggered X/Y pixel steps caused solely by differing fractional coordinates; the user confirms that the comparison pairing those steps eliminates the reported camera jitter. Use that presentation policy in normal rendering, retaining HD off and the native 320 × 180 raster.

`CameraScroll` rounds traveled distance from the start of a straight diagonal segment and applies the same pixel count to both axes. It retains the phase across stationary callbacks and speed changes. Turns reanchor to the nearest previous position, and cardinal movement uses ordinary nearest placement, keeping presentation error within one raster pixel without accumulating drift. Large position jumps and display-scale changes reinitialize the history; preview reloads, teleports, respawns, and discarded clock intervals reset it explicitly.

Camera owns this history. Its interpolated presentation copies share it, and only drawing positions advance it; simulation follows do not. Render uses the resulting camera for scenery, lighting, culling, and diagnostics, with viewport-sized 320 × 180 targets presented at `(0, 0)`. Direct actors retain the precise camera translation and final artwork alignment, keeping the followed player centered. Collision, movement, simulation/interpolation, fading, source crops, and the accepted sampling correction remain unchanged.

This replaces fractional scene-target presentation and its padded 321 × 181 targets for normal preview rendering. A fractional blit into a nearest-sampled native framebuffer did not provide finer motion and exposed independent axis rounding. The earlier larger-raster proposal remains deferred. [ADR-0017](0017-keep-preview-camera-on-player.md) retains player-centered framing, and [ADR-0013](0013-keep-hd-disabled.md) retains the display and sampling requirements.

Native regressions cover all diagonal directions, walking/sneaking, unequal and negative fractional coordinates, pauses, speed changes, repeated turns and wall sliding, resets, scale changes, and camera copies surviving hot reload. Renderer integration asserts paired scenery movement and the fixed player anchor. The 96-frame actual-room comparison against the user-tested diagnostic has identical scenery/player pixels in 95 frames; the remaining frame differs by one blue-channel value at one pixel. FPS text is excluded. Normal-preview turning and stopping still merit a final playtest; automated checks establish placement invariants rather than subjective smoothness. See the [investigation](../notes/foreground-jitter-investigation.md#normal-renderer-promotion).
