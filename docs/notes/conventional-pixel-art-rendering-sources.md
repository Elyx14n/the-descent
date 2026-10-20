# Conventional pixel-art rendering: source comparison

Investigated 2026-10-21 using primary engine documentation, published renderer source, and the installed DragonRuby 7.21 Standard SDK. This records evidence and candidate implementations; it changes no rendering policy. [ADR-0013](../adr/0013-keep-hd-disabled.md) requires HD off, and [ADR-0016](../adr/0016-fixed-step-simulation-and-interpolated-drawing.md) owns presentation timing. Vocabulary follows the [rendering glossary](../../GLOSSARY.md#rendering). Earlier local experiments are in [single-scene sampling](single-scene-sampling-sources.md) and [decoupled rendering](decoupled-rendering.md).

**Latest finding:** the user's nearest-neighbor experiment removed the reported scene blur, and a separate downsized-artwork reproduction now supports a smaller correction at the existing 320 × 180 raster. The [follow-up](#follow-up-nearest-scene-presentation-and-downsized-artwork) supersedes the earlier recommendation to pursue a finer final raster as the next implementation step. That larger-raster comparison remains useful evidence, but is deferred.

The remaining diagonal player jitter was subsequently isolated to camera clamping around the room perimeter and corners. The user confirms the unclamped comparison removes it; RoomPreview now uses that behavior under [ADR-0017](../adr/0017-keep-preview-camera-on-player.md). Neither correction changes the native raster or enables HD.

## The conventional implementations differ at the final raster

There are established implementations that keep artwork sharp while moving it in increments smaller than an artwork pixel. Their common requirement is a final rendering surface finer than the artwork grid. A low-resolution intermediate by itself is not that surface. The following source comparison explains why the current camera remainder is not equivalent to those implementations.

### Native-grid presentation

Godot recommends a low-resolution viewport and integer scaling for pixel art; noninteger enlargement produces unequal displayed pixel widths. Its documentation separately recommends `canvas_items` when sprites should move or rotate at subpixel positions: `viewport` first rasterizes at the low resolution, then stretches the completed image. Thus low-resolution design coordinates and low-resolution final rasterization are separate choices. Source: [Godot multiple resolutions, stretch modes and pixel-art guidance](https://docs.godotengine.org/en/stable/tutorials/rendering/multiple_resolutions.html#stretch-settings).

Godot's transform and vertex snapping settings round presentation without requiring integer simulation coordinates. The docs warn that snapping can make movement less smooth, particularly with camera smoothing, and discourage enabling both snapping stages together. They describe predictable quantization, rather than promising continuously smooth motion on a low-resolution raster. Source: [Godot ProjectSettings, 2D snapping](https://docs.godotengine.org/en/stable/classes/class_projectsettings.html#class-projectsettings-property-rendering-2d-snap-snap-2d-transforms-to-pixel).

Unity makes the same distinction. `Upscale Render Texture` renders into a temporary texture near the reference resolution before enlargement. `Pixel Snapping` snaps sprite rendering to a world grid without changing transform positions, and deliberately produces pixel-by-pixel movement. The default without the low-resolution texture renders near full screen resolution. Source: [Unity URP 14 Pixel Perfect Camera](https://docs.unity3d.com/Packages/com.unity.render-pipelines.universal@14.0/manual/2d-pixelperfect.html#grid-snapping).

**Application to this project, an inference:** a conventional strict 320 × 180 renderer would interpolate simulation positions, choose one shared drawing origin/grid, submit floors, actor, and foreground in depth order onto that grid, then present the completed native image at an integer-aligned destination. Snapping must account for sprite anchors/bounds. With a following camera, the actor and camera must use the same quantized presentation anchor, so rounding does not alternately move the followed actor relative to the camera. The scene can remain sharp and occlusion coherent; small native-pixel steps remain visible. Those steps should be distinguished from an extra forward/backward wobble or an occlusion-dependent displacement.

### Fractional scrolling after enlargement

The official raylib `core_smooth_pixelperfect.c` example uses a 160 × 90 texture and an 800 × 450 screen. It truncates the world camera, keeps its remainder in a second camera, multiplies that remainder by the virtual-to-screen ratio, draws the world to the low-resolution texture, then draws that texture under the second camera onto the screen framebuffer. The fractional correction is applied during the larger final draw. The example also offers overscan for exposed edges. Source: [raylib smooth pixelperfect example, lines 27–42, 73–82, 96–116](https://github.com/raysan5/raylib/blob/master/examples/core/core_smooth_pixelperfect.c).

The render texture's color attachment is created with one mip level using `rlLoadTexture`; that loader defaults to nearest minification and magnification. The example does not request bilinear filtering. Sources: [raylib render-texture creation](https://github.com/raysan5/raylib/blob/master/src/rtextures.c), [raylib texture sampler initialization](https://github.com/raysan5/raylib/blob/master/src/rlgl.h).

**Application, an inference:** after an integer 4× enlargement, a one-display-pixel translation is a quarter of an artwork pixel. A nearest-sampled enlarged pixel block can shift by that amount while preserving its colors and width. The block moves off the original artwork grid, but remains sharp on the finer final grid. This resolves smooth camera motion and phase-dependent filtering blur together when the higher-resolution presentation stage is available. It does not imply arbitrary smooth independent actor movement inside an already rasterized low-resolution scene. Such actors need their own correct display-resolution placement, or the entire depth-sorted scene must be rasterized on the finer grid. Foreground occlusion must share that placement policy.

The example's screenshot framing uses a smaller inset rectangle, while the overscan path uses the full window plus padding. Its camera remainder always uses the fixed virtual ratio. It is an authoritative demonstration of the two raster stages, not a ready-made acceptance test for every scaling/framing policy or moving depth-sorted actor.

## Where the current DragonRuby path differs

The inspected [renderer](../../mygame/app/render.rb) integer-aligns scenery inside padded 321 × 181 targets, fractionally presents those scenery runs to the main output, and draws the actor directly between them. `direct_actor` rounds its final bounds. The [camera](../../mygame/app/camera.rb) preserves fractional following and derives an integer compositing origin plus a remainder.

With this project's `aspect_size=180`, `hd=false`, the final game raster is 320 × 180; `Grid.render_scale` is 1 in the existing installed-SDK captures. The scenery's fractional presentation therefore samples back onto the artwork-sized grid **before** DragonRuby enlarges that completed raster for the window. It is not the final high-resolution remainder stage in the raylib example. Sources: [game metadata](../../mygame/metadata/game_metadata.txt), [previous SDK captures and measurements](single-scene-sampling-sources.md), installed `$DRAGONRUBY_HOME/docs/api/grid.md` and `docs/oss/dragon/grid.rb`.

**Sampling explanation, an inference:** at 1:1 size, moving a nearest-sampled texture less than a native pixel cannot move its sharp edge continuously on that raster. The sampled edge stays put until it crosses a native pixel boundary. A filter can instead distribute its colors across adjacent cells, but that changes edge contrast. Window enlargement after this step cannot recover a sharp edge at the discarded fractional position. This is an information/raster-stage limitation, not proof that the current blur or foreground wobble is unavoidable. Mismatched sampling, extra rounding, alpha mistakes, or inconsistent actor/foreground placement can introduce additional artifacts that conventional pipelines avoid.

## Existing Standard SDK controls

The installed sprite API documents `scale_quality_enum: 0` as nearest, `1`/`2` as linear, and `3` as pixel art; `nil` inherits metadata. The SDK scale-quality sample draws sprites with independent overrides. A target is later consumed as a sprite, so the target's presentation draw can use nearest while source artwork and final SDK window scaling continue to inherit other settings. This is a **consumer-draw sampler**, not a target-wide `min_filter` setting. No public independent target minification/magnification properties were found in the inspected API. Sources: `$DRAGONRUBY_HOME/docs/api/outputs.md:380`, `samples/01_rendering_basics/06_scale_quality_game_metadata/app/main.rb`, [official sprite API](https://docs.dragonruby.org/#/api/outputs?id=sprites).

Pixel-art filtering is not synonymous with nearest. DragonRuby's published SDL OpenGL shader measures the source footprint with derivatives and remaps fractional texture coordinates through `smoothstep`. Its OpenGL backend supplies linear filtering to that shader and falls back to nearest if unsupported. At approximately 1:1 sampling, its transition can span a source pixel; the name does not promise unchanged contrast at every fractional offset. Sources: [pinned SDL shader, `GetPixelArtUV`](https://github.com/DragonRuby/SDL/blob/67097705a79bf411cec03667f6d41dffbe699d12/src/render/opengl/SDL_shaders_gl.c#L139), [pinned OpenGL sampler setup](https://github.com/DragonRuby/SDL/blob/67097705a79bf411cec03667f6d41dffbe699d12/src/render/opengl/SDL_render_gl.c#L457). These files were retrieved with `curl` after the web reader failed. The distributed native binary's exact SDL SHA is not exposed, so backend identity remains a limit.

Custom target dimensions are supported: `RenderTarget#w=`/`h=` update native target data independently of Grid. This establishes that a 640 × 360 or larger intermediate can exist with HD off; it does not change the main framebuffer or expose a draw after its final enlargement. To use extra samples, drawing coordinates and dimensions must be scaled too. Downsampling back to 320 × 180 still faces the limitation above. No public bypass of that final low-resolution output was found in the inspected Ruby output implementation or sprite/render-target API. Sources: `$DRAGONRUBY_HOME/docs/oss/dragon/outputs.rb:1030–1065`, [render targets](https://docs.dragonruby.org/#/api/outputs?id=render-targets).

The installed 7.14 changelog explicitly marks `highdpi=true` with HD disabled as **Pro**, and describes sharper textures “without sub-pixel rendering.” Older grid documentation says HD is required and broadly labels HD Pro; that prose is stale: the later changelog also records HD being respected in Standard/Indie. These facts must not be collapsed into “highdpi is a Standard solution” or “HD off prevents every larger texture.” This investigation has no evidence that Pro high DPI exposes the required smooth final-raster translation. Sources: `$DRAGONRUBY_HOME/CHANGELOG-CURR.txt:64–65,315`, `docs/api/grid.md:177–189`, current [metadata's Pro section](../../mygame/metadata/game_metadata.txt).

Keeping 320 × 180 **design/world coordinates** while choosing a larger main `aspect_size` and scaling submissions would be a different conventional implementation, even with `hd=false`. It changes the project's current native-raster requirement and incurs more main-frame pixel work. It must be compared and measured explicitly, rather than presented as merely increasing the scenery target. Re-enabling HD conflicts with ADR-0013. Neither is a production change authorized by this note.

## Transparent foreground targets need a separate correctness check

SDL distinguishes ordinary alpha (`srcRGB * srcA + dstRGB * (1-srcA)`) from premultiplied alpha (`srcRGB + dstRGB * (1-srcA)`). Drawing ordinary straight-alpha sprites onto transparent black writes alpha-weighted RGB into that intermediate. Consuming those stored values with ordinary alpha again can multiply the RGB a second time. Source: [SDL blend-mode equations](https://wiki.libsdl.org/SDL3/SDL_BlendMode).

DragonRuby exposes custom RGB/alpha blend factors through `Numeric.compose_blendmode`. This can express premultiplied consumption using source `ONE` and destination `ONE_MINUS_SRC_ALPHA` for both RGB and alpha. Source: `$DRAGONRUBY_HOME/docs/api/outputs.md:383–457`, [official blend-mode API](https://docs.dragonruby.org/#/api/outputs?id=blendmode).

**Application, an inference:** a fading foreground run over the direct actor is a candidate for compounded alpha/edge errors because it is a transparent target with a fractional consumer draw. Test a solid faded foreground patch at integer and half-pixel placement against direct composition. Record both coverage and opacity. Correct premultiplied consumption can fix excess darkening and some edge bias, but cannot restore positional samples discarded by the 320 × 180 output. Tint and fade modulation on premultiplied sources must attenuate RGB and alpha consistently. Earlier [single-scene probes](single-scene-sampling-sources.md#the-strongest-inexpensive-candidate-is-consistent-alpha-handling) already demonstrate why an improved brightness centroid alone does not prove stable sharpness.

## Comparison and recommendation

| Candidate | What it can establish | Requirement or limit |
| --- | --- | --- |
| Existing scene draw with explicit nearest override | Removes color interpolation at the scenery presentation step | Retains native-grid positional steps; verify foreground and actor agree at thresholds |
| One shared native-grid scene, integer final placement | Coherent depth/alpha composition and stable sharp native artwork | Pixel-sized steps remain; must avoid a followed-actor rounding mismatch |
| Correct premultiplied consumption of transparent scenery runs | Correct foreground opacity/edges through an intermediate | Does not itself remove fractional-raster blur or quantization |
| Higher-resolution target downsampled to unchanged 320 × 180 output | Measures reconstruction/coverage improvements | Does not reproduce display-resolution motion; extra target cost |
| Low-resolution world target enlarged to a finer main raster, remainder applied there | Conventional raylib-style sharp camera scrolling | Needs an accessible larger final raster; independent actor/foreground still need coherent placement |
| Finer main raster, nearest artwork, one depth-sorted scene | Conventional smooth movement of actors, camera, and occluders without artwork filtering | More pixel work and a changed native output configuration |

First compare the inexpensive Standard controls and correct alpha against a conventional shared-grid reference; quantify extra wobble separately from expected native-grid stepping. Also compare the finer-main-raster reference in an isolated probe, preserving the game's 320 × 180 field of view, so the user can assess an implementation that actually permits sharp sub-artwork-pixel placement. Do not assert that either reported artifact requires a forced tradeoff before these comparisons. Conversely, do not claim a larger intermediate supplies that finer final stage when it still resolves through the unchanged native output.

The source review made no production edits. The coordinating investigation subsequently ran the renderer comparisons recorded below. Automated captures can establish pixel contrast, alpha, and positional thresholds; perceived smoothness and diagonal movement behind fading walls still require a playable comparison.

## Feasibility review: HD-off 1280 × 720 presentation prototype

The coordinating investigation is testing an isolated Standard configuration with `aspect_size=720`, `hd=false`, a virtual 320 × 180 world viewport, and a 4× submission scale. This is a plausible conventional implementation of a finer final raster while retaining the same world framing. It changes native output policy; it must not be adopted by quietly weakening the [display-configuration test](../../mygame/tests/display_configuration_test.rb). Source capability: the installed metadata lists `aspect_size=720` as 1280 × 720 at every license tier. The following points are an independent implementation review, not measured room-performance or visual acceptance claims.

- **Keep one final drawing grid.** Submit actor, foreground walls, caps, and any other overlapping upright artwork directly to the finer opaque scene using nearest sampling. Round final rectangle bounds in that raster. Retaining the existing direct-actor exception while filtering foreground through a low-resolution transparent layer would retain the disputed asymmetry. Anchors remain dimensionless fractions; destination widths/heights scale, while source-image crops and triangle source UVs do not. Destination triangle vertices, diagnostic coordinates, and label sizes need their appropriate destination scale. Sources: [sprite geometry](../../mygame/app/sprite.rb), [render preparation](../../mygame/app/render.rb), [lighting triangles](../../mygame/app/lighting.rb).
- **Make low-resolution floor placement agree with foreground.** In one axis, let the virtual camera offset be `c`, its integer origin `n = floor(c)`, and an integer-world scenery edge be `p`. Define the shared final translation as `t = round(-4*c)`, using the project's `floor(value + 0.5)` rule. Rasterize the floor edge at `p - n`; enlarge by 4 and place the texture at `4*n + t`, equivalently `round(-4*(c - n))`. Its final edge becomes `4*p + t`, matching direct scenery placement `round(4*(p - c))` for integer `p`. Do not replace `round(-4*c)` with `-round(4*c)`: they differ at exact half-pixel ties under this rounding rule. This algebra assumes integer texture dimensions and no later fractional translation. Fractional authored positions or dimensions need their own explicit final-bound alignment policy. A shared numerical origin is insufficient if one consumer uses a different filter or geometric rounding rule.
- **Keep floor illumination attached to the floor pass.** Produce the low-resolution lightmap with the same compositing camera as the floor, multiply it into the floor before enlargement, and present both under the same final destination. Applying that floor multiply over already tinted actors/foreground would darken them again. Existing upright receiver colors should still sample the interpolated world positions. A low-resolution shadow edge can move in larger increments than an actor on the finer grid; that is a remaining lighting-quality question to inspect, not proof of actor displacement. Sources: [floor/lightmap insertion](../../mygame/app/render.rb), [lightmap and receiver colors](../../mygame/app/lighting.rb).
- **Recheck transparency using the new composition path.** Original atlas assets use ordinary straight-alpha consumption. Direct foreground drawing onto an opaque scene should use ordinary blending; a premultiplied consumer intended for a previously rasterized transparent target is not interchangeable. Prefer an opaque floor composite when it covers the viewport. Faded caps and walls should each blend once over the accumulated scene. Source: [SDL alpha equations](https://wiki.libsdl.org/SDL3/SDL_BlendMode), [foreground fading](../../mygame/app/foreground_fade.rb).
- **Preserve the virtual viewport everywhere it matters.** Camera extent, clamping, culling, inverse coordinate conversion, HUD placement, and any screen-space input handling must continue to use virtual 320 × 180 coordinates where intended. `Grid.w`/`Grid.h` become 1280/720; changing metadata alone expands the camera view and moves HUD geometry. Keep the drawing scale at the rendering boundary. Sources: [camera](../../mygame/app/camera.rb), [preview HUD](../../mygame/app/room_preview.rb), [UI label sizing](../../mygame/app/ui.rb).
- **Inspect the actual window, not only the native screenshot.** A fixed 1280 × 720 native raster displayed in a 640 × 360 window is downsampled; a 1920 × 1080 window enlarges it by 1.5×. One native-pixel edge step then spans 0.5 or 1.5 display pixels. Final filtering can soften edges, and nearest can quantize their motion unevenly. Four-native-pixel artwork blocks become two or six display pixels at those particular sizes, but moving block boundaries can still have noninteger phase. Best-case native screenshots establish neither the final SDK sampler's behavior nor artifact-free noninteger window sizes. Integer output scaling is the standard way to avoid unequal displayed pixel widths; see [Godot's integer scaling explanation](https://docs.godotengine.org/en/stable/tutorials/rendering/multiple_resolutions.html#stretch-scale-mode). Test smaller windows and a 1.5× fit explicitly before claiming all-window sharpness.

This design can keep raycasting and low-resolution floor-lightmap work unchanged while increasing upright drawing and final composition resolution. That is a cost hypothesis, not an FPS result: the main output contains sixteen times as many pixels, and a particular driver may have different bottlenecks. Validate the real room, lamp overlay, fading, camera edges, and output sizes before choosing it over the corrected native-grid reference.

## Actual renderer comparisons, 2026-10-21

Ran 256 native captures on the installed DragonRuby 7.21 **Standard** build, Linux offscreen OpenGL, software rendering, with **HD disabled throughout**. Production Ruby and metadata were unchanged. Temporary probes are in ignored `mygame/tmp/`; isolated reference games are under `/tmp/`. This is an implementation comparison, not acceptance of a new raster policy.

### Reproduced scene-wide blur

The first probe uses a frozen real south-facing player frame, a 64-pixel black/white striped floor patch, and translucent foreground wall/cap patches. Camera and actor move together through 32 positions, advancing 1/16 world pixel on both axes per capture. The foreground alphas stay fixed, so this isolates presentation from animation, fade timing, collisions, and lighting.

Measure one interior 50-pixel scanline of the floor. Its edge contrast is the sum of absolute neighboring red-channel differences. An ideal alternating black/white line has 49 edges × 255 = **12,495**; a solid grey line has zero. This deliberately severe one-pixel pattern diagnoses filtering, rather than estimating how much of the actual room becomes blurry.

| Presentation path | Minimum / maximum edge contrast across 32 phases | Intermediate grey pixels on that 50-pixel line |
| --- | --- | --- |
| Current fractional scenery presentation, inherited pixel-art sampler | **0 / 12,495** | 0–50 |
| Same pipeline, final scenery destination rounded | 12,495 / 12,495 | 0 |
| Same fractional destination, explicit nearest scene sampling | 12,495 / 12,495 | 0 |

At a half-pixel phase the current renderer turns the alternating pattern into solid grey. The direct actor does not pass through that filter. This reproduces a scene-sampling defect independent of actor placement; changing simulation speed or interpolation cannot restore the detail lost during this draw.

Both inexpensive controls remove the interpolation blur. On the unchanged native raster, their sharp scenery positions still advance in whole-world-pixel increments. These controls therefore do not establish smooth sub-artwork-pixel movement, nor demonstrate that the user's previous camera-shake complaint is resolved. Neither control was adopted.

### Confirmed a separate foreground alpha error

At integer placement, sample a white foreground stripe with `a: 64` over black, away from the player and cap:

| Path | Measured red channel |
| --- | --- |
| Current transparent scenery target, ordinary final blend | **16** |
| Same target with nearest final sampling | **16** |
| Original stripe drawn directly onto black | **64** |
| Transparent target consumed with explicit premultiplied blend | approximately **63** |

The existing two-stage ordinary blend compounds opacity: `(64/255)²` rather than `64/255`. This is now reproduced in the installed renderer, not merely inferred from SDL's equations. The custom-blend probe has small channel/edge differences and is not an exact production color-equivalence result. The direct composition reference gives the intended value without that extra target.

Correct premultiplied consumption still yielded **zero** stripe contrast at the half-pixel camera phase. Alpha correction and scene blur are separate issues. Fractionally filtered foreground coverage over the separately aligned actor is also a credible source of apparent shimmer, but this experiment does **not** prove it is the sole cause of the user's exact diagonal-wall jitter. The original case still needs a movement playtest, including fade eligibility at neighboring collider columns and camera clamping.

### Conventional shared-raster reference

Built a small independent DragonRuby game that draws the same floor, frozen player, wall, and cap in order with nearest sampling. Every sprite uses the same camera translation and final-bound alignment; there is no separate actor placement exception. Ran it twice:

1. `aspect_size=180`, `hd=false`: 320 × 180 final raster.
2. `aspect_size=720`, `hd=false`: 1280 × 720 final raster, virtual 320 × 180 world/view, destination positions and sizes scaled by four. Source-image crops and anchors retain their source units/fractions.

Both references preserve only black/white colors in the floor stripes at the 12 measured phases; no interpolation greys appear. In the 1280 reference each source pixel occupies four raster pixels, and scenery can move by **one final pixel = 1/4 world pixel**. The followed player's submitted X stays exactly 640 while the background advances monotonically. The 320 reference can move the background only by whole world pixels. These are actual distinct rendering stages in the same Standard SDK, rather than a proposed sampler workaround or a larger texture downsampled back into 320 × 180.

This establishes a practical way to remove the specific blur mechanism while substantially reducing motion quantization. It does not promise continuous motion between physical display pixels or artifact-free arbitrary window scaling. See the output-resampling limit in the feasibility review above.

### Actual lit-room prototype and preliminary cost

Copied the project-owned game files into `/tmp/descent-room-reference`, changed **only that copy's** native reference raster to 1280 × 720, and loaded an opt-in renderer replacement:

- Camera clamping/culling and world geometry retain the virtual 320 × 180 viewport.
- Existing raycasting, source origins, receiver colors, and fading rules stay in world coordinates.
- The floor and its multiplied lightmap render together at **321 × 181**, then enlarge with nearest sampling and the final raster-aligned camera remainder.
- Actors, walls, mounted artwork, and caps render directly in normal depth order onto the finer main output with nearest sampling and ordinary alpha. Their final bounds share one placement policy. No transparent post-actor scenery target is needed.
- The probe omits HUD/diagnostic drawing; adapting UI/input coordinate boundaries is required for a production implementation.

Captured 32 matching actual-room phases through two world pixels near the southern doorway, after warming foreground fading. Idle/flame artwork remains frozen while the lamp, lightmap, tint, depth order, and foreground fading run. Selected native captures were inspected. A local [interactive phase comparison](../../mygame/tmp/conventional-rendering-comparison/index.html) displays the current and reference captures with a shared slider. This compares complete pipelines: the reference also corrects the extra alpha multiplication, so changed foreground darkness is expected. Slow phase playback is not a normal-speed motion or collision test.

One short run per implementation at a requested 1280 × 720 window measured 101 callbacks after warm-up, with screenshots excluded from the timing interval:

| Implementation | Ruby preparation median | Preparation p95 | Observed callbacks/sec |
| --- | --- | --- | --- |
| Current 320 × 180 renderer | 10.84 ms | 13.96 ms | 61.15 |
| 1280 × 720 shared-raster prototype, low-resolution floor lighting | 10.92 ms | 16.31 ms | 59.66 |

These preliminary results demonstrate that this isolated configuration runs in Standard with HD off, and did not reproduce the historical severe slowdown on this software-rendered host. They do **not** prove a hardware performance improvement, a 60-FPS guarantee, or that diagnostics and all window sizes remain affordable. The prototype increases main-frame pixel area sixteenfold, while leaving the lighting target and raycasting workload small. It also changes which work happens natively after Ruby returns. Full-size lighting targets were deliberately not substituted.

### Recommended implementation direction and remaining acceptance checks

The strongest candidate is a **shared finer final raster with nearest artwork and low-resolution floor lighting**. It follows the conventional separation between a virtual design resolution and the surface where motion is finally rasterized. It can address the reproduced scene blur, the different actor/foreground placement paths, and the compounded foreground alpha together. Merely changing the camera rounding rule does not provide that separation.

This requires revisiting the **native 320 × 180 raster** part of ADR-0013 and its configuration test, while retaining HD off and the same world framing. There is no finding here that authorizes silently changing that requirement. A larger intermediate that still resolves into the current 320 × 180 framebuffer is not equivalent. Keep the production renderer intact until a deliberate implementation/playtest decision is made.

Acceptance must include normal-speed diagonal walking and sneaking behind both walls and caps, transitions between adjacent fading columns, all camera clamps and clamp transitions, lamp on/off, animation, doors, diagnostics, and small/maximized windows. In particular, verify actual displayed output at noninteger scales: native captures cannot establish how the final SDK window filter handles a one-raster-pixel edge at a fractional display phase. If that stage reintroduces blur, its sampling/output-scale policy must be addressed explicitly rather than masking it with another per-object correction.

### Local reproduction artifacts

Relative to `mygame/`, ignored workspace files are:

- `tmp/scene_blur_occlusion_probe.rb`: `--probe-mode baseline`, `aligned`, `nearest`, or `premult`, 32 captures each.
- `tmp/conventional_rendering_reference.rb`: isolated small reference game entry point, used with native `aspect_size=180` and `720`.
- `tmp/conventional_room_reference.rb`: opt-in actual-room renderer and timed phase playback for the isolated larger-raster game.
- `tmp/conventional_room_baseline.rb`: same phase/timing schedule using the normal project renderer.
- `tmp/conventional-rendering-comparison/index.html`: local interactive room comparison; dependent capture files are alongside it.

The isolated games/captures are `/tmp/descent-render-reference/` and `/tmp/descent-room-reference/`. The image reader/measurements are `/tmp/analyze_scene_blur.py`, using only Python's standard library. These temporary files are reproducibility aids for this workspace, not checked-in tests or permanent game dependencies.

For example, reproduce the baseline controlled probe without a display:

```sh
SDL_VIDEODRIVER=offscreen SDL_AUDIODRIVER=dummy LIBGL_ALWAYS_SOFTWARE=1 \
  bin/rake run -- --eval tmp/scene_blur_occlusion_probe.rb --probe-mode baseline
```

At the end of that initial research phase, only this Markdown note had been added; production Ruby, metadata, gameplay state, and accepted ADRs were unchanged. The subsequent implementation trial is recorded next.

## Follow-up: nearest scene presentation and downsized artwork

The user changed metadata to `scale_quality=0` and confirmed the scene blur disappeared. They then reported the mounted candles and all four pedestals changing their internal pixel pattern while the camera moves. This warrants testing a smaller fix before changing output resolution. Nearest presentation still quantizes positions on the native grid, but the user's observation means that fact alone does not establish an unacceptable movement result.

Inspection of the actual Ritual Gate export identifies a shared property:

| Artwork | Atlas crop | Authored drawing size |
| --- | --- | --- |
| Pedestals, IDs 2–5 | 32 × 32 | 32 × 24 |
| Mounted candles, IDs 121–122 | 32 × 32 | 16 × 16 |

The camera already places these sprites at integer positions inside the scene targets. A new probe freezes the real source crops, excludes lighting/fading/animation, and moves the artwork through integer X/Y placements in an opaque 321 × 181 target. The final draw stays at the same integer position, with nearest sampling inherited from metadata. Thus neither fractional scene presentation nor window scaling is needed to reproduce the internal change.

After excluding two startup captures, compare each 30-frame sequence after removing the known integer translation:

| Artwork / sampling | Distinct internal pixel patterns | Maximum changed pixels relative to first measured pattern |
| --- | --- | --- |
| 32 × 24 pedestal, nearest resize | **3** | **19** |
| 16 × 16 candle, nearest resize | **12** | **55** |
| Same pedestal crop drawn at 32 × 32 | 1 | 0 |
| Same candle crop drawn at 32 × 32 | 1 | 0 |
| Downsized pedestal, pixel-art resize | **1** | **0** |
| Downsized candle, pixel-art resize | **1** | **0** |

The stable native-size controls and unstable reductions establish a minification problem in this installed rendering path. A small source-coordinate bias also stabilizes the reductions in a probe, which is consistent with nearest sampling at texel-boundary ties and numerical differences during interpolation. That numerical explanation is an inference; the distributed native renderer was not instrumented. The bias can push crops beyond image bounds, produces SDK warnings, and was not adopted. A fixed-origin resize pass also stabilized the samples, but adds unnecessary targets/lifetime management for this fix.

The implementation trial filters **only downsizing draws** with `scale_quality_enum: 3`, while the final scene draw continues to inherit the user's **nearest** metadata setting. Normal-size/enlarged artwork retains metadata sampling; explicit sprite sampler choices are respected. Source crops, artwork dimensions, flips, camera remainder, simulation, lighting geometry, and HD-off native raster remain unchanged. Pixel-art filtering is used to reduce the source into its authored smaller size; that resulting image then moves through nearest scene presentation. This does not restore fractional filtering across the whole scene.

The actual production `Render.draw` path then passed the same 30-placement image comparison: one internal pattern and **zero changed pixels** for both resized props and both native-size controls. A normal lit-room capture playback covering pedestals and mounted candles completed, with selected captures inspected. The 195 native tests pass, including a regression using all six affected room sprites, untouched source crops/frame data, preserved explicit samplers, and inherited scene-presentation sampling. Existing ordering tests compare artwork independent of the newly added sampler property.

Temporary reproduction: `mygame/tmp/nearest_scaled_art_probe.rb`, modes `nearest`, `pixelart`, `linear`, `bias`, `cached`, and `production`. Captures are `tmp/nearest-scaled-MODE-N.png`; the initial nearest baseline is `tmp/nearest-scaled-N.png`. First-frame resource initialization is excluded from image comparisons. Probe-only overrides, biasing, and cache targets do not enter production.

The user still needs to confirm the same diagonal routes, mounted flame animation, pedestal detail, foreground wall/cap occlusion, and actual window scaling. The earlier transparent-target alpha error is a separate finding and remains unchanged during this sampling trial. No larger-raster policy or replacement ADR has been adopted.
