# The Descent — Current Context

## Implemented

- Movement and collision playground under `mygame/`: walking, sneaking, lamp toggling, blocking props, decorative props, and debug collision outlines. The puzzle, authored map system, and Witness remain unimplemented.
- Player idle/walk animation has lamp variants; toggling the lamp preserves playback progress. Death plays once, and controls are disabled until respawn. See [player sprite tests](mygame/tests/player_sprite_test.rb).
- Staying on the red tile for two continuous seconds kills the player; stepping off cancels the countdown. Respawn follows after two seconds. This is a playground hazard, not the MVP's sanity mechanic.
- Camera and display decisions: [viewport-sized camera](docs/adr/0001-viewport-sized-camera.md) and [reference resolution and UI](docs/adr/0002-reference-resolution-and-ui-fonts.md).
- Rendering still builds all primitives and sorts all entities before filtering. No bottleneck has been measured; [rendering research](docs/notes/rendering-optimizations.md) records future options.
- Two-person team using DragonRuby Standard. A shared SDK release still needs to be agreed.

## Proposed map model

These are working data boundaries, not an implemented format:

- Keep tile layers, collision, objects, and doorway sockets in templates with local coordinates. Arrangement manifests place and orient templates on a shared grid and explicitly connect openings.
- Assign the symbol sequence and clues after selecting the arrangement. Validate reachability, sufficient hints, and distribution across routes; keep clue importance independent of a room's artwork.
- Derive walkability, sight lines, and Witness routes from the arrangement and current door states.
- Hand-place the first arrangement. Choose the authoring format through use; ASCII grids, numeric tile layers, and editor exports remain options.

## Proposed state models

- **Run:** `at_sealed_gate → exploring → gate_opened → run_complete`, with `caught` terminal. Keep the solution separate from revealed clues.
- **Witness:** `patrol → investigate → search → patrol`; a sighting can trigger `pursue`. After losing sight, search from the last confirmed position and consider likely exits or clue-bearing rooms.
- **Memory:** located and timed sounds, confirmed sightings, and visible environmental changes. Keep confirmed locations distinct from inferences; reading an untouched clue need not leave evidence.
- **Player pressure:** lamp state, movement mode, visibility/hiding, and possibly sanity. Sanity's trigger, feedback, and consequence remain unresolved.

## Proposed build order

1. Hand-place an arrangement and add clue interaction, solution generation, and validated clue assignments.
2. Add located sounds and Witness sight, hearing, pursuit, and search.
3. Add gate input, completion/failure, and restart with new clue assignments.
4. Validate further arrangements after the first loop works. Add sanity only if its playtest-defined consequence earns its place.

## Open questions

- What gameplay consequence makes sanity useful?
- Do environmental sounds suffice, or is a deliberate decoy needed?
- Which hiding places allow escape, and what evidence lets the Witness check them?
- What clue formulations and placement rules keep the puzzle solvable, spread out, and resistant to memorization?
- How many arrangements are useful, and which template/socket conventions make authoring economical?
- What audio and visual cues make the Witness's inferences understandable and fair?
