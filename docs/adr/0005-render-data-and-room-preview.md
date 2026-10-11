---
status: accepted
date: 2026-10-12
---

# Separate room data, rendering, input, and preview lifetime

The Tiled integration combined input translation, door interaction, loading, ordering, and output submission in the room scene. Use a stateless deserializer, a runtime Room, a centralized renderer consuming plain hashes, and a single-room preview consumer. This keeps the authoring loop practical while giving a future map consumer the same drawing interface without building map assembly now.

## Responsibilities

| Module | Owns |
| --- | --- |
| `TiledDeserializer` | Validate and decode Tiled JSON into keyword data for `Room.new`; resolve coordinates, crops, collision, and authored references |
| `Room` | Room state, active door collision/artwork, nearby-door interaction, and room render data |
| `Player` | Process semantic player actions, request room interaction, move, and advance animation |
| `Keybinds` | Physical key assignments, held/pressed semantics, action hashes, and controls hints |
| `Render` | Stable depth ordering, culling, camera conversion, targets, diagnostics submission, and HUD submission |
| `RoomPreview` | Select and reload one exported room, route actions, follow the player, and assemble frame data |

The deserializer is a module with private helpers and an explicit per-call context hash. It constructs no Room and retains no mutable module state. `load(gtk, path:)` reads/parses an export; `deserialize(data, path:)` accepts parsed JSON. Both return the keyword data consumed by Room. Room applies the initial door state once, after the deserializer associates bases with ceiling pieces.

Keep Door, Light, and Pedestal data concrete. On 2026-10-12 the user replaced the Tiled Interactable marker with Pedestal and deferred a shared interaction parent or wrapper until mechanics demonstrate a need. `room.pedestals` references the same hashes as room scenery; `item_position` is the world-space placement anchor decoded from source-pixel `offset_x`/`offset_y`. This imports the metadata without implementing item placement or adding another object identity. The gameplay requirement lives in [PRODUCT.md](../../PRODUCT.md).

## Development preview and map reuse

`RoomPreview` is a development aid for authoring and testing one discrete room. It currently serves as the entry point while the game is being built; its single player, room-sized camera bounds, source polling, and reset-on-reload lifetime do not define the eventual map or game session.

The Tiled assets, deserializer, Room rules/data, and render-data interface are reusable foundations. In the preview, coordinates relative to the loaded room's origin also serve as world coordinates. Multi-room placement has not been implemented: an assembled map must put artwork, sorting depths, collision, emitters, pedestal anchors, and relevant spawn positions into a consistent map coordinate space. Tiled object IDs are local to each export, so cross-room references need room identity as well as object identity.

Render accepts arbitrary actor groups and does not require a single room or player. A map consumer can combine floor collections, combine scenery and actor groups for one shared depth sort, and combine overhead collections before drawing. Rendering each room as a complete floor/scenery/ceiling sequence would lose that shared ordering. The current output path supplies one full-canvas camera view and one `:scene` target; separate player views would require changes to viewport placement and target ownership.

These are current capabilities and limits, not an implemented map contract. The next map prototype should connect two rooms with one passage to exercise placement, continuous movement/collision, and consistent drawing before generalizing assembly. Multiplayer remains outside the current [MVP](../../PRODUCT.md); any future two-player design must also settle controls, camera behavior, and shared interaction rules, including checking both players before closing a door.

## Render-data interface

`Render.draw(args, frame:, camera:)` consumes ordinary hashes. The DTO is the data passed to Render, rather than a separate DTO class. Render reads no Room, Player, input, or gameplay state and does not mutate its input collections or primitives.

| Frame field | Meaning |
| --- | --- |
| `floor` | World-space sprites drawn first, including Ground and FloorDetails |
| `groups` | Hashes with `depth` and `sprites`; world-space groups sorted by descending ground Y, preserving insertion order on ties |
| `ceiling` | World-space sprites drawn after the sorted groups |
| `world_borders` | World-space diagnostic border primitives |
| `world_markers` | World-space diagnostic sprites, such as light-emitter markers |
| `hud` | Screen-space primitives submitted above the scene |

Omitted collections behave as empty arrays. Room returns fresh floor/group/ceiling collections containing its current artwork; Player returns one depth group. A mounted prop remains inside its supporting wall's group. The consumer appends actor groups and diagnostic/HUD primitives. With no valid room yet, a nil camera allows HUD-only rendering.

Render owns the viewport-sized `:scene` target and always draws its compositing sprite to the screen. The temporary F3/F4 diagnostics were removed on 2026-10-12; sprite and scene-texture sampling inherit game metadata without per-primitive overrides. Camera retains following, clamping, visibility queries, and the tested coordinate/snapping calculations. The accepted HD, pixel-art sampling, and native-raster alignment in [ADR-0001](0001-viewport-sized-camera.md) and [ADR-0002](0002-reference-resolution-and-ui-fonts.md) remain in force.

## Input and authoring lifecycle

`Keybinds.read(keyboard)` returns separate `player` and `preview` action hashes. Movement uses WASD only, and key labels use `capitalize` consistently. Movement and sneak include both the initial press and held frames; lamp, interaction, reload, and the collision-overlay toggle fire on key-down only. Opposing directions cancel. Player processes interaction before movement and advances animation afterward. Room chooses the nearby door, rejects interaction when its merged authored `locked` property is true, and rejects a transition whose resulting collider overlaps the player's feet. Check the lock after selecting the nearest door, so a locked target cannot redirect E to another nearby door. An absent lock property defaults to false; placed-object properties override tile defaults. `set_door_open` remains explicit programmatic state control, separate from player interaction.

The development preview compares exported JSON contents every 30 ticks and parses only changed contents. Content comparison catches same-size edits and avoids dependence on filesystem timestamp precision. A successful reload replaces the room, player, and camera together and resets authored door states and Spawn. The B collision-overlay toggle survives. R forces a rebuild even when contents are unchanged; automatic polling is disabled in production.

A failed rebuild retains the last valid room and exposes an error in the HUD and `args.state.room_preview[:reload_error]`. Unchanged failed contents are not repeatedly parsed; a changed export or R retries loading. Gameplay and rendering exceptions are outside the reload guard. Ruby configuration changes can still require R to rebuild persistent instances.

## Consequences and verification

This adds explicit render data and action translation in exchange for keeping Tiled details, gameplay behavior, and DragonRuby output submission local to their owning modules. It introduces no scene framework, event bus, DTO class, map assembly, or rendering optimization.

Native tests cover independent deserialization, active door variants, state-transition overlap protection, mounted groups, stable ordering, camera placement, pressed/held inputs, reload resets, unchanged contents, malformed/missing exports, recovery, and production polling. Movement feel and enlarged-window appearance still require manual playtesting after structural changes.

The installed 7.21 runtime requires `class << self` with `private` for private module helpers, and `send` for dynamic key queries. `private_class_method` and `public_send` are unavailable, and `Hash#to_h` ignores transformation blocks; use explicit iteration when transforming a Hash. These differences were verified by the native tests during this refactor.

Implementation: [deserializer](../../mygame/app/tiled_deserializer.rb), [room](../../mygame/app/room.rb), [player](../../mygame/app/player.rb), [keybinds](../../mygame/app/keybinds.rb), [renderer](../../mygame/app/render.rb), and [preview](../../mygame/app/room_preview.rb). Local SDK references: `$DRAGONRUBY_HOME/docs/api/runtime.md` (`read_file`, `parse_json`, and production detection), `$DRAGONRUBY_HOME/docs/api/inputs.md`, and `$DRAGONRUBY_HOME/docs/oss/dragon/keyboard.rb` (dynamic key queries).
