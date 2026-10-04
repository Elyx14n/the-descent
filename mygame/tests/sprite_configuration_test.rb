# frozen_string_literal: true

require 'app/sprite'

def test_sprite_rejects_missing_or_competing_image_sources(_args, assert)
  animations = {
    idle: { path: 'sprites/enemy.png', frame_count: 4, ticks_per_frame: 12, loop: true }
  }
  invalid_settings = [
    [{ path: 'sprites/tilesheet.png', animations: animations }, 'path cannot be combined with animations'],
    [{}, 'path or animations must be provided'],
    [{ source_rect: { x: 0, y: 0, w: 32, h: 32 } }, 'path or animations must be provided'],
    [{ facing_rows: { south: 0 } }, 'path or animations must be provided']
  ]

  invalid_settings.each do |settings, message|
    error = nil
    begin
      Descent::Sprite.new(**settings)
    rescue ArgumentError => e
      error = e
    end
    assert.true! error.is_a?(ArgumentError)
    assert.equal! error.message, message
  end
end

def test_static_path_supports_default_crop_and_facing_rows(_args, assert)
  sprite = Descent::Sprite.new(path: 'sprites/enemy.png')
  primitive = sprite.to_primitive(x: 0, y: 0)
  assert.equal! primitive[:path], 'sprites/enemy.png'
  assert.equal! [primitive[:source_x], primitive[:source_y]], [0, 0]
  assert.equal! [primitive[:source_w], primitive[:source_h]], [32, 32]

  sprite = Descent::Sprite.new(
    path: 'sprites/enemy.png', frame_size: 64,
    facing_rows: { south: 0, west: 1, north: 2, east: 3 }
  )
  { south: 192, west: 128, north: 64, east: 0 }.each do |facing, source_y|
    primitive = sprite.to_primitive(x: 0, y: 0, facing: facing)
    assert.equal! primitive[:path], 'sprites/enemy.png'
    assert.equal! [primitive[:source_x], primitive[:source_y]], [0, source_y]
    assert.equal! [primitive[:source_w], primitive[:source_h]], [64, 64]
  end
end
