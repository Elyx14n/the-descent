# The Descent — Product

## One sentence

A small, top-down horror game in which a player deciphers a ritual lock inside a monastery while evading the Witness, an enemy that uses clues left in the world to anticipate where the player will go.

## The experience we want

The player should feel like an intruder in a place the Witness knows intimately. Light helps them stay composed but makes them easier to notice. Darkness helps them hide but makes exploration more dangerous. The Witness is threatening because it follows evidence and cuts off routes, not because it moves at an unfair speed or reads the player's inputs.

The first release is a **lore-free gameplay MVP**. The setting and character design establish mood; journals, backstory, monologues, and a larger narrative are outside this slice.

## Core loop

1. Start in the sealed Ritual Gate room and orient yourself in one of several authored monastery arrangements.
2. Explore rooms to find and interpret clues to a three-symbol sequence.
3. Decide when to use the lamp, move quietly, or risk creating noise.
4. Observe and evade the Witness. It investigates sounds, remembers where it saw or heard you, and may infer which clue-bearing room matters next.
5. Return to the Ritual Gate and enter the decoded sequence to complete the run. The level beyond the gate is outside the MVP.

A run ends when the player opens the gate or the Witness catches them. A close-range ambush on its path is fatal. If it spots the player from farther away, the player has a slim chance to break line of sight and misdirect its search.

## MVP mechanics

| System | MVP target |
| --- | --- |
| Perspective | 2D, top-down, low-fidelity art. |
| Map | A small set of curated arrangements built from handcrafted rooms and branching passages. Rooms can move relative to one another; a passage can connect three or more spaces. Randomize the code, eligible clue locations, and selected hazards or the Witness's starting position between runs. |
| Objective | Decode the order of three symbols from clues, return to the Ritual Gate, and open it. Any eligible room can hold a clue in a given run; there are no permanent “main” or “filler” room roles. Clues should convey relationships or meanings, not merely ask the player to fetch three matching objects. |
| Player | Walk, sneak, toggle a lamp, inspect/interact, and use a small number of hiding places. |
| Pressure | Light versus darkness and a simple sanity meter. The meter's exact consequence is a playtest decision; it must affect a player's choices if retained. |
| Sound | A few legible hazards such as creaky boards, glass, or a noisy door. Sounds have a location the Witness can investigate. |
| Witness | Patrol, investigate, search, and pursue. Use line of sight, audible events, last-known position, and a small memory of meaningful world changes. It can favor likely routes and rooms, but has no omniscient access to player position. |
| Escape | Breaking line of sight creates an opportunity, not a reset. The Witness searches the last-known area and nearby likely exits. Darkness and hiding only work when they plausibly block detection. |

The Witness's **mental model of the player** is the distinctive feature. It knows the selected arrangement, including passage junctions, but needs evidence to locate the player. Keep its reasoning legible: footsteps, disturbed doors or clue sites, and sightings should explain why it is looking somewhere. Use a small set of weighted rules and states; machine learning is not required.

## Design principles

- **Fair dread:** Cues let an attentive player understand a mistake and occasionally outthink the Witness.
- **A knowledgeable pursuer:** It knows the map; it still needs evidence to know the player's current location.
- **Meaningful tradeoffs:** Light, speed, silence, and hiding each solve one problem while creating another.
- **Authored spaces, varied arrangements:** Reuse recognizable handcrafted rooms in curated configurations with different neighbors and multi-exit passage junctions. Players can learn the spaces without memorizing one route.
- **No fixed room hierarchy:** Any eligible room may become important through its clue, route, cover, hazard, or what the Witness infers about it that run.
- **Repeatable without bloat:** Vary the curated arrangement, clue locations, and hazards without generating arbitrary room geometry.
- **Build the loop before the fiction:** Atmosphere supports gameplay, but lore is deferred.

## Out of scope for the MVP

- Co-op or online multiplayer, although future co-op should remain a design goal.
- Unrestricted procedural floor-plan generation or an algorithm that invents room geometry. The planned variations are authored and validated.
- The destination beyond the Ritual Gate.
- Journals, scripted lore, monologues, story branches, and a full rescue/escort story for the diagram's “find bro” idea.
- Complex combat, inventories, crafting, upgrades, multiple enemies, elaborate hallucinations, or learned/ML-driven AI.
- Large sprite libraries or polished effects before the loop proves fun.

## First playable milestone

One short, completable single-player run: start at the sealed Ritual Gate, learn the controls, find enough clues to infer a randomized three-symbol sequence, evade one Witness that responds to sight and sound, then return and open the gate or die. A first vertical slice can use one authored arrangement; add curated variations after the loop works. Playtesting should tell us whether the puzzle and the pursuit create interesting choices before we add more content.
