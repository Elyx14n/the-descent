---
status: accepted
date: 2026-10-07
---

# Use Tiled as the main room and passage editor

Author rooms and reusable passage pieces in Tiled, replacing the manual Ruby floor recipes, borders, and ASCII stamps. Visual editing makes handcrafted spaces easier to change and supports irregular interiors within the [agreed fixed-slot map approach](0003-fixed-map-footprint-and-approved-shortcuts.md).

## Implementation direction

Tiled-authored resources are the source of truth for room artwork and spatial metadata. Consume native Tiled resources through the simplest suitable loader. The exact format, loader, and layer/property conventions remain implementation choices.

The user explicitly authorizes deleting or replacing the existing manual room implementation and changing runtime interfaces where this simplifies consuming Tiled resources. Do not preserve the old floor recipe API, numeric/symbol normalization, catalog IDs, or data representation for compatibility. Ordinary tile-ID resolution and coordinate conversion belong in loading/rendering code; they are implementation details, not reasons to revisit the editor decision or request further approval.

Preserve intended gameplay and accepted camera/display behavior. Existing classes and interfaces can change. Keep the runtime small and avoid a second authoring system or a general-purpose format framework.

## Scope

The six-room MVP, fixed slots, compatible doorway sockets, backbone, and approved shortcuts remain as agreed in ADR-0003. Irregular walkable interiors can occupy compatible slot bounds. Assembly, collision response, and gameplay remain game responsibilities.

This decision accepts the editor and replacement direction; integration is not yet implemented. Current status lives in [CONTEXT.md](../../CONTEXT.md), and source evidence and loader options are in the [Tiled research note](../notes/tiled-room-editor.md).
