---
status: accepted
date: 2026-10-21
---

# Keep the camera centered on its followed position

The user isolated diagonal player jitter to the current room's perimeter and corners: the unclamped-camera comparison removes it, including when the player's feet have a visible gap from a wall. At the native 320 × 180 raster, clamping stops camera movement and makes the player cross native pixels; separate X/Y rounding can stagger diagonal steps. Fading was an apparent spatial association rather than the demonstrated cause. See the [investigation and comparisons](../notes/foreground-jitter-investigation.md).

Camera follows its supplied position directly. RoomPreview constructs it with `Camera.new(x: player.x, y: player.y)` and follows the interpolated player for drawing, keeping the player centered throughout the room. The user removed clamping completely after confirming this behavior. Camera no longer accepts a clamp option or room bounds, stores no map extent, and has no small-room centering branch. Room retains its bounds for room data; camera culling still uses the viewport around the followed position.

This replaces the edge-framing policy in [ADR-0001](0001-viewport-sized-camera.md) and [ADR-0005](0005-render-data-and-room-preview.md). The viewport can extend beyond the authored room, showing the scene background outside its walls. This is a deliberate framing choice. Keep HD off and the native 320 × 180 raster under [ADR-0013](0013-keep-hd-disabled.md). [ADR-0019](0019-use-direction-aware-camera-rounding.md) separately adopts published direction-aware rounding for scenery.

The first implementation retained a generic `clamp: true` default and disabled it in the preview. Removing that unused option also removes its constructor arguments, stored bounds, initialization from a room midpoint, and five obsolete clamping tests. The camera initializes directly at the caller's position; test and benchmark consumers use explicit positions. Direct-actor alignment remains covered for an actor moving within a stationary view, while always-follow regressions cover fractional/negative positions, four actual-room corners, interpolation, conversion, and culling. This cleanup preserves the established normal-preview motion and sampling behavior.

The cleanup passes all 197 remaining native tests and RuboCop. A 96-frame four-corner renderer playback keeps the player anchor fixed and is pixel-identical to the pre-cleanup production captures outside the live HUD text.
