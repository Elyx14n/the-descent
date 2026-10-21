---
status: accepted
date: 2026-10-18
updated: 2026-10-21
---

# Keep HD disabled

The user reported roughly 10 FPS in the smaller window and 4 FPS maximized with the lamp sight overlay. With raycasting optimizations present, disabling HD immediately restored a consistent 60 FPS in their playtest. The user explicitly requires HD to remain disabled. Reverting all raycasting optimizations then returned performance below 10 FPS even with HD off: both rendering configuration and raycasting work matter.

Use `hd=false` in game metadata, enforced by the native display-configuration test and repository guidance. Retain the 320 × 180 logical canvas and existing camera/artwork drawing alignment. This supersedes the **HD-on selection** in [ADR-0001](0001-viewport-sized-camera.md) and [ADR-0002](0002-reference-resolution-and-ui-fonts.md); their coordinate, viewport, and asset/font ownership decisions remain in force. Older HD-on skill guidance must not override this decision or the user's instruction.

The user changed metadata sampling to nearest (`scale_quality=0`) on 2026-10-21 and confirmed this removes scene blur. Nearest minification exposed changing source-pixel patterns in the downsized candles and pedestals. Render now uses pixel-art sampling (`scale_quality_enum: 3`) only when reducing source artwork, while scene presentation inherits nearest. The user confirms blur remains fixed after this correction; renderer captures show stable resized crops across integer placements. This replaces the earlier all-stage `scale_quality=3` recommendation without changing HD or raster size. See the [sampling reproduction](../notes/conventional-pixel-art-rendering-sources.md#follow-up-nearest-scene-presentation-and-downsized-artwork). [ADR-0017](0017-keep-preview-camera-on-player.md) separately records the perimeter-camera correction.

HD-off m5x7 body text at `size_px: 8` was visibly blurry. Prior captures in ADR-0002 show partially covered grey strokes at that size on the native 320 × 180 raster. This motivated the font replacement below. Tune font size, pixel alignment, and layout within HD-off rendering. The user's performance report supersedes the earlier preference for HD's finer scene movement; previous HD-on observations do not establish acceptance of HD-off movement or text.

The retained raycasting changes are measured separately in the [learning/performance note](../notes/raycast-lighting.md). Keep only changes justified by the current workload; no persistent geometry cache or lower-quality ray sampling is required by this decision.

## UI font

On 2026-10-19, the user selected Pixuf to replace m5x7. The project-owned asset is [Pixuf.ttf](../../mygame/fonts/Pixuf.ttf), referenced with that exact casing as `fonts/Pixuf.ttf`. This replaces ADR-0002's m5x7 selection while retaining the 320 × 180 canvas and HD-off requirement.

[UI::TEXT](../../mygame/app/ui.rb) uses Pixuf through ordinary DragonRuby labels, with current `size_px` defaults of 8 for body text and 16 for headings. Assess future text-size and layout changes for readability at the native raster with HD disabled.
