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

## Runtime catalog and props

`mygame/app/tilesheet.rb` defines `Descent::Tilesheet::TILES`, a name-to-ID lookup for all 289 tiles. Ruby names replace hyphens with underscores. The names are stored in sheet order and converted to IDs when the file loads; a single 289-entry hash literal exceeds this DragonRuby runtime's operand limit. Keep their order aligned with the atlas.

Use `Tilesheet.source_rect(:closed_stone_coffin)` to calculate a bottom-left source rectangle, and `Tilesheet::PATH` for the image path. Unknown names raise `KeyError`.

Use `Prop.spawn(id: :closed_stone_coffin, x: 650, y: 290)` for a game prop. Any catalog name is accepted. `PROP_OVERRIDES` in `mygame/app/prop.rb` holds only per-id tuning: optional `scale` (default `1`) and `collider` dimensions in unscaled pixels. An omitted collider uses the full 32 × 32 cell; explicit `nil` makes a prop decorative. Scale applies to both artwork and collision. The default footprint is a tuning placeholder, not a measurement of the artwork.

For experimentation, edit `CollisionPlayground::PROP_PLACEMENTS` in `mygame/app/collision_playground.rb`. Saving placements, overrides, or the catalog rebuilds the playground props before collision and rendering, preserving the player and danger timers. Press **B** to show blue prop collider outlines. Existing props outside this playground do not automatically refresh their settings.

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
  path: Tilesheet::PATH,
  source_rect: Tilesheet.source_rect(:closed_stone_coffin)
)
```

The crop's width and height determine display size before scaling. Movement, facing changes, animation updates, and reset do not change a fixed crop. Props retain their `facing`, but this option does not provide directional artwork. Combining `source_rect` with `animations` or `facing_rows` raises `ArgumentError`; character sprites that omit `source_rect` keep their existing selection behavior. Use the dragonruby-development workflow for runtime integration.

## Source metadata and maintenance

`mygame/sprites/main_32x32.json` is the retained vendor atlas, not a runtime dependency. The compact reference preserves every tile's name, cell, category, repeat-safety, and supplied variant notes. Production bookkeeping and redundant pixel coordinates are omitted.

The JSON's `image`, `file`, and `filename` fields refer to vendor export paths, not repository assets. Its occasional `source_row`, `source_column`, and `source_box` fields describe earlier source artwork, not cells in this sheet. Use the catalog cells (the JSON's `row` and `column`) for cropping.

If replacing the sheet, verify image dimensions and atlas positions, then update the Ruby catalog, tile reference, and this guidance together. Run `bash scripts/run.sh --test tests/all_test.rb`; the catalog test checks every Ruby name and rectangle against the retained JSON. The game does not load the JSON at runtime. Retain supplied provenance/license material alongside the original assets.
