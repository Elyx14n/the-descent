# The Descent — Current Context

## Implemented

- Confirmed rendering configuration: HD on (`hd=true`), pixel-art sampling (`scale_quality=3`), and camera/artwork rounding through `to_draw_space`. After the HD-off comparisons, the user restored HD and reported no camera/player jitter or visible gaps, atlas bleed, or tile seams. This is the accepted configuration; the comparison is complete.
- Playtest 1 result: HD off with pixel-art sampling and existing camera/artwork rounding produced no visible sub-pixel gaps, atlas bleed, or tile seams. The user reported occasional very mild diagonal camera jitter. Text readability was not reported.
- Playtest 2 result: HD off with pixel-art sampling and camera rounding, but screen-space-only sprite drawing, kept the floor free of seams. The user reported player-sprite jitter and occasional severe blur/low fidelity. Removing artwork rounding therefore did not meet the player's visual-quality requirement, even though floor tiles stayed clean.
- The entry point loads the Tiled-authored Ritual Gate room from `mygame/tiled/ritual_gate.json`. Walking, sneaking, lamp toggling, authored collision, depth sorting, overhead artwork, and camera scrolling work in this room. The six-room arrangement, puzzle, and Witness remain unimplemented.
- Player animation sheets use 64 × 64 frames. Idle/walk animation has lamp variants; toggling the lamp preserves playback progress. Death plays once, and controls are disabled until respawn. See [player sprite tests](mygame/tests/player_sprite_test.rb).
- Tiled deserialization produces ordinary sprite hashes, collision rectangles, door state, light emitter positions, and interactable metadata. The player starts at the point object of class `Spawn`. Nearby doors toggle with E; bases own their ceiling pieces and collision follows the active base tile's authored rectangles, including open door leaves. B shows colliders and light emitter positions; R reloads the export and resets the player to Spawn. See the [authoring workflow](README.md#author-and-preview-rooms-in-tiled).
- The southern room boundary has been rebuilt in Tiled. The original 8 × 2 player foot collider and collision-derived default sorting remain. The proposed Foreground layer was dropped. Wall-mounted props use Tiled `mounted_on` object references and draw with their supporting walls; these references replace numeric elevation offsets for the two ledge candles.
- Light radius, intensity, and color are preserved as authored defaults for a future lighting system. Interactable markers are loaded, but clue interactions and lighting are not implemented.
- The old hand-placed playground, red-tile hazard, Ruby prop overrides, and symbolic tilesheet catalog have been removed. Player death animation and reset remain available for later gameplay.
- Camera and display decisions: [viewport-sized camera](docs/adr/0001-viewport-sized-camera.md) and [reference resolution and UI](docs/adr/0002-reference-resolution-and-ui-fonts.md). Camera and artwork use `Grid.render_scale` to align to the higher-resolution native raster while coordinates remain logical. HD supplies finer drawing steps, independently of its font benefit; movement and collision remain fractional. See [rendering terminology](GLOSSARY.md#rendering).
- Rendering still builds all primitives and sorts all entities before filtering. No bottleneck has been measured; [rendering research](docs/notes/rendering-optimizations.md) records future options.
- The inverse-HD target experiment was reverted after causing widespread sprite wobble in playtesting. The Standard build rejects the runtime `hd_max_scale` control, so no Pro setting was added. F3 compares direct rendering with the normal intermediate target; the user reports no meaningful difference.
- Playtesting found that pixel-art sampling substantially reduced enlarged-window lines, with remaining flashes during brief diagonal jumps of the whole room. Display-pixel snapping removed the reproduced atlas edge bleed, passed 64 renderer captures at 4.25× and 5.5× and 62 native tests, and was subsequently confirmed by the user to work perfectly. F4 retains nearest sampling for comparison. The investigation and unsuccessful approaches are recorded in [ADR-0001](docs/adr/0001-viewport-sized-camera.md).
- HD was originally enabled only for text fidelity; the completed game playtests now also support retaining its finer scene raster for movement. Isolated HD-off tests and alternative fonts remain evidence about available options, not the selected configuration. [ADR-0002](docs/adr/0002-reference-resolution-and-ui-fonts.md) records the distinction between scene alignment and glyph rendering.
- Two-person team using DragonRuby Standard. A shared SDK release still needs to be agreed.

## Agreed map approach

The [fixed footprint and approved shortcuts decision](docs/adr/0003-fixed-map-footprint-and-approved-shortcuts.md) is accepted but not implemented. It specifies six initial rooms, standardized footprints and doorway positions, reusable branching passages, and a permanent connected backbone containing a loop. Runs vary compatible room assignments and open two of four or five reserved shortcuts from approved combinations. The Ritual Gate stays at the starting location; other room identities depend on available tileset art.

Tiled is the accepted main room and passage editor; see the [editor decision](docs/adr/0004-tiled-room-authoring.md) and [research](docs/notes/tiled-room-editor.md). The manual authoring implementation has been replaced by a small importer for finite orthogonal JSON exports with embedded tilesets. No backward compatibility with the old recipes is required. The current authoring conventions are described in the [README](README.md#author-and-preview-rooms-in-tiled).

The earlier [research references](docs/notes/room-arrangement-systems.md), including local DragonRuby samples, remain speculative technique references. No external map generator has been adopted.

## Proposed map data boundaries

These are working data boundaries, not an implemented format:

- Keep tile layers, collision, objects, and doorway sockets in templates with local coordinates. Arrangement manifests describe compatible assignments to fixed slots and approved connections.
- Assign the symbol sequence and clues after selecting the arrangement. Validate reachability, sufficient hints, and distribution across routes; keep clue importance independent of a room's artwork.
- Derive walkability, sight lines, and Witness routes from the arrangement and current door states.
- Hand-place the first arrangement. Extend the implemented Tiled room loading with room and passage placement when building that arrangement.

## Proposed state models

- **Run:** `at_sealed_gate → exploring → gate_opened → run_complete`, with `caught` terminal. Keep the solution separate from revealed clues.
- **Witness:** `patrol → investigate → search → patrol`; a sighting can trigger `pursue`. After losing sight, search from the last confirmed position and consider likely exits or clue-bearing rooms.
- **Memory:** located and timed sounds, confirmed sightings, and visible environmental changes. Keep confirmed locations distinct from inferences; reading an untouched clue need not leave evidence.
- **Player pressure:** lamp state, movement mode, visibility/hiding, and possibly sanity. Sanity's trigger, feedback, and consequence remain unresolved.

## Proposed build order

1. Author the fixed footprint and place the initial six-room configuration; add clue interaction, solution generation, and validated clue assignments.
2. Add located sounds and Witness sight, hearing, pursuit, and search.
3. Add gate input, completion/failure, and restart with new clue assignments.
4. Validate compatible room swaps and approved shortcut combinations within the same footprint after the first loop works. Add sanity only if its playtest-defined consequence earns its place.

## Open questions

- What gameplay consequence makes sanity useful?
- Do environmental sounds suffice, or is a deliberate decoy needed?
- Which hiding places allow escape, and what evidence lets the Witness check them?
- What clue formulations and placement rules keep the puzzle solvable, spread out, and resistant to memorization?
- Which slot layout, template/socket conventions, and approved shortcut combinations make authoring economical and chases readable?
- What audio and visual cues make the Witness's inferences understandable and fair?
