# The Descent — Current Context

## Implemented

- TiledDeserializer normalizes placed classes, tile classes, and layer defaults into mandatory scenery `type` symbols. Room/rendering consume those types instead of runtime `kind`/`layer` fields. Invalid classes or placements fail at import; existing unclassified environment tiles require no migration. See the [type contract](docs/adr/0005-render-data-and-room-preview.md#normalized-scenery-types).
- Actor-relative foreground fading reveals the player behind nearby Walls, Doors, and Ceiling artwork. A unit's base must be south of the actor's feet, draw after the actor, and cross its vertical center line; artwork must intersect that line within the visible body height. Geometry associates local base/cap columns; the distance target ranges from full opacity at 32 world pixels to 20% at contact for walls/standalone ceiling pieces and 50% for doors; associated artwork shares its base's setting. The preview keeps opacity history, fading out over at most 16 ticks and back in over at most 32 ticks, including when eligibility ends. Player and Enemy share actor render data; the preview still contains only the player. B shows fade footprints in blue. See the [render interface](docs/adr/0005-render-data-and-room-preview.md#render-data-interface) and [research/playtest notes](docs/notes/foreground-fading.md).
- Confirmed rendering configuration: HD on (`hd=true`), pixel-art sampling (`scale_quality=3`), and camera/artwork rounding through `to_draw_space`. After the HD-off comparisons, the user restored HD and reported no camera/player jitter or visible gaps, atlas bleed, or tile seams. This is the accepted configuration; the comparison is complete.
- Playtest 1 result: HD off with pixel-art sampling and existing camera/artwork rounding produced no visible sub-pixel gaps, atlas bleed, or tile seams. The user reported occasional very mild diagonal camera jitter. Text readability was not reported.
- Playtest 2 result: HD off with pixel-art sampling and camera rounding, but screen-space-only sprite drawing, kept the floor free of seams. The user reported player-sprite jitter and occasional severe blur/low fidelity. Removing artwork rounding therefore did not meet the player's visual-quality requirement, even though floor tiles stayed clean.
- The entry point loads the Tiled-authored Ritual Gate room from `mygame/tiled/ritual_gate.json`. Walking, sneaking, lamp toggling, authored collision, depth sorting, overhead artwork, and camera scrolling work in this room. The six-room arrangement, puzzle, and Witness remain unimplemented.
- Player animation sheets use 64 × 64 frames. Idle/walk animation has lamp variants; toggling the lamp preserves playback progress. Death plays once, and controls are disabled until respawn. See [player sprite tests](mygame/tests/player_sprite_test.rb).
- Stateless Tiled deserialization produces normalized room data; Room owns door state, collision, and render-data production. Render consumes plain frame hashes. Keybinds translates physical keys into actions processed by Player and RoomPreview. See [ADR-0005](docs/adr/0005-render-data-and-room-preview.md).
- The player starts at the point object of class `Spawn`. Nearby unlocked doors toggle with E; a targeted door with `locked: true` rejects interaction. The north door (object 218) is the locked Ritual Gate. Bases own their ceiling pieces and collision follows the active base tile's rectangles, including open door leaves. B shows colliders and light emitters.
- RoomPreview polls exported JSON every 30 ticks in development. Successful reloads reset gameplay to authored defaults and preserve the B collision-overlay toggle; R forces a rebuild. Invalid exports retain the last valid room, with errors at `args.state.room_preview[:reload_error]`. See the [authoring workflow](README.md#author-and-preview-rooms-in-tiled).
- The southern room boundary has been rebuilt in Tiled. The original 8 × 2 player foot collider and collision-derived default sorting remain. The proposed Foreground layer was dropped. Wall-mounted props use Tiled `mounted_on` object references and draw with their supporting walls; these references replace numeric elevation offsets for the two ledge candles.
- Light radius, intensity, and color are preserved as authored defaults for a future lighting system. The four `Pedestal` objects replace the old `Interactable` markers. `room.pedestals` references their existing scenery entries; each has a world-space `item_position` derived from authored source-pixel offsets, scaling, and flips. Item discovery, carrying, placement, puzzle-driven unlocking, and lighting are not implemented.
- The old hand-placed playground, red-tile hazard, Ruby prop overrides, and symbolic tilesheet catalog have been removed. Player death animation and reset remain available for later gameplay.
- Camera and display decisions: [viewport-sized camera](docs/adr/0001-viewport-sized-camera.md) and [reference resolution and UI](docs/adr/0002-reference-resolution-and-ui-fonts.md). Camera and artwork use `Grid.render_scale` to align to the higher-resolution native raster while coordinates remain logical. HD supplies finer drawing steps, independently of its font benefit; movement and collision remain fractional. See [rendering terminology](GLOSSARY.md#rendering).
- Rendering still builds all primitives and sorts all entities before filtering. No bottleneck has been measured; [rendering research](docs/notes/rendering-optimizations.md) records future options.
- The inverse-HD target experiment was reverted after causing widespread sprite wobble in playtesting. The Standard build rejects the runtime `hd_max_scale` control, so no Pro setting was added. The temporary direct/target comparison reported no meaningful difference and has been removed; rendering always composites the scene target.
- Playtesting found that pixel-art sampling substantially reduced enlarged-window lines, with remaining flashes during brief diagonal jumps of the whole room. Display-pixel snapping removed the reproduced atlas edge bleed, passed 64 renderer captures at 4.25× and 5.5× and 62 native tests, and was subsequently confirmed by the user to work perfectly. The temporary sampler toggle has been removed; sampling now inherits game metadata. The investigation and unsuccessful approaches are recorded in [ADR-0001](docs/adr/0001-viewport-sized-camera.md).
- HD was originally enabled only for text fidelity; the completed game playtests now also support retaining its finer scene raster for movement. Isolated HD-off tests and alternative fonts remain evidence about available options, not the selected configuration. [ADR-0002](docs/adr/0002-reference-resolution-and-ui-fonts.md) records the distinction between scene alignment and glyph rendering.
- Two-person team using DragonRuby Standard. A shared SDK release still needs to be agreed.

## Agreed map approach

The current `RoomPreview` is a development aid for discrete room authoring and testing. Its single player, one-room camera bounds, and reload resets are preview assumptions. Tiled resources, the deserializer, Room data/rules, and Render's frame interface remain reusable for the map; see [ADR-0005](docs/adr/0005-render-data-and-room-preview.md#development-preview-and-map-reuse) for the current limits.

The [fixed footprint and approved shortcuts decision](docs/adr/0003-fixed-map-footprint-and-approved-shortcuts.md) is accepted but not implemented. It specifies six initial rooms, standardized footprints and doorway positions, reusable branching passages, and a permanent connected backbone containing a loop. Runs vary compatible room assignments and open two of four or five reserved shortcuts from approved combinations. The Ritual Gate stays at the starting location; other room identities depend on available tileset art.

Tiled is the accepted main room and passage editor; see the [editor decision](docs/adr/0004-tiled-room-authoring.md) and [research](docs/notes/tiled-room-editor.md). The manual authoring implementation has been replaced by a small importer for finite orthogonal JSON exports with embedded tilesets. No backward compatibility with the old recipes is required. The current authoring conventions are described in the [README](README.md#author-and-preview-rooms-in-tiled).

The earlier [research references](docs/notes/room-arrangement-systems.md), including local DragonRuby samples, remain speculative technique references. No external map generator has been adopted.

## Proposed map data boundaries

These are working data boundaries, not an implemented format:

- Keep tile layers, collision, objects, and doorway sockets in templates with local coordinates. Arrangement manifests describe compatible assignments to fixed slots and approved connections.
- Assign ritual-item and clue locations after selecting the arrangement. Validate reachability, sufficient hints, and distribution across routes; keep clue importance independent of a room's artwork.
- Derive walkability, sight lines, and Witness routes from the arrangement and current door states.
- Hand-place the first arrangement. Extend the implemented Tiled room loading with room and passage placement when building that arrangement.

The recommended first map prototype is two rooms connected by one passage, using consistent map coordinates and combining their drawing groups before sorting. It should establish placement, cross-room collision, and room/object identity before expanding to six rooms. This prototype and any multiplayer support remain unimplemented.

## Proposed state models

- **Run:** `at_sealed_gate → exploring → gate_unlocked → gate_opened → run_complete`, with `caught` terminal. Keep required, found, and placed ritual items distinct from revealed clues.
- **Witness:** `patrol → investigate → search → patrol`; a sighting can trigger `pursue`. After losing sight, search from the last confirmed position and consider likely exits or clue-bearing rooms.
- **Memory:** located and timed sounds, confirmed sightings, and visible environmental changes. Keep confirmed locations distinct from inferences; reading an untouched clue need not leave evidence.
- **Player pressure:** lamp state, movement mode, visibility/hiding, and possibly sanity. Sanity's trigger, feedback, and consequence remain unresolved.

## Proposed build order

1. Author the fixed footprint and place the initial six-room configuration; add ritual-item discovery, descriptive hints, and validated item/clue locations.
2. Add located sounds and Witness sight, hearing, pursuit, and search.
3. Add item carrying and pedestal placement, unlock the gate when all four items are placed, and add completion/failure and restart with new item/clue locations.
4. Validate compatible room swaps and approved shortcut combinations within the same footprint after the first loop works. Add sanity only if its playtest-defined consequence earns its place.

## Open questions

- What gameplay consequence makes sanity useful?
- Do environmental sounds suffice, or is a deliberate decoy needed?
- Which hiding places allow escape, and what evidence lets the Witness check them?
- What clue formulations and placement rules keep the puzzle solvable, spread out, and resistant to memorization?
- What carrying limits and item-to-pedestal assignment rules suit the four-item puzzle? Placement order is explicitly unrestricted.
- Which slot layout, template/socket conventions, and approved shortcut combinations make authoring economical and chases readable?
- What audio and visual cues make the Witness's inferences understandable and fair?
