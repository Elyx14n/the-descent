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
