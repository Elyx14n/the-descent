# Wall occlusion and collision

Research date: 2026-10-11. Evidence and proposed guidance; this note does not establish a new implementation decision. Room authoring remains governed by [ADR-0004](../adr/0004-tiled-room-authoring.md).

Current status: the user rebuilt the southern boundary and dropped the Foreground proposal. The game has returned to the original 8 × 2 foot collider and collision-derived sorting for a controlled comparison. The proposal below is retained as research history, not the current authoring instruction.

Collision and draw order are separate conventional concerns. Collision describes the occupied ground area. A sorting point describes the ground position used to draw one object in front of another. Artwork can extend beyond both.

Primary examples:

- Godot's `TileData` defines a tile's `y_sort_origin` separately from its collision polygons. The former controls visual order; the latter defines physics geometry. This is direct evidence for separate data, without implying that every tile needs a custom offset. [TileData documentation](https://docs.godotengine.org/en/stable/classes/class_tiledata.html#class-tiledata-property-y-sort-origin).
- Godot sorts CanvasItems by position. A sorted parent can keep its children together at the parent's sorting position. This supports one ground anchor for a prop assembled from several images. It does not support giving every adjoining wall tile the same arbitrary depth. [CanvasItem documentation](https://docs.godotengine.org/en/stable/classes/class_canvasitem.html#class-canvasitem-property-y-sort-enabled).
- Tiled exports object-layer `draworder` independently of tile collision shapes. Its default Top Down order uses object positions; collision shapes have a separate authoring tool. A runtime must still integrate its characters with the intended layers. [JSON format](https://doc.mapeditor.org/en/stable/reference/json-map-format/#layer), [object order](https://doc.mapeditor.org/en/stable/manual/objects/#changing-stacking-order), [tile collision editor](https://doc.mapeditor.org/en/stable/manual/editing-tilesets/#tile-collision-editor).
- RPG Maker MZ documents passable star tiles that hide characters behind buildings. This is a concrete established example of artwork above the character without blocking movement in that tile. [Tileset settings](https://rpgmakerofficial.com/product/MZ_help-en/01_08_10.html).

## Implications for this room

The following is an engineering inference from these sources and the current room renderer, not an editor requirement:

1. Keep the player's collider as its intended ground footprint. Expanding it to cover the full body or swinging limbs changes approach distances around every prop. It should not be used to repair wall draw order.
2. Keep floor artwork below the player. Keep genuine overhead artwork, such as wall caps and door headers, above the player without adding collision just to change rendering.
3. Sort freestanding props and characters by their ground positions. Give multipart props one consistent ground anchor. An optional sorting offset is conventional when the image origin does not match that anchor, but a collection of guessed offsets is not a complete wall-authoring convention.
4. Inspect each wall section's intended coverage. Adjacent image cells belonging to one raised face must not unexpectedly change visual order just because their collision rectangles differ. A longer wall with changing ground position may need separate sections or overhead artwork rather than one sorting point for the entire wall.
5. Draw order only affects opaque artwork. Transparent or missing pixels in a corner piece cannot hide the player regardless of its sorting point. If an overlap reaches such a gap, fix the placed artwork or its foreground coverage, then verify collision still allows the intended floor area.

In DragonRuby, world Y increases upward, so lower ground positions render later when using ordinary Y sorting. This reverses the sort direction used by editors with downward Y coordinates; it does not require making positions negative or deriving depth from collision geometry.

## Concrete diagnosis of the current export

The rejected collider change increased horizontal half-width from 4 to 9 pixels. That moves the player's stopping position five pixels farther from every vertical contact surface at scale 1; the user's visible gaps are a direct consequence.

The renderer currently sorts every Walls object independently. For example, right-edge object 33 starts at world Y=128, and corner object 160 starts at Y=96. A player with feet at Y=112 can overlap both pictures, but object 33 draws behind the player while object 160 draws in front. Their shared wall does not have one coherent coverage rule. These values come from [the exported map](../../mygame/tiled/ritual_gate.json) and [the renderer](../../mygame/app/render.rb).

Direct alpha-channel inspection of [the environment atlas](../../mygame/sprites/environment_tilesheet.png) also finds that local tiles 21 and 23, placed as objects 157–160, have no opaque pixels from source row 12 through row 31. They are short corner end pieces. In comparison, tiles 20 and 24 have a six-pixel opaque edge strip through all 32 rows. A full-height collider on a short end piece does not create full-height visual coverage. This is evidence of a possible coverage gap; the correct replacement artwork must be checked in context.

## Proposed next slice

This proposal has not been implemented or accepted:

- Restore the 8 × 2 foot collider, and retain collision rectangles based on the intended ground footprint.
- Keep ordinary props and characters sorted by their ground anchors.
- Add a `Foreground` object layer for wall artwork that must always cover the player from reachable floor, starting with the relevant south perimeter faces and upright boundary trim. Read its authored tile colliders normally, and draw its artwork after sorted objects and before Ceiling. Moving an object to this layer preserves its position and collider; it does not require duplicating the picture or geometry.
- Keep north-facing room-edge faces in the ordinary drawing path. Walls that can be approached from both sides still need sorting or a visual split; assigning every wall to Foreground would be incorrect.
- Keep Ceiling for collision-free caps and door headers. Inspect the short corner pieces for missing visual coverage; use suitable continuous edge artwork or decorative trim where coverage is needed. Fixing draw order cannot supply missing artwork.
- Verify the south corners, north stepped corners, close approaches to props, and passage beneath the south caps with the original foot footprint. Check visual results as well as movement: regression tests for an inflated collider did not establish correct occlusion.
