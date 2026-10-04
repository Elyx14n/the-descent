# frozen_string_literal: true

require 'app/prop'

def test_prop_crop_survives_facing_movement_animation_updates_and_reset(_args, assert)
  prop = Descent::Prop.new(
    type: :stone_coffin, x: 100, y: 200, scale: 3,
    sprite: Descent::Sprite.new(
      path: 'sprites/tilesheet.png', source_rect: { x: 448, y: 320, w: 32, h: 32 }
    ),
    collider: nil
  )

  %i[north south east west].each do |facing|
    prop.reset(x: prop.x + 10, y: prop.y + 20, facing: facing)
    prop.update_animation(:idle)
    primitive = prop.sprite_to_primitive
    assert.equal! prop.facing, facing
    assert.equal! primitive[:path], 'sprites/tilesheet.png'
    assert.equal! [primitive[:source_x], primitive[:source_y]], [448, 320]
    assert.equal! [primitive[:source_w], primitive[:source_h]], [32, 32]
    assert.equal! [primitive[:x], primitive[:y]], [prop.x, prop.y]
    assert.equal! [primitive[:w], primitive[:h]], [96, 96]
  end
end

def test_crop_dimensions_scale_without_changing_source_or_foot_anchor(_args, assert)
  sprite = Descent::Sprite.new(
    path: 'sprites/tilesheet.png', foot_padding: 2,
    source_rect: { x: 0, y: 0, w: 16, h: 32 }
  )

  [1, 3].each do |scale|
    primitive = sprite.to_primitive(x: 100, y: 200, scale: scale)
    assert.equal! [primitive[:source_x], primitive[:source_y]], [0, 0]
    assert.equal! [primitive[:source_w], primitive[:source_h]], [16, 32]
    assert.equal! [primitive[:w], primitive[:h]], [16 * scale, 32 * scale]
    assert.equal! primitive[:y] + (2 * scale), 200
    assert.equal! [primitive[:anchor_x], primitive[:anchor_y]], [0.5, 0]
  end
end

def test_fixed_crop_rejects_conflicting_cell_selection(_args, assert)
  [{ animations: {} }, { path: 'sprites/tilesheet.png', facing_rows: { south: 0 } }].each do |settings|
    error = nil
    begin
      Descent::Sprite.new(source_rect: { x: 0, y: 0, w: 32, h: 32 }, **settings)
    rescue ArgumentError => e
      error = e
    end
    assert.true! error.is_a?(ArgumentError)
    assert.equal! error.message, 'source_rect cannot be combined with animations or facing_rows'
  end
end
