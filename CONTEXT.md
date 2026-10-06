# The Descent — Project Context

This file records the **current planning context** for contributors and coding agents. `PRODUCT.md` defines the intended player experience and MVP boundary. Do not infer that a planned system is already implemented.

## Current status

- **Stage:** movement and collision playground implemented under `mygame/`, with player collision tests under `mygame/tests/`. The full puzzle and Witness loop remains planned.
- **Player rendering:** 64 × 64 source frames (512 × 256 sheets) displayed at 3× scale with nearest-neighbor sampling; eight-frame idle/walk animations support lamp on/off. Actor position is the horizontal center of the feet, with a twenty-four-source-pixel bottom-padding offset and a 24 × 6 displayed foot collider. South death animation positions fallen feet on the ground anchor with the head collapsing south into the bottom padding. Native sprite regression tests are in `mygame/tests/player_sprite_test.rb`.
- Lamp toggles preserve animation progress; changes between idle, walk, and death restart the animation cycle.
- Player animation definitions group lamp variants under idle/walk clips and declare whether each clip loops. `Actor` owns the selected clip and its clock; the playground advances playback once after movement, hazard, and respawn updates so death renders from its first frame immediately. Rendering does not advance playback.
- Staying on the playground's red tile for two continuous seconds (120 ticks) kills the player; stepping off cancels the danger countdown. Death plays once and holds its final frame until the two-second respawn countdown completes. The existing player instance resets at `(400, 180)` with full sanity, lamp on, and a fresh idle animation; controls are disabled during death.
- **Team:** a small amateur group; keep the first build lean and understandable to nontechnical collaborators.
- **Engine:** DragonRuby Standard, installed outside the repository for each developer's OS. `DRAGONRUBY_HOME` selects the complete SDK; `scripts/run.sh` and `scripts/run.ps1` launch this repository's `mygame/`. See `README.md` for setup. A common SDK release still needs to be agreed and recorded.
- **Ruby linting:** Run `bundle exec rubocop` from the repository root. The restored `.rubocop.yml` defines project lint rules and includes `mygame/app/main.rb`; the old starter-scene exclusion no longer applies.
- **Art direction:** low-fidelity 2D top-down. Placeholder and AI-assisted assets are acceptable if gameplay readability is good. The Witness concept is a tall, slender, robed figure with a broken halo and an exposed pale, desiccated face showing terror and agony.
- **MVP scope:** one player, a small curated set of arrangements made from handcrafted monastery spaces, one Witness, one ritual-gate puzzle, no lore or networking. The first vertical slice may use one arrangement while the loop is being proved.

## Decisions and their rationale

| Decision | Reason |
| --- | --- |
| Handcrafted rooms in curated arrangements | Room positions and neighbors may change between approved configurations. This provides variation while keeping every playable arrangement inspectable. |
| Multi-exit passages | Corridors, galleries, and junctions are traversable spaces that can connect several rooms, rather than only one-to-one links between fixed slots. Loops give players and the Witness choices during pursuit. |
| Any eligible room can host a clue | “Main” and “filler” are not permanent room types. Assign clues per run, with enough reachable, interpretable hints to solve the three-symbol order. |
| Ritual Gate is start and goal | The player begins at the sealed gateway and returns with the answer. Opening it completes the MVP run; the next level is deferred. |
| Vary content within each arrangement | Vary the solution, clue locations, and selected hazards or the Witness's starting position without generating arbitrary room geometry. The player always starts at the Ritual Gate. |
| Rule-based Witness with memory | States, last-known positions, and weighted evidence can produce understandable cunning at a small team's scale. |
| Distant detection permits a narrow escape | A chase is compelling when breaking sight and misleading a search can work. Walking into the Witness at close range remains fatal. |
| Puzzle based on inference | Semantic variants of clues should lead to an ordered sequence, rather than three disguised fetch items. |
| Co-op later | Multiplayer is a long-term interest, but the single-player loop must work first. |
| No lore in MVP | Validate the play loop before writing journals, monologues, or a larger mythology. |

The supplied high-level sketch still lists procedural generation, health, lore, and “find bro.” Treat these as ideas in the broader concept, **not approved first-build requirements**. The newer MVP decision is to select from validated authored arrangements and vary their run content. An algorithm that invents new room geometry or connections without an approved configuration is not planned.

## Map authoring model

These are proposed data boundaries, not an implemented map format:

- **Room and passage templates:** Handcrafted tile layers, collision, objects, and local coordinates. Doorway sockets mark compatible openings. A passage template can have three or more exits and can itself contain cover, noise hazards, or hiding places.
- **Arrangement manifests:** Authored placements and orientations of templates on a shared tile grid, with explicit connections. Select one approved manifest per run. Do not assume all rooms occupy fixed slots or that every run uses the same neighbor relationships.
- **Run content:** Choose a symbol solution, then assign sufficient semantic hints to eligible clue points in reachable rooms. Any room may be a clue host; room identity alone should not reveal whether it matters this run. Validate solvability and avoid placing all necessary information on one short route.
- **World assembly:** Compose visual tile layers and gameplay objects; derive walkability, line of sight, and Witness routes from the selected arrangement and current door states. The Witness knows this topology but only infers player location from observations.

For the first slice, hand-place one arrangement. Add further curated arrangements by reusing templates and validating their connections. An ASCII grid, numeric tile layers, or editor-exported data are all possible source formats; choose the one that fits the team's workflow rather than committing to a format here.

## Proposed vertical slice

1. Player navigation and collision from a small, hand-placed arrangement of rooms and branching passages, starting at the Ritual Gate.
2. Interact with clues; generate a valid three-symbol solution and place sufficient hints in eligible rooms so the sequence can be deduced.
3. Toggle lamp and sneak; implement one or two sound-producing surfaces or doors.
4. Give the Witness patrol, investigate, pursue, and search behaviors with explicit sight and hearing observations.
5. Add the Ritual Gate input, run-complete/failure outcomes, and a quick way to restart with a new clue assignment.
6. Reuse the room and passage pieces in further curated arrangements after the single-arrangement loop works; validate room access, clue solvability, and more than one useful route through pursuit spaces.
7. Add sanity only after its consequence is defined and shown to improve the light-versus-stealth decision.

Build a gray-box version before committing to finished animation. A successful slice can be completed end to end and can produce at least one convincing moment where the player deliberately misleads the Witness.

## Working state models

These are design sketches, not implemented APIs.

**Run:** `at_sealed_gate → exploring → gate_opened → run_complete`, with `caught` as a terminal state. Opening the gate ends the MVP run; no next-level scene is required. Keep puzzle solution separate from the revealed clues so the player must infer the sequence.

**Witness:** `patrol → investigate → search → patrol`; a sighting can move it to `pursue`. On losing sight, search from the last confirmed position, then consider plausible exits or clue-bearing rooms. The Witness knows the selected passages and can update a room's priority when it finds a visible change. It must distinguish a confirmed sighting from a guess; merely reading an untouched clue need not leave evidence.

**Observations:** direct sight, a sound with a source and time, last seen/heard location, and persistent environmental changes such as a door or clue state. Keep this event data small and inspectable while tuning behavior.

**Player pressure:** lamp state, movement mode, visible/hidden status, and possibly sanity. If sanity remains, decide its trigger, feedback, and gameplay consequence before implementing a bar.

**Map/run:** selected authored arrangement, current passage and door states, chosen three-symbol solution, and clue assignments to eligible room points. Spatial layout and clue placement are separate decisions.

## Open decisions to settle through a prototype

- What does low sanity do that is clear and interesting, and is it needed for the first slice?
- Is yelling or a deliberate decoy needed when environmental noise can already mislead the Witness?
- Which hiding places permit escape, and what evidence allows the Witness to check them?
- How many clue formulations are needed so the puzzle stays solvable without becoming memorized?
- How many authored arrangements provide meaningful route variety for the MVP, and which template/socket conventions make them economical to build?
- What placement rules keep clue sets reachable, sufficiently spread out, and fair across each arrangement?
- What minimum audio and visual cues make the Witness's inferences feel fair?
- How should future co-op alter clues, noise, and pursuit without weakening the single-player design?

## Contribution and asset notes

- Keep an approved source sprite or reference for each important character. Validate sprite-sheet pixel dimensions, frame boundaries, transparency, and foot anchors automatically; preview the actual loop at game scale.
- An 8-column, 4-row sheet of 64 × 64 cells is **512 × 256 pixels**. The artwork inside each cell may use transparent padding. Do not treat a generated sheet as game-ready solely because its outer dimensions match.
- Store game-ready sprites under `mygame/sprites/descent/` and other runtime assets under the matching `mygame/` directories, alongside applicable source and license/provenance notes. Asset paths in code are relative to `mygame/`.
- Keep source room and passage tilemaps distinct from their arrangement manifests. Do not encode clue importance permanently in a room's visual tiles.
- Record new decisions in the appropriate file: player-facing intent and scope in `PRODUCT.md`; present implementation facts, commands, and known gaps here.
