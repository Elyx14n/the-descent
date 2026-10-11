# Room scenery and map ownership

Research date: 2026-10-12. This note distinguishes supported architecture patterns from a recommendation for The Descent; it does not establish an industry-wide convention or replace [ADR-0005](../adr/0005-render-data-and-room-preview.md).

## Evidence from official documentation

Tiled explicitly supports splitting a world into multiple authored maps. Its `.world` JSON lists map files and their global pixel positions. The documentation names easier editing and reduced memory usage as reasons to split a world. This establishes separate authoring units plus placement data; it does **not** prescribe the game's runtime ownership or rendering architecture. [Tiled: Working with Worlds](https://doc.mapeditor.org/en/stable/manual/worlds/)

Godot's TileMapLayer holds level tile data and supports collision, navigation, and rendering configuration. Its documentation recommends multiple layers where useful and external TileSet resources shared across levels. Godot therefore supports scenery-bearing runtime nodes, rather than requiring authored levels to become metadata-only objects. [Godot: Using TileMaps](https://docs.godotengine.org/en/stable/tutorials/2d/using_tilemaps.html)

Godot also recommends reusable scenes that do not depend on details of their surrounding context, with the parent initializing necessary external relationships. This supports locally organized content under a coordinating parent. It does not require a class called Room, nor a custom renderer per room. [Godot: Scene organization](https://docs.godotengine.org/en/stable/tutorials/best_practices/scene_organization.html)

The installed DragonRuby 7.21 sample `$DRAGONRUBY_HOME/samples/07_advanced_rendering/16_camera_space_world_space_simple_grid_map/app/main.rb` stores one tile collection, culls it against the camera, and submits transformed sprites to a shared `:scene` target. It demonstrates shared scenery rendering, without establishing multi-room state ownership.

## Recommendation for this project

Separate three decisions: **where content is authored**, **who owns live objects**, and **who draws them**. Rooms can remain discrete Tiled assets while a future Map coordinates their placement and exposes collision, interaction, and drawing data for the whole playable area.

`Room` currently stores scenery and mutable door state and prepares render groups; it performs no camera conversion, culling, depth sort, or output submission. Those operations already belong to `Render`. Describing Room as responsible for its scenery should mean retaining and exposing that content, not running an independent rendering pipeline.

A future Map could retain placed Room instances or instantiate their data into world-owned collections. Both fit a centralized renderer. Choose between them when the first connected-room prototype establishes the useful state and query boundaries. `RoomPreview` remains the one-room development consumer; its current single-room collision and camera assumptions are not a future map contract.
