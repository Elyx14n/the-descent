# The Descent — Glossary

Game vocabulary, including planned concepts. Implementation status lives in [CONTEXT.md](CONTEXT.md).

## Player and objective

**Player**: The human-controlled intruder exploring the monastery.

**Witness**: The monastery's pursuer, which uses observations to locate the player.

**Ritual Gate**: The sealed gateway that is both the player's starting location and the goal of a run.

**Run**: One attempt to solve the symbol sequence and open the Ritual Gate before being caught.

**Symbol sequence**: The ordered three-symbol answer required to open the Ritual Gate.

**Clue**: An interpretable hint about the symbol sequence.

**Observation**: Evidence available to the Witness, such as a sighting, sound, or visible environmental change.

## Monastery spaces

**Room**: A handcrafted monastery space.
_Avoid_: Main room, filler room (as permanent room types)

**Passage**: A traversable connection between rooms, including corridors, galleries, and junctions.

**Room template / passage template**: A reusable handcrafted definition of a room or passage, independent of its placement.

**Doorway socket**: A designated opening on a template where a compatible connection can be made.

**Arrangement**: An authored configuration of room and passage placements and their connections.

**Arrangement manifest**: The description of placements and connections making up an arrangement.

**Clue point**: An eligible location within a room where a clue can be assigned.

**Run content**: The symbol sequence, clue assignments, and selected hazards or Witness starting position chosen within an arrangement.
_Avoid_: Arrangement (when referring only to these content choices)

**Prop**: A placed environmental object, such as a coffin or banner, which may block movement or serve as decoration.
