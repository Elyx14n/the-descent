# Single-scene sampling: SDK evidence

Investigated 2026-10-19 against the installed DragonRuby 7.21 SDK and its published SDL fork. This note records capabilities and hypotheses; it does not accept a new rendering policy. [ADR-0013](../adr/0013-keep-hd-disabled.md) requires `hd=false`. [ADR-0016](../adr/0016-fixed-step-simulation-and-interpolated-drawing.md) owns temporal interpolation. Existing renderer evidence is in [decoupled rendering](decoupled-rendering.md#residual-jitter-playtest-iteration-3).

## What is available

**Per-draw sampling is the cheapest capability to investigate first.** Installed `docs/api/outputs.md:380` specifies `scale_quality_enum: 0` for nearest, `1` or `2` for linear, `3` for pixel art, and `nil` to inherit metadata. The actual installed `samples/01_rendering_basics/06_scale_quality_game_metadata/app/main.rb` draws the same image with explicit `0`, `1`, and `3` overrides. A render-target texture is subsequently drawn as a sprite, so its presentation draw can carry the same property independently of the sprites placed inside it. See the [official sprite API](https://docs.dragonruby.org/#/api/outputs?id=blending).

Older SDK metadata comments describe `2` as antialiased, and the label example in `outputs.md:751` incorrectly describes `2` as pixel art. Neither establishes a separate geometric-coverage or MSAA mode: the current sprite API and working sampling sample agree on linear for `1`/`2` and pixel art for `3`. Searches of installed API documentation and Ruby runtime sources found no public sprite multisampling, analytical edge coverage, or sample-count property.

**The pixel-art filter is nonlinear.** SDK `CHANGELOG-CURR.txt:4` identifies [DragonRuby/SDL](https://github.com/DragonRuby/SDL) as its pinned SDL source with custom patches. The fork's inspected head was `67097705a79bf411cec03667f6d41dffbe699d12` (2026-10-06). Its [OpenGL pixel-art shader](https://github.com/DragonRuby/SDL/blob/67097705a79bf411cec03667f6d41dffbe699d12/src/render/opengl/SDL_shaders_gl.c#L139) computes the source footprint using derivatives, then remaps fractional texture coordinates with `smoothstep`. Its [OpenGL sampler setup](https://github.com/DragonRuby/SDL/blob/67097705a79bf411cec03667f6d41dffbe699d12/src/render/opengl/SDL_render_gl.c#L457) uses linear filtering underneath this shader and falls back to nearest when unsupported. These sources were retrieved with `curl` because the web reader returned a cache miss. The installed distribution does not expose the precise native build SHA, so matching this fork head to every compiled backend is not proven.

It follows that drawing an actor at `+fraction` into a target and presenting that target at `-fraction` does not imply the two filtering stages cancel. Numerical coordinates cancel; the two rasterized images need not. Linear filtering removes this particular nonlinear remapping, but drawing finite sprite rectangles still involves raster coverage and boundaries. A sampler change therefore needs image measurements rather than coordinate-only tests.

**Larger custom render targets are public API, independently of the logical canvas.** Installed `docs/api/outputs.md:872` explicitly sets a target's `w` and `h`; `docs/oss/dragon/outputs.rb:1041` writes those values to target data without changing `Grid` or requiring HD. See [render targets](https://docs.dragonruby.org/#/api/outputs?id=render-targets). The current project already demonstrates a 321×181 target with a 320×180 HD-off canvas. This establishes custom dimensions; it does not by itself establish a supersampling solution.

A 2× target would require scaling destination coordinates and dimensions, camera offsets, lightmap geometry, and diagnostics by two, then presenting it at the original logical size. Source-image crop coordinates remain in source pixels. Merely increasing target dimensions creates a larger drawing area; it does not automatically increase scene resolution. The approximate texture-area cost grows with scale squared: 642×362 contains four times the pixels of 321×181, and 1284×724 contains sixteen times. This is arithmetic, not a measured GPU cost or speed prediction. Supersampling can reduce quantization error but still requires a suitable downsampling filter and atlas-edge checks.

**Standard should not assume custom shaders.** Installed `docs/api/outputs.md:927` describes the older Indie/Pro ShaderSim beta using GLSL ES2. The newer 7.16–7.19 changelog marks current shader support experimental and Pro. Installed `samples/14_shaders/03_shaders_on_render_targets/app/main.rb` uses `outputs[:target].shader = { path: ... }`, requires `.hlsl` files, and its metadata enables `shaders=true`. Thus the SDK's old prose and current samples concern different generations of shader support. Neither supports treating custom fragment shaders as available in this Standard configuration. Shader-based coverage reconstruction or per-pixel actor/background composition is a capability change, not an existing low-cost rendering switch. Sources: installed `CHANGELOG-CURR.txt`, `samples/14_shaders/`, and [official shader documentation](https://docs.dragonruby.org/#/api/outputs?id=shaders).

**`highdpi=true` is distinct from supersampling a scene target.** Installed 7.14 changelog says Pro can use high DPI with HD disabled, producing sharper textures without subpixel rendering. This is newer than `docs/api/grid.md`, which still says HD is required. No evidence here demonstrates that enabling high DPI reconstructs the missing actor position or removes the two-stage wobble, and it is not needed for the candidate sampler tests. HD remains disabled.

## Alpha and coverage

DragonRuby documents [custom blend factors and operations](https://docs.dragonruby.org/#/api/outputs?id=blendmode), including independent RGB and alpha factors. Installed `docs/api/outputs.md:383–457` exposes `Numeric.compose_blendmode`, `BLENDFACTOR_ONE`, `BLENDFACTOR_SRC_ALPHA`, `BLENDFACTOR_ONE_MINUS_SRC_ALPHA`, and `BLENDOPERATION_ADD`. This is enough to express premultiplied-source blending: RGB factors `ONE`, `ONE_MINUS_SRC_ALPHA`; alpha factors `ONE`, `ONE_MINUS_SRC_ALPHA`, both added. It does not establish whether DragonRuby automatically compensates for an intermediate target's RGB representation.

The [SDL blend implementation](https://github.com/libsdl-org/SDL/blob/main/src/render/SDL_render.c) distinguishes ordinary blending (`srcRGB * srcA + dstRGB * (1-srcA)`) from premultiplied blending (`srcRGB + dstRGB * (1-srcA)`). In an ordinary transparent render target, the former writes alpha-weighted RGB. Reapplying the same source-alpha multiplication when drawing that target can attenuate translucent edges again, unless the engine adjusts for it. This general mechanism is also discussed by SDL's maintainers in [issue 6990](https://github.com/libsdl-org/SDL/issues/6990). It is a reason to test target-edge colors and fading separately; it is not evidence that this is the cause of the player's centroid wobble in DragonRuby.

An opaque, isolated blue-square centroid is a useful motion diagnostic but cannot establish correct transparent sprite edges, fade opacity, tint, overlap, or lighting. A candidate needs transparent artwork and a faded foreground layer over a contrasting background. Changing target blending alone cannot recover positions already quantized away during rasterization.

Pixel arrays are another Standard API: installed `docs/api/pixel_arrays.md` documents ABGR pixels and arbitrary dimensions, also available in the [official pixel-array documentation](https://docs.dragonruby.org/#/api/pixel_arrays). They could encode manually computed fractional coverage, but would move image reconstruction and uploads into project code. No CPU cost, transparency correctness, or visual suitability has been demonstrated. This is substantially more implementation than a sampler override.

## Candidate order and evidence boundary

1. Compare explicit linear versus pixel-art filtering independently for the baked actor and final scene draw, retaining integer-aligned scenery. Measure centroid, atlas contamination, and edge colors across camera phases. This uses existing sprite properties and keeps target dimensions unchanged.
2. If geometry-edge quantization remains, test an isolated actor crop with a transparent border or explicit area-coverage construction. A linear texture sample inside a padded rectangle can behave differently from moving a tightly bounded opaque rectangle; any improvement must also hold for the real atlas and alpha.
3. Only then compare 2×/4× scene targets and downsampling. Higher raster resolution is plausible but introduces pixel work and broader coordinate changes; it is not presumptively cheaper than the two existing low-resolution scenery targets.
4. Custom shader reconstruction is outside the demonstrated Standard feature set. CPU pixel reconstruction is technically accessible but has no present justification.

These are research hypotheses. This sources investigation ran no renderer probes and changed no game code. The root investigation records any actual captures and conclusions separately. The validated interleaved direct-actor implementation remains the comparison baseline.

## Actual renderer experiments

The follow-up investigation generated 704 native 320×180 captures: 44 configurations at 16 fractional camera offsets. All ran on the installed 7.21 Standard build with `hd=false`, offscreen OpenGL and software rendering. Production game code and metadata were unchanged; opt-in scripts temporarily replaced `Render#composite_artwork` in their own processes.

Each synthetic scene contained a four-tile patch cropped from a contrasting 544×544 atlas, a tightly bounded opaque blue square, an equivalent blue square with transparent padding, and the real player's south-facing idle frame. Camera X advanced through `0/16 ... 15/16`; Y used the same phases with a `0.375` offset and wrap. All three actors followed the camera at fixed screen positions. Scenery retained the existing integer-aligned compositing camera. The comparison baseline drew actors directly between scenery runs, as the normal preview does.

The nearest/linear/pixel-art sampler matrix covered both transparent and opaque scene backgrounds. Further cases scrolled through fractional source crops instead of fractional destination rectangles, increased the scene raster to 2×/4×/8× while retaining HD off, and tested explicit premultiplied-alpha blending.

### Position is recoverable much more closely than the solid-square test suggested

The tightly bounded square continued to wobble by about 0.9 pixels with the ordinary samplers, because filtering a texture does not supply geometric coverage outside its rectangle. A padded sprite is a different case: its visible edge lies inside the rectangle and can be reconstructed by sampling transparent texels. The real player already has transparent margins. Thus the earlier square result was a valid failure case, but overstated the likely motion error for the actual player.

For the real player, centroid was measured using the sum of RGB intensities over a fixed, isolated region on black; this is a brightness centroid, not the player's feet or collision anchor. The blue probes used blue intensity above red/green. The table reports maximum minus minimum over the 16 captures, in native pixels. Small residuals should not be attributed solely to quantization without further investigation.

| Strategy | Player centroid span X / Y | Player edge-contrast ratio versus direct baseline |
| --- | --- | --- |
| Current direct actors between scenery runs | 0 / 0 | 1.00 throughout |
| One native scene; inherited pixel-art sampling; ordinary alpha | 0.014 / 0.211 | 0.62–0.79 |
| One opaque native scene; linear actor and scene sampling | 0.004 / 0.139 | Not separately summarized |
| One native scene; premultiplied actor/scene; pixel-art sampling | 0.007 / 0.010 | 0.64–0.82 |
| One native scene; premultiplied actor/scene; linear sampling | 0.005 / 0.013 | 0.58–0.78 |
| One 2× scene; linear sampling and source-space scrolling | 0.005 / 0.107 | 0.74–0.90 |
| One 4× scene; linear sampling and source-space scrolling | 0.004 / 0.053 | 0.89–0.93 |
| One 8× scene; linear sampling and source-space scrolling | 0.004 / 0.040 | 0.93–1.00 |

Edge contrast here is the sum of absolute horizontal/vertical neighboring RGB differences over the same player region, divided by that measure in the direct baseline. It is a diagnostic for edge softening, not a perceptual quality score. The same sprite and animation frame were used at every phase. The direct baseline's pixels were identical across phases. All tested strategies retained zero detected interior tile seams and zero contrasting-neighbor contamination in this synthetic patch; this does not establish every room tile or atlas is safe.

Source-space scrolling at native resolution produced the same summarized player measurements as the corresponding fractional-destination draw. Moving the fractional offset from one rectangle field to another did not solve the problem.

### The strongest inexpensive candidate is consistent alpha handling

The successful alpha experiment first drew the selected player frame at integer coordinates into a transparent 64×64 cache using ordinary alpha blending. This produced alpha-weighted RGB in the cached texture. The cache was generated once, before its first consumer. When sampling that texture into the scene, and when presenting the transparent scene, it used this explicit blend:

```ruby
Numeric.compose_blendmode(
  BLENDFACTOR_ONE, BLENDFACTOR_ONE_MINUS_SRC_ALPHA, BLENDOPERATION_ADD,
  BLENDFACTOR_ONE, BLENDFACTOR_ONE_MINUS_SRC_ALPHA, BLENDOPERATION_ADD
)
```

This avoids multiplying already weighted RGB by source alpha again. Matching pixel-art samplers reduced the padded square's centroid spans to approximately `0.008 / 0.007`; matching linear samplers reduced them to `0.001 / 0.001`. The real player results are in the table. Mixing linear and pixel-art samplers was less stable than matching them in this probe. The nonlinear shader alone therefore does not establish the cause of centroid drift: padding, alpha representation, geometric coverage, and the pairing of reconstruction filters all matter.

This is a demonstrated candidate for almost preserving position in one scene, not an equivalent replacement for the current rendering. It still changed the player's pixels as camera phase changed, and selected captures visibly softened the artwork. Across adjacent sampled phases, maximum total player RGB change was about 5.5% of the first phase's brightness with the premultiplied pixel-art pair, versus zero in the direct baseline.

Even ideal linear filtering explains this remaining tradeoff. In one dimension, a fractional shift followed by the opposite shift preserves a padded image's brightness centroid but generally broadens it. At half a pixel, the combined reconstruction is a three-tap `[0.25, 0.5, 0.25]` filter, whereas at an integer phase it is unchanged. The second shift does not invert the first sampling operation. Consequently, a steady centroid can coexist with periodic softening/sharpening of fine details. The pixel-art filter has its own phase-dependent reconstruction; it must be assessed from captures rather than assumed to behave exactly like this linear example.

### Integration and cost boundaries

Sixteen further normal-room captures compared the current renderer and the premultiplied pixel-art candidate near the pedestals and mounted lights. For this probe, a full 512×256 idle/lamp-on sheet was cached once, preserving source crops and animation changes, before the normal RoomPreview lighting/render path ran. Selected pairs were inspected: the scene and occlusion order were retained, while the player was softer. This does not establish correct appearance for every animation/facing, lamp-off/death sheet, opacity transition, camera edge, or translucent overlap. Fading, tinting, and transparency require explicit acceptance checks before adopting a different alpha convention; setting `a` on a premultiplied sprite also requires consistent RGB attenuation.

The cache is an extra asset texture, but does not need another actor rendering pass each frame. A production version would need to own cache creation, source changes, reload invalidation, and every required sprite sheet. It could instead use premultiplied source assets. Neither integration has been implemented. A scene could then contain all scenery and actors in normal depth order and be presented once. Lighting's existing producers would remain separate: "one scene" does not mean one render target for the whole lighting pipeline.

Short sequential software-rendered room timings used 30 warm-up callbacks and 121 measured callbacks, comparing the direct baseline with the premultiplied pixel-art candidate. Ruby preparation medians were 11.05 → 11.23 ms at a 640×360 window and 11.20 → 11.24 ms at 1920×1080. There is no demonstrated preparation-time saving. Callback-rate samples included an inconsistent over-100 Hz offscreen result and are unsuitable for a GPU/displayed-FPS conclusion. Fewer scene switches and presentation draws could reduce native work, but a hardware speedup has not been established.

Supersampling is the expensive alternative: relative to the two current 321×181 scenery targets, one 2× scene has twice their combined area, 4× has eight times, and 8× has 32 times. These ratios concern scene texture area, not whole-game time. The probe scaled submitted scenery, actor, and lightmap quads; it did not increase lighting raycasts or the logical canvas. Higher resolution retained more edge contrast but did not automatically provide the smallest player-centroid span. It is not currently justified as a performance optimization.

The current renderer remains the recommendation when stable, sharp player artwork is the requirement. If a single scene is still desirable, the next playable experiment should be the native-resolution premultiplied pixel-art candidate, explicitly assessing softness rather than treating centroid stability as complete visual equivalence. No movement-policy or simulation changes are needed for that experiment.

### Local reproduction artifacts

The temporary probe scripts and captures are retained under ignored `mygame/tmp/`, following the earlier jitter investigations. They are workspace artifacts, not checked-in regression tests:

- `single_scene_sampling_probe.rb`: sampler/background matrix, source-space scrolling, and 2×/4×/8× scenes.
- `single_scene_premult_probe.rb`: cached player frame, independent actor/scene alpha conventions, matching/mixed samplers.
- `single_scene_room_probe.rb`: normal lit-room captures, `--probe-mode direct` or `--probe-mode single`.
- `single_scene_timing_probe.rb`: normal-room preparation timings, the same modes and `--probe-width 640` or `1920`.
- `sampling-*.png` and `single-room-*.png`: native captures. For example, compare `sampling-direct-8.png` with `sampling-pma-a3-s3-o0-b1-8.png`.

Run a probe from the repository root with the installed SDK configured:

```sh
SDL_VIDEODRIVER=offscreen SDL_AUDIODRIVER=dummy LIBGL_ALWAYS_SOFTWARE=1 \
  bin/rake run -- --eval tmp/single_scene_premult_probe.rb
```

Image measurements used an external temporary PNG decoder and RGB analysis; they are descriptive experiments, not assertions in the native unit suite. No production Ruby files, metadata, gameplay state, or accepted ADRs changed in this investigation.

## Follow-up: direct actor blur at camera boundaries

After merging the diagonal-jitter fix, the user reported that some sprites, especially the player's face, occasionally looked blurry, including while standing still. The merged renderer still draws the player directly between scenery runs; none of the single-scene experiments above had entered production.

The earlier sharpness baseline covered actors centered under a following camera. It missed fractional screen positions when the camera clamps at a room edge. In a new renderer probe, the same frozen south-facing player frame remained unchanged at all 16 following-camera offsets, but softened as it crossed fractional screen pixels with one or both camera axes clamped. Relative to the sharpest phase, minimum total edge contrast was 0.80 with X clamped, 0.83 with Y clamped, and 0.66 with both clamped. A player that stops at one of those fractional positions retains the soft image while standing still; changing animation is not required to produce it.

The fix rounds only the final screen-space bounds of directly drawn actors to the native raster, after adding the scenery's fractional presentation offset. It accounts for anchors, so centered odd-sized artwork aligns its rectangle edges rather than blindly rounding its center. It does not round the world position, interpolated presentation anchor, camera motion, lighting source, receiving collider, or foreground-fade geometry. Sprite crops, dimensions, tint, depth ordering, and metadata sampling remain unchanged.

Verification:

- Before/after renderer captures cover 16 phases each with a following camera, X clamped, Y clamped, and both clamped. After the fix, the frozen player's nonblack pixel pattern was identical at every phase after accounting for integer movement, in all four scenarios.
- Another 64 captures hold the player stationary at fractional world coordinates and advance only the idle animation: all eight frames, four facings, following and clamped cameras. Every rendered player region exactly matched a separately drawn pixel-aligned reference of the same animation frame, with zero mismatching pixels.
- Two native regressions cover 96 clamped player positions across low/high edges and corners, unchanged fractional fade anchors and frame data, preserved sprite crops, anchored odd-sized actors, negative coordinates, and fractional scenery offsets across floor-camera boundaries. They failed before the fix. All 194 native tests and RuboCop (53 files) pass afterward.
- Temporary workspace artifacts: `tmp/direct_actor_blur_probe.rb`, `tmp/idle_actor_blur_probe.rb`, `tmp/actor-blur-before-*.png`, `tmp/actor-blur-*.png`, and `tmp/idle-blur-*.png`, relative to `mygame/`. The probes use the same offscreen command pattern as above.

This is a draw-only crispness tradeoff: the actor now moves by native pixel steps when crossing a stationary viewport, with at most half a native pixel of alignment error on either axis. The fractional camera/scene scroll that fixed whole-viewport diagonal jitter remains in place. Scene textures still undergo fractional filtering, so this does not promise permanently crisp moving scenery or remove soft detail already present in a source frame. Human playtesting must confirm standing-player detail, motion near room edges, the transition into camera following, and continued absence of camera shake.

The user subsequently confirmed that the final-screen alignment fixed the reported blur. This confirms the observed issue; it does not broaden the claim to every scenery texture or all future actor scaling policies.
