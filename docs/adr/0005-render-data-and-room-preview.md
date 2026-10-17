---
status: accepted
date: 2026-10-12
---

# Separate room data, rendering, input, and preview lifetime

The Tiled integration combined input translation, door interaction, loading, ordering, and output submission in the room scene. Use a stateless deserializer, a runtime Room, a centralized renderer consuming plain hashes, and a single-room preview consumer. This keeps the authoring loop practical while giving a future map consumer the same drawing interface without building map assembly now.

## Responsibilities

| Module | Owns |
| --- | --- |
| `TiledDeserializer` | Validate and decode Tiled JSON into keyword data for `Room.new`; normalize scenery types and resolve coordinates, crops, collision, and authored references |
| `Room` | Room state, active door collision/artwork, light enabled state/artwork, nearest door/light interaction, and room render data |
| `Player` | Process semantic player actions, request room interaction, move, and advance animation |
| `Keybinds` | Physical key assignments, held/pressed semantics, action hashes, and controls hints |
| `Render` | Stable depth ordering, culling, camera conversion, targets, diagnostics submission, and HUD submission |
| `RoomPreview` | Select and reload one exported room, route actions, follow the player, and assemble frame data |

The deserializer is a module with private helpers and an explicit per-call context hash. It constructs no Room and retains no mutable module state. `load(gtk, path:)` reads/parses an export and supplies pixel loading; `deserialize(data, path:, image_loader:)` accepts parsed JSON and an explicit image-data dependency. Both return the keyword data consumed by Room. Room applies the initial door state once, after the deserializer associates bases with ceiling pieces. [ADR-0007](0007-alpha-derived-scenery-bounds.md) records the source-local alpha bounds carried by imported sprite hashes.

Keep Door, Light, and Pedestal data concrete. On 2026-10-12 the user replaced the Tiled Interactable marker with Pedestal and deferred a shared interaction parent or wrapper until mechanics demonstrate a need. `room.pedestals` references the same hashes as room scenery; `item_position` is the world-space placement anchor decoded from source-pixel `offset_x`/`offset_y`. This imports the metadata without implementing item placement or adding another object identity. The gameplay requirement lives in [PRODUCT.md](../../PRODUCT.md).

On 2026-10-15, Light artwork and enabled state joined the same concrete scenery entry: `room.lights` retains emitter coordinates and lighting metadata while referencing the object drawn by the room. The deserializer resolves the placed lit tile's Tiled animation and same-tileset static `unlit_id`, precomputing variant sprites and alpha bounds. Light collision and emitter anchors remain fixed from the placed tile, independent of visual state. Runtime `enabled` is authoritative; merged `properties` retain authored defaults.

The preview or future map supplies time through `room.update_animations(tick:)` before interaction and frame assembly. Room has no internal clock or playback progress. Equal whole-tick durations use tick division and modulo (150 ms is nine ticks at 60 Hz); other durations use cumulative authored milliseconds. The selected lit sprite is retained so enabling immediately joins the supplied tick's frame, even after time spent disabled. Variant changes replace the active sprite hash in place, preserving mounted and fade references. `render_data` does not advance animation.

## Normalized scenery types

Every imported scenery entry and sprite has a mandatory symbolic `type`. Resolve it once in `TiledDeserializer.entry_type`: a nonempty placed-object class overrides the tile class, which overrides the layer default. Both current Tiled `class` and legacy `type` source fields are accepted. Reject unknown classes and unsupported class/layer combinations during import. Room and rendering code consume the canonical symbols; legacy runtime `kind` and `layer` fields are removed.

| Tiled layer | Default type | Other allowed types |
| --- | --- | --- |
| Ground | `:ground` | — |
| FloorDetails | `:floor_detail` | — |
| Walls | `:wall` | — |
| Props | `:prop` | `:door`, `:light`, `:pedestal` |
| Ceiling | `:ceiling` | `:door` |

An authored Spawn remains a point marker and supplies the existing spawn coordinates. Door state variants retain `:door`. Authoring classes and layers still determine how exports are validated and assembled inside the deserializer; they are not reinterpreted by runtime consumers. This keeps existing unclassified environment artwork usable without a Tiled migration. New classes/defaults belong in the central deserializer tables.

## Development preview and map reuse

`RoomPreview` is a development aid for authoring and testing one discrete room. It currently serves as the entry point while the game is being built; its single player, room-sized camera bounds, source polling, and reset-on-reload lifetime do not define the eventual map or game session.

The Tiled assets, deserializer, Room rules/data, and render-data interface are reusable foundations. In the preview, coordinates relative to the loaded room's origin also serve as world coordinates. Multi-room placement has not been implemented: an assembled map must put artwork, sorting depths, collision, emitters, pedestal anchors, and relevant spawn positions into a consistent map coordinate space. Tiled object IDs are local to each export, so cross-room references need room identity as well as object identity.

Render accepts arbitrary actor groups and does not require a single room or player. A map consumer can combine floor collections, combine scenery and actor groups for one shared depth sort, and combine overhead collections before drawing. Rendering each room as a complete floor/scenery/ceiling sequence would lose that shared ordering. The current output path supplies one full-canvas camera view and one `:scene` target; separate player views would require changes to viewport placement and target ownership.

These are current capabilities and limits, not an implemented map contract. The next map prototype should connect two rooms with one passage to exercise placement, continuous movement/collision, and consistent drawing before generalizing assembly. Multiplayer remains outside the current [MVP](../../PRODUCT.md); any future two-player design must also settle controls, camera behavior, and shared interaction rules, including checking both players before closing a door.

## Render-data interface

`Render.draw(args, frame:, camera:, fade_state: nil, tick: 0)` consumes ordinary hashes. The DTO is the data passed to Render, rather than a separate DTO class. Render reads no Room, Player, input, or gameplay state and does not mutate its input collections or primitives. The caller may supply a separate mutable opacity-history hash and simulation tick for transitions; omitting that history renders the instantaneous distance target.

| Frame field | Meaning |
| --- | --- |
| `floor` | World-space sprites drawn first, including Ground and FloorDetails |
| `groups` | Hashes with `depth` and `sprites`; world-space groups sorted by descending ground Y, preserving insertion order on ties |
| `ceiling` | World-space sprites drawn after the sorted groups |
| `fade_units` | Hashes with the base's canonical `type`, original supporting `base`, world-space `footprint`, and original `sprites` references; associated base/cap artwork shares opacity |
| `fade_actors` | Hashes with actor ground-anchor `x`, `y`, scaled `occlusion_width` and `occlusion_height`, and an original actor `sprite` reference identifying its final drawing order |
| `world_borders` | World-space diagnostic border primitives |
| `world_markers` | World-space diagnostic sprites, such as light-emitter markers |
| `hud` | Screen-space primitives submitted above the scene |

Omitted collections behave as empty arrays. Room returns fresh floor/group/ceiling/fade-unit collections containing its current artwork; Actor returns one depth group plus `fade_actor`. A mounted prop remains inside its supporting wall's group. The consumer appends actor groups, their fade actor data, and diagnostic/HUD primitives. With no valid room yet, a nil camera allows HUD-only rendering.

[ADR-0009](0009-measured-render-preparation.md) refines collection ownership: outer arrays are fresh, while cached scenery group hashes and their sprite lists are room-owned structural data that consumers must not mutate. Sprite references continue to reflect active variants.

On 2026-10-14, actor-relative foreground fading extended this interface. Room prepares local units with supporting-base and member sprite references plus stable footprint snapshots; Actor supplies live ground coordinates and scaled visible body width and height. After stable sorting, Render delegates to `ForegroundFade`. Keep sprite references shared between drawing collections and fade data when assembling a frame, including any future world translation.

[ADR-0006](0006-simplified-foreground-fading.md) owns the geometry association, spatial curve, and temporal approach rules. It supersedes this ADR's original Euclidean-distance calculation with the equivalent vertical gap for eligible Room-created units. [ADR-0007](0007-alpha-derived-scenery-bounds.md) refines eligibility to reject scenery padding with measured alpha bounds. The preview supplies history in `room_preview[:fade_state]`; omitting history renders the instantaneous target. All on-screen actors independently contribute when supplied, although the current preview contains only Player. Collision, gameplay sight, lighting, and camera behavior remain independent.

Render owns the viewport-sized `:scene` target and always draws its compositing sprite to the screen. The temporary F3/F4 diagnostics were removed on 2026-10-12; sprite and scene-texture sampling inherit game metadata without per-primitive overrides. Camera retains following, clamping, visibility queries, and the tested coordinate/snapping calculations. The accepted HD, pixel-art sampling, and native-raster alignment in [ADR-0001](0001-viewport-sized-camera.md) and [ADR-0002](0002-reference-resolution-and-ui-fonts.md) remain in force.

## Input and authoring lifecycle

`Keybinds.read(keyboard)` returns separate `player` and `preview` action hashes. Movement uses WASD only, and key labels use `capitalize` consistently. Movement and sneak include both the initial press and held frames; lamp, interaction, reload, and the collision-overlay toggle fire on key-down only. Opposing directions cancel. Player processes interaction before movement and advances animation afterward.

`Room#toggle_nearest_interactable(point:, collision_rect:, radius: 24)` chooses one nearest Door or Light, using closed door colliders or the placed light sprite rectangle. Equal distances follow authored object order. Selection is shared across a frozen list of supported types, with explicit door/light dispatch and no parent class or handler framework. A targeted door rejects interaction when its merged authored `locked` property is true or its resulting collider overlaps the player's feet. Check restrictions after selection so a blocked target cannot redirect E. An absent lock property defaults to false; placed-object properties override tile defaults. Lights toggle runtime `enabled` and artwork. `set_door_open(id, open:)` and `set_light_enabled(id, enabled:)` provide explicit programmatic state control and reject unknown IDs.

The development preview compares exported JSON contents every 30 ticks and parses only changed contents. Content comparison catches same-size edits and avoids dependence on filesystem timestamp precision. A successful reload replaces the room, player, and camera together and resets authored door/light states and Spawn. Animation immediately follows the consumer's supplied tick. The B collision-overlay toggle survives. R forces a rebuild even when contents are unchanged; automatic polling is disabled in production.

A failed rebuild retains the last valid room and exposes an error in the HUD and `args.state.room_preview[:reload_error]`. Unchanged failed contents are not repeatedly parsed; a changed export or R retries loading. Gameplay and rendering exceptions are outside the reload guard. Ruby configuration changes can still require R to rebuild persistent instances.

## Consequences and verification

This adds explicit render data and action translation in exchange for keeping Tiled details, gameplay behavior, and DragonRuby output submission local to their owning modules. It introduces no scene framework, event bus, DTO class, map assembly, or rendering optimization.

Subsequent measured rendering optimizations and their trade-offs are recorded in [ADR-0009](0009-measured-render-preparation.md).

Native tests cover independent deserialization, active door variants, light defaults and overrides, animation boundaries and looping, candelabra collision in both enabled states, nearest door/light targeting, state-transition overlap protection, mounted groups, stable ordering, camera placement, pressed/held inputs, reload resets, unchanged contents, malformed/missing exports, recovery, and production polling. Movement feel and enlarged-window appearance still require manual playtesting after structural changes.

The installed 7.21 runtime requires `class << self` with `private` for private module helpers, and `send` for dynamic key queries. `private_class_method` and `public_send` are unavailable, and `Hash#to_h` ignores transformation blocks; use explicit iteration when transforming a Hash. These differences were verified by the native tests during this refactor.

Implementation: [deserializer](../../mygame/app/tiled_deserializer.rb), [room](../../mygame/app/room.rb), [player](../../mygame/app/player.rb), [keybinds](../../mygame/app/keybinds.rb), [renderer](../../mygame/app/render.rb), and [preview](../../mygame/app/room_preview.rb). Local SDK references: `$DRAGONRUBY_HOME/docs/api/runtime.md` (`read_file`, `parse_json`, and production detection), `$DRAGONRUBY_HOME/docs/api/inputs.md`, and `$DRAGONRUBY_HOME/docs/oss/dragon/keyboard.rb` (dynamic key queries).
