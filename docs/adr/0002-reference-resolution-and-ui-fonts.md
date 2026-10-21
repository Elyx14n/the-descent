---
status: superseded
superseded_by: 0013-keep-hd-disabled.md
date: 2026-10-05
updated: 2026-10-19
---

# Use a 320 × 180 reference resolution with m5x7 and HD rendering

The **HD-on and m5x7 selections** below are superseded by [ADR-0013](0013-keep-hd-disabled.md), including its [Pixuf selection](0013-keep-hd-disabled.md#ui-font). Keep HD off; the 320 × 180 canvas, sampling, and font ownership remain in force. The configuration and comparisons below record the earlier m5x7/HD-on decision. Historical HD-on playtests do not authorize restoring HD.

The pixel artwork needs a deliberate view size to remain readable. Use a 320 × 180 logical canvas, draw artwork using its configured source dimensions and entity scale, and let DragonRuby handle display scaling. The confirmed combination is **HD on, pixel-art sampling, and camera/artwork drawing alignment**. Retain m5x7 at the sizes accepted in playtesting.

The historical project configuration was:

| Setting | Accepted value | Purpose |
| --- | --- | --- |
| `orientation` | `landscape` | Landscape presentation. |
| `aspect_mode` | `0` | A 16:9 logical canvas. |
| `aspect_size` | `180` | A 320 × 180 reference resolution. |
| `scale_quality` | `3` | SDL3 pixel-art sampling. |
| `hd` | `true` | Finer scene raster and clearer small text while retaining logical coordinates. |
| Drawing alignment | Camera and artwork snapped to the native raster | Stable player placement and aligned tile boundaries. |
| UI font | `fonts/m5x7.ttf` | Pixel lettering that the user found legible. |
| Body `size_px` | `8` | Accepted body text size. |
| Heading `size_px` | `16` | Accepted heading size. |

32 × 32 is the usual sprite cell size and the default in `Sprite`, but it is not required for every asset. The cathedral atlas uses 32 × 32 cells; the [player configuration](../../mygame/app/player.rb) uses 64 × 64 animation frames. Configure source dimensions per asset; rendering scale and collision dimensions are separate settings.

At entity scale 1, one source artwork pixel occupies one logical world pixel: a 32 × 32 frame occupies 32 × 32 logical pixels, and a 64 × 64 frame occupies 64 × 64. The camera adds no compensating zoom. A 720p display scales logical pixels by 4×; 1080p, 1440p, and 4K scale them by 6×, 8×, and 12× respectively. These ratios describe canvas presentation, not the raster resolution of HD font glyphs. Other window sizes can use fractional fit scaling; nearest-neighbor sampling alone does not guarantee uniform pixel sizes in every window.

On 2026-10-11, playtesting selected the pixel-art sampler instead of nearest sampling: it substantially reduced the enlarged-window tile lines. [SDL describes this as improved pixel-art scaling](https://wiki.libsdl.org/SDL3/SDL_ScaleMode). F4 temporarily compared nearest sampling without changing geometry during the investigation; this runtime toggle has since been removed, leaving sampling controlled by game metadata. The remaining diagonal-only flashes motivated snapping to physical display pixels in [ADR-0001](0001-viewport-sized-camera.md); sampling alone does not establish a complete fix.

The user's completed game comparison retained HD for scene movement as well as text. HD off with artwork rounding had clean floors but mild camera jitter; removing artwork rounding kept floors clean but introduced player wobble and blur. Restoring HD with pixel-art sampling and drawing alignment removed all reported jitter and seams. [ADR-0001](0001-viewport-sized-camera.md) records the complete comparison.

HD supplies more **native raster pixels** for the same **logical canvas**. At a 5.5× window fit, the HD scene can render at 1760 × 990, allowing drawing alignment in steps of 1/5.5 logical units. HD-off alignment instead takes one-logical-pixel steps before the 320 × 180 frame is enlarged. The rounding is valid in both modes; the higher-resolution grid makes it finer. Separately, font outlines become higher-resolution rasterized glyphs. This improves small text but does not supply inputs to the sprite/camera calculation or add detail to source artwork. Definitions live in the [rendering glossary](../../GLOSSARY.md#rendering).

The reference-resolution workflow is established engine guidance, not a universal resolution requirement for this genre. [Unity explicitly gives 320 × 180 as an example](https://docs.unity.com/en-us/engine/6000.7/manual/unity2d/2d-urp/2d-pixelperfect/prep-sprites), while [Godot describes several suitable pixel-art base resolutions](https://docs.godotengine.org/en/stable/tutorials/rendering/multiple_resolutions.html#desktop-game). Playtesting selected 320 × 180 for this artwork. At 640 × 360, the artwork looked too small; the earlier 1280 × 720 canvas with camera zoom 3 mixed view framing with display magnification.

HD was originally enabled solely to improve text fidelity. The user found `tiny.ttf` difficult to read and accepted m5x7 at body size 8 and heading size 16; disabling HD made these labels blurry. This was initially a playtesting decision without a controlled explanation of the font rendering. It does not establish a gameplay requirement for HD.

An isolated comparison on DragonRuby 7.21 Standard subsequently tested HD on and off with nearest sampling in both modes, at a 1760 × 990 window size:

| Observation | HD on | HD off |
| --- | --- | --- |
| Logical canvas | 320 × 180 | 320 × 180 |
| Native canvas | 1760 × 990 | 320 × 180 |
| `Grid.render_scale` | 5.5 | 1 |
| m5x7 label at `size_px: 8`, white on black | Higher-resolution strokes included solid white pixels. | Every visible stroke pixel in the captured label was partially covered grey; none was solid white. |
| Drawing alignment | Physical display pixels, expressed back in logical units. | Whole logical pixels before scaling the completed frame for presentation. |

HD gives glyph rendering more raster pixels for the same logical label size. Without HD, a tiny TrueType glyph is rasterized into the low-resolution canvas before that image is enlarged. Nearest sampling enlarges the existing grey, partially covered pixels; it cannot recover the glyph detail lost during rasterization. This explains the observed softness of our m5x7 size-8 labels. Font rasterization and final image sampling are separate concerns.

HD is optional for crisp text. In the same HD-off/nearest test, the SDK's `tiny.ttf` at size 10 and its sample `fonts/lowrez.ttf` at sizes 10 and 20 produced only black and white pixels, with no grey antialiased strokes. A low-resolution UI using suitably authored glyphs and sizes is therefore a viable alternative. Switching would require reviewing font appearance, text size, spacing, and HUD layout; the user's previous rejection of tiny.ttf remains relevant. Bitmap glyph sprites are another possible authoring approach, not an implemented requirement.

HD also changes world rendering: sprite geometry and the scene target are rasterized at the higher resolution. Fractional window fitting still exists with HD off, but it scales the already-composited low-resolution frame rather than independently rasterizing each atlas tile at that display scale. Logical pixel blocks can occupy unequal physical widths at a 5.5× presentation scale. In the game playtests recorded in [ADR-0001](0001-viewport-sized-camera.md), removing per-sprite rounding with HD off introduced player wobble and blur even though floors stayed clean. It would also restore coarser visual movement: a one-logical-pixel step occupies approximately five or six display pixels at this window size.

At the time, the completed comparisons confirmed the original HD-on configuration with pixel-art sampling and display-pixel snapping; the HD-off alternative was not selected, and no font replacement was agreed. ADR-0013 subsequently required HD off and recorded the user's Pixuf selection. No CPU or GPU benchmark establishes a performance problem with the snapping arithmetic. `to_draw_space` prepares ordinary sprite positions and does not allocate an additional rendering buffer.

The bundled Grid documentation still groups HD under Pro, but the SDK's 7.3 changelog explicitly records HD support for Standard and Indie. The installed 7.21 Standard runtime confirms that behaviour. Verify it again when changing SDK versions; this does not establish support for other separately licensed high-DPI or all-screen controls.

HUD and annotation layout use logical screen coordinates. `size_px` is a font size, not a guarantee of visible glyph height; do not replace the accepted sizes merely because another font recommends different sizes. Keep the default 16:9 fit presentation for the current implementation. This does not establish letterboxing as a desired player experience; no edge-to-edge all-screen dependency was added.

## Consequences and sources

- Changing the reference resolution changes how much world the player can see. Tune it as a framing decision alongside artwork readability, rather than treating it as a performance switch.
- UI readability is established by playtesting. Coordinate tests and lint checks cannot establish whether text is comfortable to read.
- Configuration lives in [game metadata](../../mygame/metadata/game_metadata.txt); current font defaults live in [UI](../../mygame/app/ui.rb), using [Pixuf.ttf](../../mygame/fonts/Pixuf.ttf) under [ADR-0013](0013-keep-hd-disabled.md#ui-font).
- Historical font source: [m5x7 by Daniel Linssen](https://managore.itch.io/m5x7). The m5x7 asset has been replaced by Pixuf; the comparisons above remain evidence about m5x7.
- SDK sources inspected in 7.21: `$DRAGONRUBY_HOME/docs/api/grid.md`, aspect mode/size and HD modes; `$DRAGONRUBY_HOME/docs/api/outputs.md`, label properties; `$DRAGONRUBY_HOME/docs/changelog.txt`, HD label rendering and the 7.3 Standard/Indie fix; `$DRAGONRUBY_HOME/samples/99_genre_lowrez/lowrez_labels/app/main.rb`, pixel-font examples and intended sizes. Locate the installation through `DRAGONRUBY_HOME` as described in the [repository setup](../../README.md#first-time-setup-and-running-the-game).
