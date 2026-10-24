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

## Current room and drawing workflow

Use the current [runtime decision](../../../../docs/adr/0005-render-data-and-room-preview.md) and inspect implementation before changing ownership:

- `TiledDeserializer` is a stateless module returning keyword hashes for Room; it owns format validation and coordinate/asset decoding.
- Room currently holds room data, active door state/collision, and render-data production. Render consumes plain frame hashes and owns sorting, camera conversion, target submission, and compositing.
- Keybinds translates physical keys to semantic actions. Player processes player actions; RoomPreview handles preview actions and reload lifetime.
- RoomPreview is a discrete development aid. A future map consumer can reuse room resources and frame data; map assembly and multiplayer are not implemented.

Author scenery and geometry through Tiled. See the [authoring workflow](../../../../README.md#author-and-preview-rooms-in-tiled) for current layers/classes. The former TiledRoom/RoomScene, symbolic atlas catalog, Prop overrides, and collision playground have been removed.

Follow the current [display and sampling decision](../../../../docs/adr/0013-keep-hd-disabled.md): keep `hd=false` and the native 320 × 180 raster. Tune UI fonts, sizes, and layout within that raster. Scene presentation uses metadata `scale_quality=0`; the renderer applies `scale_quality_enum: 3` only when downsizing source artwork. Preserve the current camera/artwork drawing alignment and precise movement/collision state. Do not round simulation state or restore the removed F3/F4 comparison switches as a default.

The installed DragonRuby 7.21 differs from desktop Ruby in verified ways: private module helpers use `class << self` with `private`; dynamic key queries use `send`; `Hash#to_h` ignores transformation blocks, so transform hashes with explicit iteration. Key-held excludes the initial press; movement/sneak use `key_down_or_held?`. Confirm compatibility in native tests rather than assuming desktop Ruby results establish runtime behavior.
