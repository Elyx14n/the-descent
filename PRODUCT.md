# The Descent — Product

A small, top-down horror game in which the player deciphers a ritual lock inside a monastery while evading the Witness, a pursuer that uses evidence to anticipate where they will go.

## Intended experience

The player should feel like an intruder in a place the Witness knows intimately. Light helps them stay composed but makes them easier to notice. Darkness helps them hide but makes exploration more dangerous. Cues should let an attentive player understand mistakes and occasionally outthink the Witness.

The Witness knows the arrangement but needs observations to locate the player. Its threat comes from memory, inference, and cutting off routes, rather than unfair speed or access to the player's inputs. A close-range ambush is fatal; distant detection leaves a slim chance to break sight and misdirect the search.

## Core loop

1. Start at the sealed Ritual Gate.
2. Explore rooms and interpret clues to a three-symbol sequence.
3. Choose when to use the lamp, sneak, hide, or risk noise.
4. Evade the Witness as it investigates evidence and pursues sightings.
5. Return to the Ritual Gate and enter the sequence.

Opening the gate completes the run; being caught ends it in failure.

## MVP requirements

| System | Requirement |
| --- | --- |
| Map | Six initial handcrafted rooms and reusable branching passages within one fixed grid footprint. A permanent connected backbone contains a loop; open two of four or five reserved shortcuts from approved combinations. See the [map decision](docs/adr/0003-fixed-map-footprint-and-approved-shortcuts.md). |
| Run variation | Vary compatible room assignments, the approved shortcut combination, symbol sequence, eligible clue locations, and the Witness's valid starting position and patrol direction. |
| Puzzle | Clues convey relationships or meanings, rather than acting as three fetch items. Any eligible room can host a clue; there are no permanent main/filler room types. |
| Player | Walk, sneak, toggle the lamp, inspect/interact, and use a small number of hiding places. |
| Pressure | Light versus darkness; retain sanity only if playtesting establishes a consequence that improves player choices. |
| Sound | A few legible hazards, such as creaky boards, glass, or a noisy door, produce located sounds the Witness can investigate. |
| Witness | Patrol, investigate, search, and pursue using sight, hearing, last-known positions, and meaningful environmental changes. Use a small set of weighted rules and states. |
| Escape | Breaking sight creates an opportunity, not a reset. Search continues around the last-known area and likely exits; darkness and hiding must plausibly block detection. |

## Art direction

Low-fidelity 2D top-down art. The Witness is a tall, slender, robed figure with a broken halo and an exposed pale, desiccated face showing terror and agony. Placeholder and AI-assisted assets are acceptable when gameplay remains readable.

## Out of scope

- Co-op or networking; revisit multiplayer after the single-player loop works.
- Automatic spatial room placement, corridor routing, maze generation, unrestricted procedural floor plans, generated room geometry, or a general layout solver.
- The level beyond the Ritual Gate.
- Lore, journals, monologues, story branches, or a rescue/escort storyline.
- Complex combat, inventories, crafting, upgrades, multiple enemies, elaborate hallucinations, or learned/ML-driven AI.
- Large sprite libraries or polished effects before the loop proves fun.

## First playable milestone

One short, completable run in one validated configuration of the authored footprint with randomized clues and a Witness responding to sight and sound. Use a gray-box build to test whether inference and pursuit create meaningful choices, including a moment where the player deliberately misleads the Witness. Add further compatible room assignments, approved shortcut combinations, and finished presentation after that loop works.
