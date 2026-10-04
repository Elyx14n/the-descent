# frozen_string_literal: true

require 'app/tilesheet'

def test_tilesheet_catalog_matches_every_vendor_atlas_cell(args, assert)
  atlas = args.gtk.parse_json_file('sprites/main_32x32.json')
  assert.equal! Descent::Tilesheet::TILES.length, atlas['count']
  assert.equal! Descent::Tilesheet::TILES.values.uniq.length, atlas['count']
  assert.equal! Descent::Tilesheet::TILE_SIZE, atlas['tile_size']
  assert.equal! Descent::Tilesheet::COLUMNS, atlas['columns']
  assert.equal! Descent::Tilesheet::ROWS, atlas['rows']
  image_height = atlas['rows'] * atlas['tile_size']

  atlas['items'].each do |tile|
    name = tile['name'].tr('-', '_').to_sym
    assert.equal! Descent::Tilesheet::TILES.fetch(name), tile['id']
    assert.equal! Descent::Tilesheet.source_rect(name), {
      x: tile['x'], y: image_height - tile['y'] - tile['height'],
      w: tile['width'], h: tile['height']
    }
  end
end
