# Audit checklist

These conventions describe the room preview/importer agreed on 2026-10-12. Reconcile them with current code and project decisions on each audit.

## Export, resources, and IDs

- Runtime input is a finite orthogonal JSON map with positive dimensions, embedded image tilesets, and uncompressed numeric tile arrays. External tileset references, image collections, infinite chunks, and encoded/compressed data are outside the current loader. Source TMJ files may use external tilesets; judge their exported counterparts separately.
- Exactly these layers currently load: Ground and Ceiling are `tilelayer`; FloorDetails, Walls, and Props are `objectgroup`. Names are case-sensitive. Check tile data length against layer width × height. Layer offsets, nested groups, tileset drawing offsets, and rotated placed objects are unsupported.
- Tile objects need usable GIDs and positive rendered dimensions; Spawn is the point-object exception. Check duplicate IDs/property names, property types, atlas geometry, and overlapping tileset GID ranges even where the importer lacks validation.
- Resolve image paths relative to the export, normalize separators, and confirm the resulting files exist inside `mygame/`. Absolute POSIX/drive/UNC/WSL paths are not portable. Resource filenames are not fixed contracts.
- Mask GIDs with `0x0fffffff`, select the applicable `firstgid`, and subtract it for the local tile ID. Only horizontal `0x80000000` and vertical `0x40000000` flags currently load; the other two flag bits are unsupported. Check IDs against `tilecount` and image crops.
- Map-layer GID 0 means empty. Tileset-local ID 0 is valid artwork, including in door pair properties.
- Accept the loader's bottom-left alignment defaults; flag unsupported explicit alignments. Sprite cells are commonly 32 × 32, but mixed sizes and deliberate scaling are supported. Player frames are 64 × 64. Do not enforce uniform sizes or rectangular walkable interiors.
- Visibility does not necessarily suppress gameplay metadata: the current importer processes some colliders/classes even when artwork is hidden. Trace the code before assuming hidden fixtures have no physical effect; identify unintended invisible blockers.

## Classes and effective properties

Concrete classes are Door, Light, Pedestal, and Spawn. Unclassed tiles can be scenery. Interactable and LightProp are deprecated; flag remaining effective uses, not historical names in notes.

Read both `class` and legacy `type` as the loader does. A placed object's nonempty class overrides the tile class; object properties override tile properties. Check mismatched overrides and types. Plain rectangles/points with arbitrary classes are not imported as tile fixtures.

## Doors and upper pieces

- Bases belong on Props. Both artwork variants have class Door and identical `close_tile`/`open_tile` local IDs: distinct integers in the same tileset. The placed variant belongs to that pair and defines initial state; an `open` Boolean is not required.
- Optional upper pieces on Ceiling also have class Door and their own consistent pairs. Each attaches to the base immediately below it through grid placement and follows its state. Check orphan pieces, competing bases, and grid coordinates. Upper pieces are artwork, not separate interaction targets or physical barriers.
- Static stairs/background artwork in a door tileset stays unclassed. Do not class the whole atlas as Door.
- Closed and open bases each use their own tile's collision rectangles. Inspect open artwork, especially side-facing leaves: opening does not automatically remove collision or rotate the old collider. An intentionally collider-free open variant is valid.
- `locked` is a Boolean inherited/overridden on the base; missing defaults to false. E rejects a locked targeted door. A cap's lock does not control its base. `set_door_open` is explicit programmatic state control; it is not proof that E respects locks.
- The current room's north base is the Ritual Gate and should start closed with `locked: true`. Four items identified through vague descriptive hints will be placed on four pedestals in no required order to unlock it. Placement/unlocking remains future functionality. Do not require an ordered symbol sequence, invent item-to-pedestal assignments, or demand four pedestals and a gate in every room. Discover current object IDs rather than fixing today's IDs as permanent.

## Coordinates, colliders, and boundaries

- World map height is map height × tile height. A bottom-left tile object's world bottom is `map_height - object.y`; a Spawn point's world Y is `map_height - point.y`. The current tile-layer placement is `map_height - (row + 1) * map_tile_height`; check oversized tile artwork separately.
- Rectangles/offsets originate in native source pixels, measured right/down from the tile's top-left. Mirror within source width/height, then scale. A local point becomes `world_x = sprite.x + local_x * scale_x`, `world_y = sprite.y + (source_height - local_y) * scale_y`. Transform both rectangle corners and normalize bounds.
- Only positive-sized, unrotated rectangular tile collision shapes currently load; multiple rectangles per tile are supported. Shapes inherit placed-object transforms. Visible pixels may occupy less than the full frame.
- Inspect transformed walls for unintended gaps, overlaps, enclosed U-shaped traps, blocked doorways, and walkable space behind overhead caps. Account for the current player foot box (8 × 2 at default scale) and its offset; verify Player/Entity values before calculating.
- Thin/asymmetric colliders can be intentional. Do not invent a universal minimum width, force full-tile collision, or classify every missing collider as defective. Decorations and steppable floor details can have none.
- Distinguish a physical leak from body/artwork overlap while feet collide correctly. A geometric gap alone does not prove passage: surrounding obstacles and movement resolution matter. Use runtime checks or a precise playtest scenario where static evidence is insufficient.

## Drawing and mounted fixtures

- Ground/FloorDetails render below scenery and actors. Walls/Props and actors share depth ordering; Ceiling renders afterward and is visual only. FloorDetails is an object layer for steppable artwork. The abandoned Foreground layer is outside the current loader.
- Room derives default depth from the lowest world Y of colliders, falling back to the sprite bottom. This is the current implementation, not a requirement that every occluding pixel have a collider. Do not add physical barriers to fix drawing-only overlap.
- A Props fixture's `mounted_on` is an Object reference to a visible Walls tile object. Empty/0 means freestanding. Hosts draw attachments afterward in the same depth group, one level deep. Invalid IDs, targets on Props/Spawn/FloorDetails, and unsupported nesting are defects.
- Preserve deliberate fixture positioning. Do not force mounted artwork onto the tile grid or substitute numeric elevation hacks. Verify artwork visibility against its host separately from emitter placement.

## Lights, pedestals, and Spawn

- Light belongs to the whole fixture tile/object. `offset_x`/`offset_y` locate its emitter, independently of collision shapes or mounted draw groups. Offsets follow scaling and flips.
- `enabled`, `radius`, `intensity`, and `color` are future lighting data. Empty color and zero radius/intensity are agreed defaults for later overrides, not defects. Illumination and light interaction are not implemented. Judge offsets against artwork; out-of-frame values need explanation, not automatic rejection.
- Pedestal replaces Interactable. Its offsets define the future item anchor, exposed as `item_position`. Collider, depth, and anchor have different purposes. Check four distinct usable anchors in the Ritual Gate room without imposing that count on other templates.
- The discrete preview requires exactly one Spawn point, located at the player's feet without artwork/collider. Check the instantiated foot box against active starting-state collision and bounds, with room to move away. A center-of-room point alone does not prove safe placement.
- The preview is a development consumer of reusable room resources. These checks do not establish a future map/multiplayer contract. Do not demand six rooms, map connectivity, multiple player spawns, or a room-owned renderer in an individual-room audit.
