---
name: tilesheet
description: Find and select existing cathedral tiles from The Descent tilesheet and translate atlas cells into DragonRuby sprite crops. Use when choosing environment art, props, or effects from mygame/sprites/tilesheet.png.
---

# Cathedral tilesheet

## Find a tile

- Image: `mygame/sprites/tilesheet.png`; runtime path: `sprites/tilesheet.png`.
- Cursed Gothic Cathedral Pixel Tileset Pack, version 1.2.0.
- 544 × 544 pixels, 17 columns × 17 rows, 32 × 32 pixels per cell, no gutters.
- Search [references/tiles.md](references/tiles.md) for tile names, categories, and zero-based `(row, column)` cells. Rows run top to bottom; columns run left to right.
- Inspect the image when choosing art: names and categories describe appearance, not collision, walkability, damage, or other game rules.
- Only `seamless-surface` entries are marked repeat-safe by the supplied atlas. Check seams visually at the intended scale; architecture, props, and effects are not marked repeat-safe.
- Effect variants are not declared animation sequences. Do not infer playback order or timing from adjacent cells.

## Crop in DragonRuby

For a catalog cell `(row, column)`, use:

```ruby
{
  path: 'sprites/tilesheet.png',
  x: x, y: y, w: 32 * scale, h: 32 * scale,
  source_x: column * 32,
  source_y: (16 - row) * 32,
  source_w: 32, source_h: 32,
  scale_quality_enum: 0
}
```

`source_y` counts from the bottom of the image. For example, `worn-flagstone` at `(0, 0)` uses `(source_x: 0, source_y: 512)`; `red-spikes-tall` at `(16, 16)` uses `(512, 0)`. Keep source size at 32 × 32 when changing display scale. Prefer integer display scales for crisp pixels.

`Descent::Sprite` accepts a fixed `source_rect:` in bottom-left image pixel coordinates:

```ruby
Sprite.new(
  path: 'sprites/tilesheet.png',
  source_rect: { x: column * 32, y: (16 - row) * 32, w: 32, h: 32 }
)
```

The crop's width and height determine display size before scaling. Movement, facing changes, animation updates, and reset do not change a fixed crop. Props retain their `facing`, but this option does not provide directional artwork. Combining `source_rect` with `animations` or `facing_rows` raises `ArgumentError`; character sprites that omit `source_rect` keep their existing selection behavior. Use the dragonruby-development workflow for runtime integration.

## Source metadata and maintenance

`mygame/sprites/main_32x32.json` is the retained vendor atlas, not a runtime dependency. The compact reference preserves every tile's name, cell, category, repeat-safety, and supplied variant notes. Production bookkeeping and redundant pixel coordinates are omitted.

The JSON's `image`, `file`, and `filename` fields refer to vendor export paths, not repository assets. Its occasional `source_row`, `source_column`, and `source_box` fields describe earlier source artwork, not cells in this sheet. Use the catalog cells (the JSON's `row` and `column`) for cropping.

If replacing the sheet, verify image dimensions and atlas positions, then update the catalog and this guidance together. Retain supplied provenance/license material alongside the original assets.
