---
name: tilesheet
description: "Find and compare existing environment, prop, door, or effect art in The Descent's current atlases. Use for selecting Tiled tiles or calculating sprite crops; use tiled-json-audit for room export validation."
---

# Tilesheet art lookup

Choose existing art from current assets and identify it precisely for Tiled or a standalone sprite. Tiled is the main room editor; atlas names and appearance do not define gameplay behavior.

## Establish the active atlas

Read the relevant room's tileset definitions and resolve its image path. Check the image's actual dimensions, cell dimensions, columns, margin, and spacing before calculating IDs or crops. Current resources are:

| Image | Dimensions | Current cells |
| --- | --- | --- |
| `mygame/sprites/environment_tilesheet.png` | 640 × 480 | 20 columns, 32 × 32 |
| `mygame/sprites/props_tilesheet.png` | 544 × 544 | 17 columns, 32 × 32 |
| `mygame/sprites/doors.png` | 416 × 64 | 13 columns, 32 × 32 |

These describe today's files, not a uniform-size requirement. Check current metadata after image edits; player animation frames are 64 × 64. `light_mask.png` is a separate future lighting asset, not a tile atlas.

Search [references/tiles.md](references/tiles.md) for the retained props atlas's vendor names and zero-based top-left `(row, column)` cells. That lookup covers only `props_tilesheet.png`; it cannot identify cells in the environment or doors atlases. Inspect those images and current Tiled tile definitions directly rather than inventing a corresponding name catalog.

Inspect candidate artwork, including transparent margins, before recommending a tile. Vendor categories describe appearance; they do not establish collision, class, walkability, or animation. Repeat-safety and variant notes are hints to check visually at the intended scale.

## Place room artwork in Tiled

Give the user the image/tileset, local tile ID, and row/column, with a brief visual description where useful. Derive local ID as `row * columns + column`; map-wide GIDs depend on the export's `firstgid` and flags and are not permanent art IDs.

Author placement, tile collision rectangles, classes, door pairs, mounted references, and light/pedestal offsets in Tiled, then re-export. Follow the current [authoring conventions](../../../README.md#author-and-preview-rooms-in-tiled). Use [tiled-json-audit](../tiled-json-audit/SKILL.md) for an export audit and [dragonruby-development](../dragonruby-development/SKILL.md) for runtime changes.

The manual Ruby tilesheet catalog, Prop factory/overrides, and collision playground have been removed. Do not recreate those paths or substitute hand-coded room placements for Tiled.

## Standalone DragonRuby crops

For artwork outside the Tiled room workflow, calculate bottom-left image crops from actual atlas metadata:

```text
source_x = margin + column * (cell_w + spacing)
source_y = image_h - margin - row * (cell_h + spacing) - cell_h
source_w = cell_w
source_h = cell_h
```

Source dimensions select artwork; destination dimensions scale its presentation. Preserve the accepted metadata sampling instead of assigning nearest-neighbor overrides. See [rendering terminology](../../../GLOSSARY.md#rendering) and the current [display and sampling decision](../../../docs/adr/0013-keep-hd-disabled.md).

`Descent::Sprite` still accepts a fixed `source_rect:` with `x/y/w/h` measured from the image's bottom-left. For example, the retained props cell `closed-stone-coffin` at row 6, column 14 is:

```ruby
Descent::Sprite.new(
  path: 'sprites/props_tilesheet.png',
  source_rect: { x: 448, y: 320, w: 32, h: 32 }
)
```

Verify the current cell before using this example. Fixed crops do not supply directional/animated artwork; the current Sprite rejects combining `source_rect` with animations or facing rows.

## Lookup maintenance

`mygame/sprites/main_32x32.json` is retained vendor metadata for the props layout, not runtime data or a catalog for every atlas. Its vendor file paths and occasional original source boxes are not repository crop coordinates; use its `row`/`column` fields and verify the image.

When the props atlas is rearranged, update or retire its lookup after comparing it with the actual artwork. No Ruby catalog or catalog-regression test remains. Preserve asset provenance/license material.
