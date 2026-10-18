---
status: accepted
date: 2026-10-18
---

# Keep HD disabled

The user reported roughly 10 FPS in the smaller window and 4 FPS maximized with the lamp sight overlay. With raycasting optimizations present, disabling HD immediately restored a consistent 60 FPS in their playtest. The user explicitly requires HD to remain disabled. Reverting all raycasting optimizations then returned performance below 10 FPS even with HD off: both rendering configuration and raycasting work matter.

Use `hd=false` in game metadata, enforced by the native display-configuration test and repository guidance. Retain the 320 × 180 logical canvas, `scale_quality=3`, and existing camera/artwork drawing alignment. This supersedes the **HD-on selection** in [ADR-0001](0001-viewport-sized-camera.md) and [ADR-0002](0002-reference-resolution-and-ui-fonts.md); their coordinate, viewport, sampling, and asset/font ownership decisions remain in force. Older HD-on skill guidance must not override this decision or the user's instruction.

HD-off m5x7 body text at `size_px: 8` is visibly blurry; this is an acknowledged UI tuning issue, not a reason to re-enable HD. Prior captures in ADR-0002 already show partially covered grey strokes at that size on the native 320 × 180 raster. Tune font size, pixel alignment, and layout within HD-off rendering; no replacement font or final new size is accepted yet. The current user report supersedes earlier preference for HD's finer scene movement. Recheck movement and text readability during playtesting, without assuming previous HD-on observations still establish acceptance.

The retained raycasting changes are measured separately in the [learning/performance note](../notes/raycast-lighting.md). Keep only changes justified by the current workload; no persistent geometry cache or lower-quality ray sampling is required by this decision.
