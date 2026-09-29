# Debugging

Use this reference for failures, incorrect behavior, and performance investigation.

## Diagnose from evidence

1. Reproduce the smallest failing scenario and record the exact input, initial state, and observed result.
2. Inspect runtime output and `$DRAGONRUBY_HOME/logs/` (the launchers run from the SDK directory). Also inspect any game-local error output under `mygame/`; use the paths reported by the runtime rather than assuming repository-root logs.
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
