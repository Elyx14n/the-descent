# frozen_string_literal: true

require 'tests/support/room_helpers'

class TiledOpacityTests
  include RoomTestHelpers

  def test_alpha_bounds_reject_padding_follow_scale_and_flips_and_keep_empty_tiles_empty(args, assert)
    data = tiled_test_map(args)
    images = opacity_test_images(data)
    image = images.fetch('sprites/environment_tilesheet.png')
    # Wall tile 20 starts at atlas row 32. Even alpha=1 contributes to its bounds.
    (5...8).each do |row|
      (2...5).each { |column| image[:pixels][((32 + row) * image[:w]) + column] = 0x01000000 }
    end
    object = data['layers'].find { |layer| layer['name'] == 'Walls' }['objects'].find { |entry| entry['id'] == 193 }
    object['width'] = 64
    object['height'] = 48
    object['gid'] |= Descent::TiledDeserializer::HORIZONTAL | Descent::TiledDeserializer::VERTICAL
    reads = []
    image_loader = lambda do |path|
      reads << path
      images.fetch(path)
    end
    decoded = Descent::TiledDeserializer.deserialize(data, path: 'tiled/ritual_gate.json', image_loader: image_loader)
    wall = decoded[:collections][:objects].find { |entry| entry[:id] == 193 }[:sprite]
    assert.equal! wall[:occlusion_bounds], { x: 2, y: 24, w: 3, h: 3 }
    assert.equal! Descent::ForegroundFade.visible_bounds(wall), { x: 54, y: 103.5, w: 6, h: 4.5 }
    empty = decoded[:collections][:objects].find { |entry| entry[:id] == 166 }[:sprite]
    assert.true! empty.key?(:occlusion_bounds)
    assert.equal! Descent::ForegroundFade.visible_bounds(empty), nil
    assert.equal! reads.sort, images.keys.sort # Each atlas is loaded once despite repeated tiles and door variants.

    image[:pixels].fill(0)
    reloaded = Descent::TiledDeserializer.deserialize(data, path: 'tiled/ritual_gate.json',
                                                            image_loader: ->(path) { images.fetch(path) })
    assert.equal! reloaded[:collections][:objects].find { |entry| entry[:id] == 193 }[:sprite][:occlusion_bounds], nil
    assert.equal! wall[:occlusion_bounds], { x: 2, y: 24, w: 3, h: 3 }
  end

  def test_door_variants_replace_visible_bounds_without_changing_the_supporting_footprint(args, assert)
    room = tiled_test_room(args)
    [216, 217].each do |id|
      door = room.doors.find { |entry| entry[:id] == id }
      sprite = door[:sprite]
      unit = room.fade_units.find { |candidate| candidate[:base].equal?(sprite) }
      footprint = unit[:footprint].dup
      closed = sprite[:occlusion_bounds].dup
      assert.equal! closed[:w], 6
      room.set_door_open(id, open: true)
      assert.true! sprite.equal?(unit[:base])
      assert.equal! sprite[:occlusion_bounds][:w], 32
      assert.equal! unit[:footprint], footprint
      room.set_door_open(id, open: false)
      assert.equal! sprite[:occlusion_bounds], closed
    end
  end

  def test_unreadable_atlas_fails_during_deserialization(args, assert)
    error = nil
    begin
      Descent::TiledDeserializer.deserialize(tiled_test_map(args), path: 'tiled/ritual_gate.json',
                                                                   image_loader: ->(_path) {})
    rescue ArgumentError => e
      error = e.message
    end
    assert.true! error&.include?('Cannot read tile image:')
  end

  private

  def opacity_test_images(data)
    images = {}
    data['tilesets'].each do |tileset|
      w, h = tileset.values_at('imagewidth', 'imageheight')
      images["sprites/#{tileset['image'].split('/').last}"] = { w: w, h: h, pixels: Array.new(w * h, 0) }
    end
    images
  end
end
