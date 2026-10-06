# Handcrafted rooms and randomized arrangements

Researched 2026-10-06; decision context updated 2026-10-07. Primary-source code references for reusable handcrafted rooms, an undirected connection graph, and traversable passages in a top-down 2D game. **Tool choices, adaptation ideas, prototype effort rankings, and proposed generator techniques in this note are speculative.** No external generator or local sample tool has been adopted.

The agreed MVP is recorded in [ADR 0003](../adr/0003-fixed-map-footprint-and-approved-shortcuts.md): one fixed footprint with six initial rooms, a permanent connected backbone containing a loop, compatible room swaps, and two active shortcuts selected from approved combinations. Automatic spatial placement, corridor routing, maze generation, and a general layout solver are outside that approach. Use the references below for individual techniques rather than as the MVP implementation plan.

The closest conceptual match is **Edgar**; the clearest editable room-library example is **halftheopposite's BSP generator**; the strongest low-level C example of authored room data is **Angband**. DragonRuby's installed samples supply useful authoring and tile-navigation pieces, but the inspected samples do not provide a complete prefab graph generator.

## Project context

Use the meanings of Room, Passage, room/passage template, doorway socket, and Arrangement in [GLOSSARY.md](../../GLOSSARY.md). The [MVP](../../PRODUCT.md) and [CONTEXT.md](../../CONTEXT.md) follow the accepted fixed-footprint decision. The original research explored broader randomized placement and adjacency options; those remain speculative references. The map system is still unimplemented; the unused [Room class](../../mygame/app/room.rb) does not assemble templates.

[ADR 0001](../adr/0001-viewport-sized-camera.md) and [ADR 0002](../adr/0002-reference-resolution-and-ui-fonts.md) constrain camera/rendering behavior, not this room data model. An authoring or generator reference does not imply adopting its rendering pipeline.

## Comparison

| Reference | Handcrafted room interiors | Connection model | Best use here |
| --- | --- | --- | --- |
| [Edgar-DotNet](https://github.com/OndrejNepozitek/Edgar-DotNet) | Authored outlines and door positions; game supplies interiors | Explicit undirected graph; solver finds geometry | Study template/socket/graph separation |
| [BSP dungeon generator](https://github.com/halftheopposite/bsp-dungeon-generator) | Editable tile/prop/monster layers | Connections follow spatial partition tree | Study small room library and stamping |
| [Angband](https://github.com/angband/angband) | Text layouts, including irregular rooms | Procedural placement and tunnel connection | Study plain data and C template interpreter |
| Installed DragonRuby samples | Editable terrain and authored floor cells | No room assembly generator | Adapt familiar Ruby authoring/navigation pieces |

These are complementary references. None is a small DragonRuby implementation of the entire requested system.

## 1. Edgar: closest match to the graph requirement

Read [BasicsExample.cs](https://github.com/OndrejNepozitek/Edgar-DotNet/blob/master/src/Edgar.Examples/Grid2D/BasicsExample.cs), especially `GetLevelDescription()` and `Run()`. It creates named `RoomTemplateGrid2D` values from an outline, door mode, and allowed transformations; pools templates in a room description; calls `AddRoom` and `AddConnection`; then calls `GenerateLayout`. The example contains both a cycle and a branch. Its comments explain `ManualDoorModeGrid2D` for exact sockets and rotation handling. [Worked source](https://github.com/OndrejNepozitek/Edgar-DotNet/blob/master/src/Edgar.Examples/Grid2D/BasicsExample.cs).

The important distinction is **random layout for a supplied graph**. Randomizing who is connected to whom needs a separate graph-generation step or a choice among graph variants. Templates describe outlines and openings, so The Descent would still need to associate its tiles, collision, props, and clue points with template identities. This is an inference from the input/output boundary in the example.

For actual passages, read [CorridorsExample.cs](https://github.com/OndrejNepozitek/Edgar-DotNet/blob/master/src/Edgar.Examples/Grid2D/CorridorsExample.cs): the author models corridors as additional graph nodes with handmade shapes and opposite sockets. **A significant limitation:** `LevelDescription.GetGraph()` constructs an undirected graph, but `CheckIfValid()` requires every node marked `IsCorridor` to have exactly two non-corridor neighbors. A three-exit Passage would therefore need to be modeled as an ordinary room-shaped node, not an Edgar corridor node. [Graph construction and validation](https://github.com/OndrejNepozitek/Edgar-DotNet/blob/master/src/Edgar/GraphBasedGenerator/Common/LevelDescription.cs).

**Limit:** this is engine-independent C#, not directly loadable Ruby. The documentation warns that some graphs are difficult to lay out and recommends fewer than 30 rooms. It advertises short corridors and an evolving API; borrowing the public data model is a much smaller commitment than porting its solver. [Official introduction](https://ondrejnepozitek.github.io/Edgar-DotNet/docs/introduction/).

## 2. BSP dungeon generator: strongest room-library workflow

The [browser demo](https://halftheopposite.github.io/bsp-dungeon-generator/) includes room editing. Its editor explicitly supports creating, editing, and removing rooms, saving/loading `rooms.json`, and preserving the editing session in local storage. Its generator also exports dungeon JSON. This directly addresses keeping a growing collection of discrete authored spaces. [Project README](https://github.com/halftheopposite/bsp-dungeon-generator).

Read [src/generate/dungeon.ts](https://github.com/halftheopposite/bsp-dungeon-generator/blob/main/src/generate/dungeon.ts): `generateTree` recursively splits space and creates connecting corridors; `fillByType` positions a fitting template in a container; `findFittingTemplate` checks dimensions and prefers unused templates; `carveRooms`, `carveProps`, and `carveMonsters` translate local layer cells into map cells. These are useful, straightforward stamping routines.

**Limits visible in the code:** the topology follows the partition tree, not an arbitrary input graph. The generator has fixed boss/entrance/heal/treasure/monster categories, which conflict with this project's interchangeable clue-bearing rooms if copied unchanged. It has no explicit doorway-socket compatibility model; corridors are carved before room tiles are stamped. Therefore custom interiors require careful connection conventions and tile reachability checks. A missing fitting template can leave a container without a room. [Generator source](https://github.com/halftheopposite/bsp-dungeon-generator/blob/main/src/generate/dungeon.ts).

**Fit:** study its editable layered data and stamping, then keep graph and passage decisions project-specific. The React/Pixi editor is separate from the TypeScript generator; adopting that web stack is optional. [README](https://github.com/halftheopposite/bsp-dungeon-generator).

## 3. Angband: real handcrafted templates in low-level C

Read [lib/gamedata/room_template.txt](https://github.com/angband/angband/blob/master/lib/gamedata/room_template.txt). Rooms are named records with dimensions and `D:` ASCII rows. The file documents the glyphs: `%` marks perimeter where corridors may connect, `+` a fixed door, and numbered cells alternative secret-door sets. It includes irregular outlines such as U-bends and hourglasses. Adding/editing/removing records changes the available collection; changing `type` away from the currently selected value can disable a template. These are full authored cell layouts, not only rectangles. [Template data and its format comments](https://raw.githubusercontent.com/angband/angband/master/lib/gamedata/room_template.txt).

Read [src/gen-room.c](https://github.com/angband/angband/blob/master/src/gen-room.c), narrowly: `random_room_template` selects from the library; `build_room_template_type` selects and invokes a template; `build_room_template` translates glyphs into terrain and objects after a symmetry transform; `append_entrance` records candidate openings. Space reservation can fail. [Room-generation source](https://raw.githubusercontent.com/angband/angband/master/src/gen-room.c).

**Limit:** this is a large, established game's generation subsystem, with many game-specific glyphs and globals. It does not present the requested external room-neighbor graph API. Connection work lives separately in [src/gen-cave.c](https://github.com/angband/angband/blob/master/src/gen-cave.c), including `build_tunnel`; use it as evidence for separating authored interiors from connection construction, not as a small drop-in engine. **Fit:** borrow the human-editable records and local-to-world transformation idea, with much simpler project-owned glyphs and sockets.

## 4. Local DragonRuby: authoring and navigation pieces

Every `SDK:` path below is relative to `DRAGONRUBY_HOME`; see [repository setup](../../README.md#first-time-setup-and-running-the-game). Keep SDK files outside this repository.

These are the local samples referenced in the follow-up discussion. Their source was inspected, but their suitability as this project's room-authoring or validation tools is speculative. None supplies reusable room templates, doorway sockets, or randomized room assembly; using one would require project-specific code. The earlier suggestion that adapting the map editor would be the easiest six-room prototype was an unmeasured effort judgment, not an agreed tool choice.

- `SDK: samples/99_genre_platformer/map_editor/app/level_editor.rb`: `LevelEditor#tick` paints/deletes terrain with camera-to-world conversion; `save_terrain` and `load_terrain` serialize rows containing position, dimensions, sprite path, and collision flag. Although demonstrated in a platformer, tile painting and persistence are useful for top-down room authoring. Adaptation would require local coordinates, separate room files, and socket metadata.
- `SDK: samples/99_genre_rpg_roguelike/02_roguelike_line_of_sight/app/main.rb`: `load_area_one` supplies authored floor cells, `derive_dungeon_from_area` derives dungeon state, `input_click_map` edits cells, and `export_dungeon` prints Ruby statements containing cell coordinates. Useful as a small Ruby map representation; it is one area, without reusable room assembly.
- `SDK: samples/13_path_finding_algorithms/08_a_star/app/main.rb`: `AStar#adjacent_locations`, `tick_solve`, and `path_found?` demonstrate bounded cardinal tile navigation with walls. This can inform traversability checks after assembly; it does not generate room topology.

The map editor's code uses the MIT license; its Kenney assets have their own CC0 notice. Source: `SDK: samples/99_genre_platformer/map_editor/license-for-sample.txt`. Consult the local SDK version when adapting sample APIs.

## Speculative options from the earlier research

The following were exploratory inferences, not accepted requirements. In particular, generating spanning trees or solving placement geometry is outside the agreed MVP. The accepted map approach is owned by [ADR 0003](../adr/0003-fixed-map-footprint-and-approved-shortcuts.md).

1. **A room library independent of arrangements.** Each stable template ID owns local tile/collision/object data and named doorway sockets. Angband demonstrates that plain text can be enough; the BSP editor demonstrates a layered visual workflow. The authoring format can change while the placement boundary stays small.
2. **An explicit undirected graph independent of coordinates.** Maintain room instances and pairwise connections separately from the reusable definitions. A randomized spanning tree provides initial connectivity; selected extra edges provide loops, subject to physical feasibility. Choosing a template also has to satisfy the node's required sockets.
3. **A separate placement step.** A graph does not solve geometry. Rooms can overlap, sockets can face the wrong way, and corridors can accidentally create additional connections. For a first exploration, use a coarse grid with constrained room footprints and known passage pieces, or generate candidate arrangements offline and curate the successes. Edgar illustrates the complexity introduced by arbitrary outlines and prescribed graphs.
4. **Validate the assembled walkable space.** Check template references, overlap, socket alignment, opening widths, and reachability under the game's collision rules. A connected room graph can still stamp an impassable map if an interior wall or prop blocks an entrance. Seed plus template/arrangement identifiers should make failures reproducible and inspectable.

For a conceptual room-only graph, passages can be edges. For actual navigation and placement, a passage with three exits is a space where routes branch: represent that junction as a passage node and its doorway connections as ordinary edges. This preserves undirected traversal without forcing every connector to have exactly two endpoints.

The earlier suggestion of a three-room experiment was illustrative and has been superseded by the agreed six-room scope. Neither that experiment nor a constrained randomized placement generator is an implementation commitment.

## Evidence limits

Source and data were inspected; the external generators were not built or playtested. The local SDK scan found useful component examples, not proof that no complete community DragonRuby generator exists. Weak matches were excluded: randomly carved rectangular rooms alone do not establish handcrafted-template support, and a prefab-placement demo without overlap/reachability handling does not establish a reliable arrangement system. Online links target upstream branches and may move; local sample behavior depends on the SDK installation.
