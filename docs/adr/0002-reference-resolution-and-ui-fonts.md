---
status: accepted
date: 2026-10-05
---

# Use a 320 × 180 reference resolution with m5x7 and HD rendering

The current 32 × 32 artwork needs a deliberate view size to remain readable. Use a 320 × 180 logical canvas, draw artwork at native dimensions, and let DragonRuby handle display scaling. Keep HD rendering enabled and use m5x7 for UI text at the sizes accepted in playtesting.

The project configuration is:

| Setting | Accepted value | Purpose |
| --- | --- | --- |
| `orientation` | `landscape` | Landscape presentation. |
| `aspect_mode` | `0` | A 16:9 logical canvas. |
| `aspect_size` | `180` | A 320 × 180 reference resolution. |
| `scale_quality` | `0` | Nearest-neighbor sprite sampling. |
| `hd` | `true` | Clear text rendering while retaining the logical canvas. |
| UI font | `fonts/m5x7.ttf` | Pixel lettering that the user found legible. |
| Body `size_px` | `8` | Accepted body text size. |
| Heading `size_px` | `16` | Accepted heading size. |

At entity scale 1, one world unit is one artwork pixel. A 32 × 32 source frame occupies 32 × 32 logical pixels. The camera adds no compensating zoom. A 720p display scales logical pixels by 4×; 1080p, 1440p, and 4K scale them by 6×, 8×, and 12× respectively. These ratios describe canvas presentation, not the raster resolution of HD font glyphs. Other window sizes can use fractional fit scaling; nearest-neighbor sampling alone does not guarantee uniform pixel sizes in every window.

The reference-resolution workflow is established engine guidance, not a universal resolution requirement for this genre. [Unity explicitly gives 320 × 180 as an example](https://docs.unity.com/en-us/engine/6000.7/manual/unity2d/2d-urp/2d-pixelperfect/prep-sprites), while [Godot describes several suitable pixel-art base resolutions](https://docs.godotengine.org/en/stable/tutorials/rendering/multiple_resolutions.html#desktop-game). Playtesting selected 320 × 180 for this artwork. At 640 × 360, the artwork looked too small; the earlier 1280 × 720 canvas with camera zoom 3 mixed view framing with display magnification.

Use the font and HD setting together. The user found `tiny.ttf` difficult to read and accepted m5x7 at body size 8 and heading size 16. The user also found that disabling HD made labels blurry. A runtime check on the installed DragonRuby 7.21 Standard build reported `HD: yes`, native rendering at 1280 × 720 in a 720p window, and logical resolution 320 × 180. The bundled documentation groups HD font rendering under Pro, but that classification does not override the observed behavior of this installation. Preserve the working configuration and verify it again when changing SDK versions; do not infer support for every other HD or all-screen feature from this result.

HUD and annotation layout use logical screen coordinates. `size_px` is a font size, not a guarantee of visible glyph height; do not replace the accepted sizes merely because another font recommends different sizes. Keep the default 16:9 fit presentation for the current implementation. This does not establish letterboxing as a desired player experience; no edge-to-edge all-screen dependency was added.

## Consequences and sources

- Changing the reference resolution changes how much world the player can see. Tune it as a framing decision alongside artwork readability, rather than treating it as a performance switch.
- UI readability is established by playtesting. Coordinate tests and lint checks cannot establish whether text is comfortable to read.
- Configuration lives in [game metadata](../../mygame/metadata/game_metadata.txt); font defaults live in [UI](../../mygame/app/ui.rb); the font asset is [m5x7.ttf](../../mygame/fonts/m5x7.ttf).
- Font source: [m5x7 by Daniel Linssen](https://managore.itch.io/m5x7). Keep its source identifiable when distributing or replacing the asset.
- SDK sources inspected in 7.21: `$DRAGONRUBY_HOME/docs/api/grid.md`, aspect mode/size and HD modes; `$DRAGONRUBY_HOME/docs/api/outputs.md`, label properties; `$DRAGONRUBY_HOME/samples/99_genre_lowrez/lowrez_labels/app/main.rb`, pixel-font examples. Locate the installation through `DRAGONRUBY_HOME` as described in the [repository setup](../../README.md#first-time-setup-and-running-the-game).
