# Decoupled rendering research and verification

Investigated 2026-10-19 against installed DragonRuby 7.21 and the two requested articles. The accepted policy is [ADR-0016](../adr/0016-fixed-step-simulation-and-interpolated-drawing.md).

## Sources and findings

- [Tyler Glaiel, How to make your game run at 60fps](https://medium.com/@tglaiel/how-to-make-your-game-run-at-60fps-24c61210fe75), especially Decoupled Rendering and Resyncing: separate whole fixed updates from frame production and interpolate previous/current transforms using the accumulator remainder. Keep discrete animation/object states current; reset transform history for teleports and loading. Interpolation adds visual latency. Avoid fuzzy timing or snapping elapsed time to guessed refresh intervals because that can distort game time.
- [Glenn Fiedler, Fix Your Timestep!](https://gafferongames.com/post/fix_your_timestep/): fixed-size updates preserve simulation behavior, while interpolation reconciles fractional presentation time. Catch-up needs headroom; bounded update work prevents an overload spiral. An accumulator uses elapsed time to decide how many fixed updates are due without passing variable timesteps into physics.
- [DragonRuby getting-started guide](https://docs.dragonruby.org/#/guides/getting-started?id=there-is-no-delta-time), installed `docs/guides/getting-started.md`, “There Is No Delta Time”: documents a simulation loop independent of display refresh at 60 Hz and directly cites Glaiel. This describes the intended engine architecture, not a guarantee that an overloaded Ruby callback completes 60 times per elapsed second.
- Installed `$DRAGONRUBY_HOME/docs/oss/dragon/runtime.rb`, `tick_gtk_engine_before`: increments `Kernel.tick_count` once per engine user tick. `__sdl_tick__` explicitly considers SDL catch-up, but the engine still must execute the project's callback work. Application measurements below establish the observed deficit without modifying engine internals.
- Installed `docs/api/runtime.md`, `current_framerate`: the displayed FPS is an approximation/moving average. Its reciprocal is unsuitable as the simulation clock.
- Installed `docs/oss/dragon/runtime/benchmark.rb`: SDK benchmarks subtract `Time.now` values. No documented public monotonic clock was found in the installed API or samples. The project handles backward/large wall-clock jumps explicitly rather than claiming monotonicity.
- Installed `docs/oss/dragon/recording.rb`: input records contain `Kernel.tick_count`; playback groups input by recorded engine ticks. Neither elapsed time nor application catch-up counts are recorded. Replaying those inputs against fresh wall time is machine/load dependent. Exact catch-up replay requires a separate schedule or simulation-tick input recording, deferred here.
- Installed `docs/oss/dragon/numeric.rb`: elapsed-time and animation helpers default to engine ticks but accept explicit overrides. Future gameplay must supply application ticks rather than accidentally mixing clocks.

## Callback-throughput experiment

Ran `bin/rake run -- --eval tests/timing_playback.rb`. The probe patched the real player update in that process, holds right movement, and exercises diagnostics off/on with natural pacing and a minimum 20 ms callback duration. The limit produced **at most** 50 callbacks/s; rendering/host overhead can lower throughput further. Each case warms up for one second and measures approximately three seconds. It reports callback/update throughput, player-update cost, other preparation cost, and discarded time. Player eventually reaches collision; these are room-loop throughput measurements, not proof of uninterrupted visual walking quality.

Linux offscreen OpenGL with software rendering, HD off, 1024 × 576 window:

| Diagnostics | Minimum callback duration | Before callbacks/s | Before updates/s | After callbacks/s | After updates/s |
| --- | --- | --- | --- | --- | --- |
| Off | Natural | 58.86 | 58.86 | 58.07 | 60.06 |
| On | Natural | 54.05 | 54.05 | 59.75 | 60.08 |
| Off | 20 ms | 38.89 | 38.89 | 44.82 | 59.98 |
| On | 20 ms | 45.04 | 45.04 | 44.72 | 59.96 |

The pre-change loop performed one update per callback and lost simulation time. The changed loop maintained approximately 60 gameplay updates/s despite lower callback throughput, with zero discarded time in all four cases. Short measurement windows have fractional-step boundary error. Host variance means the callback-rate differences do **not** establish a rendering-speed improvement. After-change player updates averaged 0.031–0.035 ms; other preparation averaged 10.864–11.893 ms. These timings exclude native drawing after Ruby returns and are not a GPU profile.

## Verification boundaries

Native tests cover elapsed-time conservation across regular/irregular callback schedules, fixed-step gameplay/animation equivalence, overload accounting, discontinuities, queued pressed inputs, held-input release, catch-up interaction, shared presentation coordinates, camera clamping, repeated rendering, respawn/teleport, and reload failure/recovery. Existing lighting/cache/target-order and collision regressions remain in the suite.

Human playtesting remains necessary: walk diagonally and along walls, cross camera clamp boundaries, toggle the lamp, open doors while moving, and watch foreground fades with diagnostics off/on. Compare normal play with the timing probe's deliberate load. Check for relative player/lamp jitter, wall clipping, delayed interaction feel, and smooth recovery after dragging the window or pausing in the debugger. No automated check establishes motion quality on the player's display.

## Residual jitter playtest: iteration 1

Further user testing still found occasional diagonal jitter, substantially reduced. The first experiment addresses disagreement between artwork rounding and moving lighting geometry. Previously, all consumers shared a fractional interpolated position, but only the artwork and camera rounded it. A native regression reproduced drawn feet at `(160, 90)` while their receiving base followed `(160.1414, 90.1414)` in the same frame.

The trial aligned the interpolated presentation anchor with the camera's existing native-raster rule before preparing player artwork, camera follow, depth, fading, lamp/receiver geometry, and diagnostics. Simulation positions and interpolation history remained fractional. Triangle vertices stayed fractional: this changed the source geometry before solving lighting, rather than repeating the unsuccessful triangle-vertex rounding experiment. HD, sampling, pass order, physics, and frame scheduling stayed unchanged.

A deterministic diagonal regression checked that the rendered feet, lamp, receiver, and presented camera position stayed aligned across irregular callback times, while simulation coordinates retained their fractions. All 186 native tests and RuboCop passed, but the user reported that the trial did not fix the jitter. The implementation and its policy-specific test changes were reverted; the shared fractional interpolation anchor is restored. This result does not identify the remaining cause.

Subsequent trials use one hypothesis at a time against the restored baseline. Revert unsuccessful trials before testing another suspect; retain a partial improvement only when its benefit is demonstrated, then compare the next change with that improved baseline. Previously established corrections, including render-pass ordering and fixed-step simulation/interpolation, remain in place. Test combinations explicitly only if separate results suggest an interaction.

## Residual jitter playtest: iteration 2

The user clarified that the whole background/viewport appears to shake. The next trial tests independent-axis raster snapping: at regular diagonal travel with different fractional X/Y positions, the existing drawing translation alternates between steps such as `(-1, 0)`, `(-1, -1)`, and `(0, -1)`. The world never needs to reverse for that staircase to appear uneven.

Render now requests `Camera#for_drawing(snap: false)`. This snapshot translates both the camera and artwork fractionally, with the same translation for lighting, diagnostics, inverse conversion, and culling. The default snapped path stays available during the experiment. This revisits ADR-0001's snapping policy under the user's authorization to test individual suspects; it is not yet an accepted replacement. Unlike the historical HD-off test that removed only artwork rounding, this also removes camera rounding. HD remains off; pixel-art sampling, the scene target, render-pass dependency order, gameplay, interpolation, and lighting rules are unchanged. Iteration 1's rounded-anchor change remains reverted.

The new scene regression first failed against the baseline's rounded background position. Native coverage now checks equal diagonal translation on both axes in all four directions, a stable followed-player anchor, adjacent tiles, reversible conversion, fractional viewport culling, and independent drawing snapshots. All 188 native tests and RuboCop pass. A temporary ignored offscreen renderer probe generated snapped/fractional captures for five offsets in the normal lit room. Its submitted background deltas changed from the staircase above to approximately `(-0.707107, -0.707107)` every sampled frame. One capture pair was inspected; these coordinates and static images do not establish smoothness on the user's display.

The user reported that this completely solved the camera jitter, but reintroduced sub-pixel tearing and apparent per-tile jitter in pedestals, mounted candles, and the inner borders of top-down/non-occluding walls. Retain the demonstrated benefit of fractional camera motion while investigating the scenery sampling regressions. This is a partial success, not acceptance of the complete rendering configuration.

## Residual jitter playtest: iteration 3

The reported scenery has integer world placement. Rounding those world coordinates again would not fix fractional sampling caused by camera translation. An actual renderer probe using a 544×544 atlas with a contrasting neighboring cell reproduced seams and atlas bleed while drawing four adjacent tiles at fractional screen positions.

The preview now opts into `Render.draw(compose_scroll: true)`. The drawing camera floors its raster position and extends coverage by one raster pixel on the right and top. Static scenery is sampled onto that aligned grid before the fractional camera remainder shifts the composed image. At HD-off this uses 321×181 targets for the 320×180 view, retaining the same world framing and preventing uncovered viewport edges. Lighting uses the same scene camera, with its mask/lightmap producers still accessed before scene consumers.

A first prototype filtered actors inside that image too. A rendered actor-centroid probe caught nearly one pixel of unintended movement across fractional offsets despite numerically centered coordinates. The revised trial splits scenery runs at visible actor positions in the existing depth order, draws each actor directly once between those runs, then draws the later scenery above it. This also preserves ordering for multiple actors, mounted artwork, ceiling pieces, fading, and tinting. Diagnostics are appended to the last scenery run and HUD stays last. The actor references already supplied in `fade_actors` identify these positions; consumers opting into composition must supply those references for actors they want presented directly.

The original fractional path remains available with `compose_scroll: false`, and iteration 1 remains reverted. HD-off, pixel-art sampling, gameplay, interpolation, raycasting rules, and source art are unchanged. This remains a playtest experiment against the historical snapping/output-path decisions, rather than an accepted ADR replacement.

Verification:

- All 192 native tests and RuboCop pass. New checks cover padded viewport coverage across negative and positive coordinates, composed tile alignment, unchanged fractional screen motion, direct actor placement, multiple-actor depth interleaving, lightmap dimensions, and producer-before-consumer target access.
- Across 16 actual renderer offsets, the probe's interior seam count fell from 1,418 pixels to zero, and contrasting-neighbor contamination fell from 1,652 pixels to zero. These are totals over the captures of a deliberately constructed four-tile patch, not counts from the whole game. The directly drawn actor's measured centroid remained constant at every offset.
- Normal lit-room capture pairs cover the pedestals and mounted-light area; selected captures were inspected. They do not establish temporal smoothness on the user's display.
- Short sequential Linux/offscreen software-rendered room playback observed Ruby preparation medians of 12.81 → 11.33 ms at 640×360 and 11.35 → 11.47 ms at 1920×1080, comparing direct fractional drawing with composition. These measurements do not establish a hardware FPS improvement; the added scenery targets still need the user's performance check.

The user subsequently confirmed that this iteration seemingly fixes diagonal jitter completely. The implementation stays in place while comparing it with DragonRuby community advice to move in discrete steps every two or three frames while animation continues normally. No alternative movement policy has been implemented or playtested here. Skipping movement ticks alone would retain fractional diagonal increments; a deliberately integer-step version would also need a speed/cadence policy and a decision about position/camera interpolation.
