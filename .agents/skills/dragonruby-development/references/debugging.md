# Debugging

Use this reference for failures, incorrect behavior, and performance investigation.

## Diagnose from evidence

1. Reproduce the smallest failing scenario and record the exact input, initial state, and observed result.
2. Inspect runtime output and `$DRAGONRUBY_HOME/logs/` (Rake launches from the SDK directory). Also inspect any game-local error output under `mygame/`; use the paths reported by the runtime rather than assuming repository-root logs.
3. Reduce the problem to input, simulation/state, geometry, rendering, asset data, or engine integration.
4. Add temporary observability where hidden state changes: logs, labels, debug primitives, state names, paths, detection areas, evidence weights, or random seeds.
5. Form one testable hypothesis and run the narrowest check that can disprove it.
6. Fix the cause and add a regression test when the behavior is deterministic.

Useful local references include:

- `$DRAGONRUBY_HOME/samples/10_advanced_debugging/00_logging/`
- `$DRAGONRUBY_HOME/docs/samples/advanced-debugging.md`
- developer support functions in `$DRAGONRUBY_HOME/docs/api/runtime.md`
- `$DRAGONRUBY_HOME/docs/samples/performance.md` and `$DRAGONRUBY_HOME/samples/09_performance/`

Use replay or seeded state when a bug depends on a frame sequence. For AI behavior, expose the current state, last observation, target, and reason for a transition rather than inferring them from sprite movement.

For performance work, establish a baseline with DragonRuby diagnostics or benchmarks and test representative entity counts. Do not replace readable code based on an unmeasured micro-optimization.

Remove noisy temporary instrumentation after diagnosis or retain it behind a deliberate debug toggle when it will materially help tuning.

## Current room preview

Inspect `args.state.room_preview` for the current room, player, camera, exported source, and `reload_error`. Development reload compares JSON contents every 30 ticks; successful rebuilds reset player/door state to authored defaults. R forces a rebuild, and B shows colliders and light-emitter markers. A saved TMJ alone does not update runtime data: re-export its JSON.

For room-data faults, follow [tiled-json-audit](../../tiled-json-audit/SKILL.md). For overlap or seams, distinguish active collision, depth/mounting, atlas crop, and camera/raster placement before changing geometry. Current rendering uses one scene target with metadata sampling; F3/F4 are no longer controls. Review [ADR-0001](../../../../docs/adr/0001-viewport-sized-camera.md) for tested approaches and failed experiments before repeating them.

Static or automated renderer checks do not replace a player's enlarged-window/diagonal-movement playtest. When the user is comparing configurations, change one agreed setup at a time and give a short test scenario.
