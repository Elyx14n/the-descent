# The Descent — Glossary

Game and rendering vocabulary, including planned concepts. Implementation status lives in [CONTEXT.md](CONTEXT.md).

## Player and objective

**Player**: The human-controlled intruder exploring the monastery.

**Witness**: The monastery's pursuer, which uses observations to locate the player.

**Ritual Gate**: The sealed gateway that is both the player's starting location and the goal of a run.

**Run**: One attempt to find and place four ritual items, unlock the Ritual Gate, and open it before being caught.

**Ritual item**: One of four required objects identified through vague descriptive hints. Placing all four on the pedestals unlocks the Ritual Gate, with no required placement order.

**Pedestal**: A fixture near the Ritual Gate that receives a ritual item. Four pedestals hold the four required items.

**Clue**: A vague descriptive hint used to identify and find a ritual item.

**Observation**: Evidence available to the Witness, such as a sighting, sound, or visible environmental change.

## Monastery spaces

**Room**: A handcrafted monastery space.
_Avoid_: Main room, filler room (as permanent room types)

**Passage**: A traversable connection between rooms, including corridors, galleries, and junctions.

**Room template / passage template**: A reusable handcrafted definition of a room or passage, independent of its placement.

**Doorway socket**: A designated opening on a template where a compatible connection can be made.

**Arrangement**: A configuration of room and passage placements and their connections assembled from authored choices.

**Arrangement manifest**: The description of placements and connections making up an arrangement.

**Backbone**: The permanent connected set of room and passage connections that remains traversable in every arrangement.

**Shortcut**: An optional connection at an authored location that can open or remain blocked as part of an arrangement.

**Clue point**: An eligible location within a room where a clue can be assigned.

**Run content**: The ritual-item and clue placements, and selected hazards or Witness starting position and patrol direction chosen within an arrangement.
_Avoid_: Arrangement (when referring only to these content choices)

**Prop**: A placed environmental object, such as a coffin or banner, which may block movement or serve as decoration.

## Rendering

**Foreground fading**: Reducing the opacity of nearby scenery that draws over an actor, so the actor remains readable behind it. This affects the camera's view without changing movement blocking or gameplay sight rules.

**Occluder**: A shape used to decide whether scenery obstructs something behind it. Foreground fading uses active wall/door colliders together with artwork overlap; ground-light blocking uses active object colliders. See [ADR-0015](docs/adr/0015-use-colliders-for-foreground-fading.md) and [ADR-0014](docs/adr/0014-use-collider-bases-for-lighting.md).

**Light blocker**: An object's active collider used as a ground-plane obstacle to illumination. Tall artwork and caps do not add separate blocking silhouettes; see [ADR-0014](docs/adr/0014-use-collider-bases-for-lighting.md).

**Fade unit**: A local group of scenery sprites that shares one foreground-fading response, such as a wall face, its cap, and mounted artwork. Its supporting walls or doors supply the active colliders; lighting selects its blockers independently.

These definitions describe our 320 × 180 DragonRuby setup with [HD disabled](docs/adr/0013-keep-hd-disabled.md). World space, screen space, and draw space describe coordinate representations; a logical pixel is a unit, while source, native raster, and display pixels belong to image grids. See the [coordinate reference](reference/coordinates-and-pixels.html) for their relationships and [ADR-0019](docs/adr/0019-use-direction-aware-camera-rounding.md) for the current presentation policy.

**Source pixel / artwork pixel**: One pixel stored in a sprite image. HD changes how that artwork is presented; it does not add newly drawn detail to the source image.

**Logical pixel**: A coordinate unit on our reference canvas, independent of window size; this translation-only camera uses the same unit for world, screen, and draw coordinates. At entity scale 1, one source pixel spans one logical unit before rasterization.

**Reference resolution / logical canvas**: The coordinate dimensions used to frame the game, currently 320 × 180. Enlarging the window preserves this view of the world.

**Raster**: An image stored as a grid of coloured pixels. **Rasterization** converts drawing instructions, such as sprite rectangles or font outlines, into that grid.

**Native raster pixel**: One cell in a raster DragonRuby renders before final presentation; with HD off, the final game raster is 320 × 180 and one native pixel spans one logical unit. Intermediate scene targets have their own grids; the current scene and lightmap targets are also 320 × 180.

**Physical pixel / display pixel**: One actual pixel of the display output after scaling and letterboxing. At a 5.5× window fit with HD off, one native pixel spans 5.5 display-pixel units geometrically; sampling determines the colors on the discrete display grid.

**Render scale**: DragonRuby's multiplier from logical coordinates to its native raster, exposed as `Grid.render_scale`. In our tested 5.5× enlarged window it is 5.5 with HD on and 1 with HD off.

**Window fit scale**: The multiplier fitting the logical canvas into the displayed viewport. It can remain 5.5 even when HD is off and the render scale is 1, because the completed low-resolution frame is enlarged afterward.

**HD mode**: DragonRuby's higher-resolution scene and font rendering while retaining logical coordinates. It provides a finer native raster for drawing alignment and more raster detail for small glyphs.

**World space**: Positions relative to the room or map, used for gameplay, movement, and collision, measured in logical units. Positions can be fractional, negative, or outside the viewport; the world is not limited to 320 × 180.

**Screen space**: Camera-relative positions in the logical viewport's coordinate system, measured from its bottom-left origin. Coordinates can remain fractional; camera translation is reversible and does not itself require rounding artwork or using physical display-pixel coordinates.

**Draw space**: Our project term for artwork coordinates prepared for a drawing destination, still measured in logical units; it is not a separate SDK coordinate system or render buffer. Scenery uses a camera aligned through direction-aware rounding, while direct actors use the precise camera and align their final screen-space bounds to the native raster.

**Pixel snapping / drawing alignment**: Rounding artwork placement onto the native raster grid while preserving precise gameplay positions. With HD off, final actor bounds align in one-logical-unit steps after camera translation; snapping is a presentation operation, distinct from converting coordinate spaces.

**Sampling**: Choosing or combining source-image colours when drawing a sprite or scaling an image. Nearest-neighbour sampling chooses a source pixel; DragonRuby's pixel-art sampler uses a different filtering policy intended for scaled pixel artwork.

**Glyph**: The drawn shape of one character in a font. A rasterized glyph is its pixel representation at the rendering resolution; glyphs are text-specific and do not determine the sprite snapping calculation.

**Atlas bleed**: Colour sampled from outside a sprite's selected atlas cell, such as a neighbouring tile. It can look like a thin seam even when the destination rectangles meet exactly.

**Tile seam / sub-pixel gap**: A visible line between tiles; this describes appearance rather than establishing a cause. An uncovered background gap and atlas bleed are different causes and should be distinguished when diagnosing it.

**Jitter**: An unwanted visible wobble or uneven step in motion. Specify camera jitter when the room shifts unexpectedly, and player-sprite jitter when the player wobbles relative to the room.
