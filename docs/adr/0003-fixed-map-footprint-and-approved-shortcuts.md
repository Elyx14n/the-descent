---
status: accepted
date: 2026-10-07
---

# Assemble the MVP map within a fixed footprint with approved shortcuts

Use handcrafted rooms and reusable passage pieces within one authored grid of room-sized slots. Vary compatible room assignments and approved shortcut combinations between runs. This gives pursuit and escape different routes while keeping map authoring and assembly small.

## Footprint and rooms

The initial map contains six rooms. Each slot contains a room, passage, junction, or unused space. Standardized room footprints and doorway positions let compatible rooms swap slots between runs; slot positions and passage routes are authored.

The Ritual Gate remains at a fixed starting location and hosts the final puzzle interaction. Other room names, themes, and interior descriptions are not prescribed: choose them from the available tileset. Any room can contain a clue, with no permanent objective/filler distinction.

## Connectivity

A permanent connected backbone containing a loop keeps every room reachable and provides routes for pursuit and escape. Passage pieces can branch into multiple rooms, and some rooms have multiple exits so chases can pass through their interiors.

Define four or five candidate shortcut connections in reserved locations. Open exactly two per run, selected from approved combinations. Render inactive connections as walls or sealed doors that block traversal. Use corners and sight blockers to create opportunities to lose the Witness.

Compatible room assignments and shortcut combinations must preserve the backbone and traversable doorway connections. Code assembles the authored pieces into validated configurations; it does not find new room positions or corridor routes.

## Run variation

Each run varies compatible room assignments, the active shortcut combination, clue locations, ritual symbol order, and the Witness's valid starting position and patrol direction. The Witness knows the assembled layout but must locate the player through sight, sound, and evidence.

## Scope and consequences

Author one structural footprint, six initial room interiors, and a small set of passage pieces. Expand later by adding slots, loops, rooms, and approved connections within the same approach.

The MVP excludes automatic spatial room placement, corridor routing, maze generation, unrestricted procedural generation, and a general layout solver. It trades unrestricted layout variety for a small set of authorable, verifiable choices. The room data format, exact slot layout, and approved shortcut combinations remain to be defined during implementation.

This decision is accepted but not implemented; current status lives in [CONTEXT.md](../../CONTEXT.md). The [map-system research](../notes/room-arrangement-systems.md) and local DragonRuby samples remain speculative references for individual techniques, not an adopted generator or authoring tool.
