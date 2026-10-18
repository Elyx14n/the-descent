---
status: accepted
date: 2026-10-19
---

# Fixed-step simulation with interpolated drawing

The current room loses gameplay time when the Ruby callback cannot sustain 60 Hz. An offscreen playback measured 54.05 updates/s with diagnostics and 38.89–45.04 under deliberate load. DragonRuby's documented separation from display refresh does not remove this callback-throughput limit. Keep gameplay quantities per fixed 1/60-second step, schedule catch-up updates from elapsed time, and prepare/draw one frame per callback. See the [research and measurements](../notes/decoupled-rendering.md).

`SimulationClock` owns the application simulation tick and fractional remainder. Integer microsecond timestamps contribute `elapsed_us * 60` units; one update consumes 1,000,000 units. `Time.now` is supported by the installed SDK but is not a guaranteed monotonic clock. Backward changes and gaps of at least 250 ms discard the interval and collapse position history. Shorter gaps run at most eight updates; excess whole updates are discarded and counted, while the fractional remainder survives. Successful reloads rebase after loading, clear pending actions/history, and retain the session simulation tick. Engine reset starts a new clock.

`RoomPreview` reads input and handles development controls once per callback, runs fixed gameplay updates, then prepares lighting and renders once. Held movement/sneak use the latest sample on each due step. Ordered batches of interaction/lamp presses wait for a due step, with at most one batch consumed per step. Each batch preserves interaction before movement and lamp processing. Reload clears pending gameplay input; an invalid export retains the valid world and input. Export polling uses elapsed 500 ms intervals instead of engine ticks.

Only player position is interpolated between the last two simulation states. One presented anchor supplies artwork, depth, fade geometry, lighting receiver bases, lamp origin, and diagnostics; a drawing-camera copy follows it before existing clamping/snapping. Spawn, respawn/reset (including same-position reset), direct position changes, reload, and clock discontinuities collapse history. Facing, sprite frames, and door/light enabled states use current discrete state. Foreground fading uses fractional presentation time instead of engine callback count. This adds approximately one fixed step of visual latency, accepted in exchange for smooth pacing. HD remains disabled under [ADR-0013](0013-keep-hd-disabled.md).

Native DragonRuby input recordings are indexed by engine ticks and cannot faithfully replay elapsed-time catch-up without an additional timing trace. This implementation uses injected timestamps/action traces for deterministic regressions; exact live-session recording is deferred. Do not use native slow motion, replay speed, or engine tick counts as the application gameplay clock. New gameplay timers must use the application simulation tick.

This refines [ADR-0005](0005-render-data-and-room-preview.md)'s preview lifecycle and time ownership; Room's clock-free animation interface and Render's plain frame-hash interface remain. Variable-size physics steps, SDK edits, extra threads, native timing extensions, and increased simulation frequency are unnecessary for this slice. Catch-up requires spare simulation capacity and cannot solve sustained overload below the safety budget.
