# Engineering

Use this reference for implementation and refactoring.

## Project boundaries

- Game entry point: `mygame/app/main.rb`.
- Put project Ruby code under `mygame/app/` and require it from the entry point as needed.
- Put runtime assets under the matching `mygame/` directory. Descent sprite assets belong under `mygame/sprites/descent/`.
- Use `$DRAGONRUBY_HOME/docs/api/` for engine APIs and search `$DRAGONRUBY_HOME/samples/` for the smallest relevant example.

## Shape code around demonstrated needs

Begin with a direct implementation. Extract a function, module, or object when it gives at least one concrete benefit: a comprehensible responsibility, deterministic testing, isolated tuning, or reuse that already exists.

Good seams commonly include deterministic puzzle generation, state transitions, Witness observations and decisions, geometry, and collision rules. DragonRuby input collection and output emission can remain thin adapters around such rules. This is a heuristic, not a required layered architecture.

Avoid speculative managers, base classes, registries, component systems, and generic configuration formats. A few explicit hashes, arrays, modules, or small objects are usually easier to tune in a small game.

## Frame-loop care

- Make initialization explicit and safe across resets.
- Distinguish held input from one-frame key events.
- Keep per-frame iteration bounded by actual game scale.
- Avoid filesystem or expensive setup work on every tick.
- Make clocks, random values, and state transitions inspectable when they affect behavior.
- Preserve the logical resolution and coordinate conventions defined by game metadata unless the task changes them.

Use runtime APIs in `$DRAGONRUBY_HOME/docs/api/runtime.md`, state guidance in `$DRAGONRUBY_HOME/docs/api/state.md`, and rendering/input API docs only when relevant.
