# Tiled as a room editor

Research date: 2026-10-07. **Tiled is adopted as the main room and passage editor** in [ADR-0004](../adr/0004-tiled-room-authoring.md). The user authorizes replacing the manual implementation and changing runtime interfaces to simplify consuming Tiled resources, without backward compatibility. Importer and renderer choices remain open. The implementation suggestions below are based on inspected documentation and code, not a completed integration or editor playtest.

## Finding

Tiled replaces the manual room **authoring format**, while keeping the [accepted fixed-footprint arrangement](../adr/0003-fixed-map-footprint-and-approved-shortcuts.md). It supplies visual painting, reusable patterns, separate artwork/metadata layers, and direct placement of gameplay markers. It does not supply this game's assembly, collision response, pursuit rules, or validation.

The useful boundary is `Tiled room/passage file → validated local template → placed runtime objects`. Keep arrangement manifests and run content separate. These terms follow [the glossary](../../GLOSSARY.md); the scope remains [PRODUCT.md](../../PRODUCT.md).

## What exists and what could change

The current floor compiler is standalone: [room.rb](../../mygame/app/room.rb) constructs a completely filled rectangular array from default/border/stamp data; [rooms.rb](../../mygame/app/rooms.rb) defines the Ritual Gate and its numeric stamp. It is covered by [room tests](../../mygame/tests/room_test.rb), but not connected to gameplay rendering. The active [collision playground](../../mygame/app/collision_playground.rb) still has separate hand-placed walls, props, bounds, and spawn data. These are observations from the repository, not Tiled capabilities.

| Treatment during integration | Current item | Proposed replacement or retained responsibility |
| --- | --- | --- |
| Remove/change | `Rooms::FLOOR_STAMPS`, the authored `Rooms::RITUAL_GATE` floor recipe and metadata | Paint the Ritual Gate and author its dimensions/openings in Tiled. A small template ID/file registry may remain. |
| Remove | `Room#build_floor_tiles`, `#apply_borders`, `#apply_stamp`, authoring-only `#normalize_tile` | Read resolved tile-layer data. Fill, borders, and patterns become editor work. Avoid maintaining two authoring systems. |
| Keep/change | `Room` identity, dimensions, exits, walls, props | Keep a small local runtime/template record if useful. Accept imported floors and empty cells; extract sockets and collision. Class shape is an implementation choice. |
| Keep/change | Dimension and tile validation; room tests | Preserve useful invariants. Replace stamp-parser tests with import, coordinate, empty-cell, socket, and collision regressions. |
| Keep/change | `Tilesheet` artwork and semantic names | Reuse the artwork. Replace the catalog or crop API where consuming Tiled tileset data is simpler; semantic names need only remain where gameplay uses them. |
| Keep/change | `Prop.spawn`, `PROP_OVERRIDES` | Continue producing runtime entities. Initially use explicit room collision boxes or existing overrides; if collision moves into the shared tileset later, retire duplicate collision definitions. |
| Keep behavior; interfaces may change | Player animation, entity/collider behavior, viewport camera, resolution | Preserve intended gameplay and accepted behavior while simplifying interfaces for Tiled data. See [camera ADR](../adr/0001-viewport-sized-camera.md) and [display ADR](../adr/0002-reference-resolution-and-ui-fonts.md). |
| Change later | Playground placement constants | Replace the selected scene's coordinates with imported room data when a playable room exists. Keep a playground only if it remains useful for tuning. |
| Keep to implement | Fixed slots, compatible assignments, backbone, approved shortcuts, clue assignment | Game-owned assembly and rules, as agreed in ADR-0003. Tiled annotates authored choices; code selects and validates configurations. |

Replacement and deletion of the manual system are authorized. Keep no compatibility layer or parallel authoring path solely to protect the old implementation.

## Different shapes

A finite orthogonal map still has a rectangular bounding grid. Empty tile cells have GID `0`. Therefore an L-shaped room, U-shaped room, alcoves, or a courtyard can occupy selected cells inside that rectangle. This is an inference from the format, not a distinct “L-shaped map” file type. For example, a 10 × 10 bounding grid can contain an L of floor cells with the remaining cells empty. Use Tiled's empty-cell semantics directly. [JSON format](https://doc.mapeditor.org/en/stable/reference/json-map-format/), [GID reference](https://doc.mapeditor.org/en/stable/reference/global-tile-ids/).

For the existing map decision, distinguish **slot footprint** from **walkable interior**. Keep compatible outer dimensions and doorway positions; vary the occupied interior. An L-shaped interior can fit the same slot without changing the arrangement algorithm. It must still connect the required openings and leave enough clearance for the player's collider. A room spanning several slots, interlocking templates, or moving openings freely would change compatibility and placement assumptions; treat that as a later design decision.

Blank artwork is not a movement barrier. The current player checks rectangular obstacles; it does not derive walkability from floor absence. For a lean prototype, author unrotated collision rectangles around irregular boundaries and voids, or deliberately define a blocked-cell layer and compile it to rectangles. Choose one collision authority. Navigation and sight blocking will need explicit semantics when implemented.

Tiled can author polygons and polylines as well as rectangles and points. That gains expressive metadata, but does not implement polygon collision in this game. Axis-aligned rectangles can describe stepped L/U boundaries without adding polygon physics. [Object tools](https://doc.mapeditor.org/en/stable/manual/objects/). The inspected runtime uses `Actor#collision_position` and `Geometry.find_all_intersect_rect`; polygon movement collision is absent.

## What the editor adds

| Gain | Practical use here | Cost/limit |
| --- | --- | --- |
| Tile painting, selection, bucket/shape fill, saved multi-tile stamps | Fill floors, paint borders, copy the ritual pattern, edit irregular outlines with visual feedback. | Saved stamps are painting conveniences; don't confuse them with whole room templates. [Tile editing](https://doc.mapeditor.org/en/stable/manual/editing-tile-layers/). |
| Tile and object layers | Separate floor/decor artwork, interactive props, collision, and marker metadata. Object placement can be off-grid. | The importer must assign runtime meaning to layer names/types; editor order alone does not solve entity depth. [Layers](https://doc.mapeditor.org/en/stable/manual/layers/). |
| Point/rectangle markers | Place doorway sockets, Ritual Gate/player spawn, clue points, eligible Witness starts, hiding places, or sound hazards. | These are proposed game conventions; all selection and gameplay rules remain ours. [Objects](https://doc.mapeditor.org/en/stable/manual/objects/). |
| Typed custom properties and optional classes/enums | Properties such as socket direction/width, compatibility, or prop identity get visible controls; classes can provide consistent property defaults. | Keep a small vocabulary. Classes are metadata, not executable game classes; resolve defaults correctly or require explicit values. [Properties](https://doc.mapeditor.org/en/stable/manual/custom-properties/). |
| Shared tileset collision shapes | Tune a prop's footprint once and preview it wherever used. | Runtime must extract and transform those shapes. Existing prop overrides and tileset collision must not silently disagree. [Tileset editor](https://doc.mapeditor.org/en/stable/manual/editing-tilesets/). |
| Object templates | Reuse a configured interactive prop/marker across files with per-instance overrides. | Native instances reference another file; import must resolve inheritance, or use an embedding export. This is distinct from the game's room/passage template concept. [Templates](https://doc.mapeditor.org/en/stable/manual/using-templates/). |
| Terrain sets / Wang data | Automatically choose compatible floor/wall edge and corner artwork while painting. | Requires appropriate artwork and tileset setup; not a route generator. [Terrains](https://doc.mapeditor.org/en/stable/manual/terrain/). |
| Automapping | Later automate repetitive border/wall decoration through input/output patterns. | Additional rule files and conventions; defer until manual painting is actually repetitive. [Automapping](https://doc.mapeditor.org/en/stable/manual/automapping/). |

Reusable **passage templates** can follow the same one-file convention as rooms, including corners, straight pieces, and junctions. Keep their local sockets and import contract consistent; arrangement placement remains authored. There is no need to author the entire monastery as one map to start.

## DragonRuby integration options

The installed SDK 7.21 docs/guides and samples were searched for Tiled/TMX/TMJ/TSJ integration; no bundled importer example was found. DragonRuby does provide `$gtk.parse_json_file`, documented at `$DRAGONRUBY_HOME/docs/api/runtime.md` and already used by [tilesheet tests](../../mygame/tests/tilesheet_test.rb). That is file parsing, not automatic tile rendering or collision import.

There is an existing alternative to writing the format reader: Tiled's [official framework list](https://doc.mapeditor.org/en/stable/reference/support-for-tmx-maps/#dragonruby-game-toolkit) links [DRTiled](https://github.com/wildfiler/drtiled) and its separate [renderer](https://github.com/vinnydiehl/drtiled-renderer). DRTiled is third-party DragonRuby code, not a bundled SDK feature. Source inspected at commit `96da011bc90724f697c8a1b74fe089591ff2cb7e` identifies version 0.5.1 and reads native TMX through `$gtk.parse_xml_file`. It loads tile/object/image layers and external TSX tilesets; its layer reader accepts CSV encoding and raises for other encodings. No group-layer loading case was present in the inspected map loader. [Map loader](https://github.com/wildfiler/drtiled/blob/96da011bc90724f697c8a1b74fe089591ff2cb7e/lib/tiled/map.rb), [layer reader](https://github.com/wildfiler/drtiled/blob/96da011bc90724f697c8a1b74fe089591ff2cb7e/lib/tiled/layer_data.rb).

| Route | Benefit | Remaining work |
| --- | --- | --- |
| Small `.tmj` reader using native JSON parsing | Supports exactly the room features we consume; fits current small runtime. | Own GID/path/property resolution and validation. |
| DRTiled with `.tmx` / `.tsx`, CSV layer data | Reuses existing DragonRuby parser/data classes. | Verify the selected authoring profile and modern metadata; adapt its data to existing camera, props, and collision. |

Choose the loader and renderer for straightforward consumption of Tiled resources, changing existing runtime interfaces as useful. Preserve accepted camera behavior without requiring a legacy adapter. Neither library was installed or run during this research; this is a credible candidate, not verified drop-in compatibility.

## Lean import contract to consider

My recommendation for a first custom importer is one native JSON map (`.tmj`) per room/passage and a shared external JSON tileset (`.tsj`) referencing the existing PNG. JSON is editable directly in Tiled, so a separate generated export is optional. XML `.tmx`/`.tsx` is equally native, but adds XML handling if no existing importer is selected. [Generic formats](https://doc.mapeditor.org/en/stable/manual/export-generic/).

Start with finite orthogonal maps, the existing 32 × 32 room tile grid, flat tile/object layers, uncompressed numeric arrays, zero offsets, full opacity, and unrotated rectangles/points plus supported tile props. Require explicit marker properties. Defer infinite chunks, base64/compression, group effects, animation, polygon movement collision, object-template inheritance, and advanced blend/parallax behavior. Reject unsupported content with its file/layer/object location; a silently missing wall is a bad failure mode. These are proposed restrictions, not limitations of Tiled. [JSON schema](https://doc.mapeditor.org/en/stable/reference/json-map-format/).

Suggested layers are `floor`, optional flat `decoration`, `props`, `collision`, and `markers`; names are a convention to agree during implementation. Initially use properties only for facts the game consumes. Keep stable room IDs and named socket/marker IDs distinct from editor-assigned numerical object IDs. Use the same import routine for passages. Do not build a generic metadata framework for unimplemented systems.

### Routine format handling

These are implementation reference facts, not adoption trade-offs or compatibility requirements. Handle them directly using Tiled's format; no further decision is needed to preserve old IDs or representations.

- **Tile identity:** Strip all four high flag bits before resolving a GID; `0` means empty. Find the owning tileset by `firstgid`, then subtract `firstgid` to get its local tile ID. Preserve/render supported flip flags, or reject them. [GIDs](https://doc.mapeditor.org/en/stable/reference/global-tile-ids/).
- **External files:** Resolve a map's tileset reference relative to its map file, and the image relative to the tileset file, rather than treating every path as game-root relative. Normalize those to DragonRuby asset paths. Shared atlas columns, tile size, spacing, and margins must match. [TMX fields](https://doc.mapeditor.org/en/stable/reference/tmx-map-format/), [tileset authoring](https://doc.mapeditor.org/en/stable/manual/editing-tilesets/).
- **Coordinates:** Convert Tiled's downward Y into local upward Y once at import. For template pixel height `H`, tile column/row `(c,r)`, tile dimensions `(tw,th)`, ordinary rectangle `(x,y,w,h)`, and point `(x,y)`, use the derived formulas below. Add the placed template's origin afterwards. Tiled rectangles start at the top-left, whereas orthogonal tile objects default to bottom-left alignment; their conversion differs. Explicitly fixing supported alignment is simplest. [Object alignment](https://doc.mapeditor.org/en/stable/manual/objects/), [map fields](https://doc.mapeditor.org/en/stable/reference/tmx-map-format/).

  ```text
  tile bottom-left:     (c * tw, H - (r + 1) * th)
  rectangle bottom-left:(x,      H - y - h)
  point:                (x,      H - y)
  bottom-left tile object anchor: (x, H - y)
  ```

  The tile formula assumes grid-sized artwork and zero offsets; tile objects use their actual artwork dimensions and alignment. Source-image crop coordinates need their own top-to-bottom conversion; the current `Tilesheet.source_rect` already does this for the cathedral atlas.
- **Artwork and depth:** A 32 × 32 map grid does not require all sprites to be 32 × 32. Tiled supports differently sized tile images and offsets; this game's player remains 64 × 64 under ADR-0002. Import tile props with their artwork and ground anchor separately from collision. Convert Tiled placement to the current `Sprite` center-X/bottom-Y/foot-padding convention rather than copying an object's X directly to `Prop.spawn`. Keep tall occluding props in the game's foot-Y entity sort with the player; flattening them into an always-under-player floor layer loses occlusion. [Variable tile size and offsets](https://doc.mapeditor.org/en/stable/reference/tmx-map-format/); current [Sprite](../../mygame/app/sprite.rb), [Prop](../../mygame/app/prop.rb), and playground rendering establish the runtime conventions.

Tiled's Class UI has changed format spelling: current JSON objects use `type` for their class, while other structures use `class`; importer support should target a chosen editor/format version. [JSON reference](https://doc.mapeditor.org/en/stable/reference/json-map-format/). If adding editor classes or object templates, either resolve their defaults/inheritance or use export embedding; displayed inherited values must not be assumed to be explicit instance properties. [Properties](https://doc.mapeditor.org/en/stable/manual/custom-properties/), [templates](https://doc.mapeditor.org/en/stable/manual/using-templates/).

## Workflow and prototype

Keep authored `.tmj` files, shared `.tsj`, image assets, and any agreed `.tiled-project` in version control under `mygame/`; reuse existing artwork rather than copying it. A project file is optional, but stores shared custom types and compatibility settings. Ignore `.tiled-session`, which stores personal editor state. [Projects](https://doc.mapeditor.org/en/stable/manual/projects/).

If direct native JSON or TMX loading works, editor saves are the source of truth. If needing flattened inheritance or a derived format, choose one documented export route and treat outputs as generated. Tiled supports command-line map/tileset exports and options to embed tilesets, detach object templates, and resolve effective object types/properties. This is an available workflow, not a reason to build an export pipeline immediately. [Exporting](https://doc.mapeditor.org/en/stable/manual/export/), [export preferences](https://doc.mapeditor.org/en/stable/manual/preferences/#export-options).

Compile once when loading/reloading a room, keep resulting local data inspectable, and feed existing collision/render paths. File changes outside Ruby code require a deliberate reload/reset mechanism; existing hot-reload identity checks on Ruby constants do not establish automatic reload of external map files.

A small integration trial should author the Ritual Gate in Tiled first, with an opening, spawn, and explicit collision. The old floor recipe and exact artwork layout need not be reproduced. Add an L-shaped test template in compatible bounding dimensions, with blank cells blocked and required sockets reachable. Check imported artwork, collision placement, prop ground anchors, unsupported feature errors, and camera behavior. Assess editor-to-game iteration manually. This exercises irregular shapes without implementing six-room assembly yet.

The editor and replacement direction are accepted in [ADR-0004](../adr/0004-tiled-room-authoring.md). Choosing a JSON importer, an existing TMX library, or exact layer conventions remains implementation work; polygon physics remains separate scope.

Evidence limits: official Tiled documentation and current project source were inspected. No Tiled GUI was opened, no room was converted, and no import/render/playtest was run. The main integration work is an explicit bridge from editor data to this game's existing coordinate, collision, and rendering conventions; its effort has not been measured.
