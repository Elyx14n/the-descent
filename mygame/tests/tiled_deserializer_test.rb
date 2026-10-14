# frozen_string_literal: true

require 'tests/support/room_helpers'

class TiledDeserializerTests
  include RoomTestHelpers

  def test_deserializer_assigns_a_canonical_type_to_every_scenery_entry_and_sprite(args, assert)
    room = tiled_test_room(args)
    assert.equal! room.ground.map { |sprite| sprite[:type] }.uniq, [:ground]
    assert.equal! room.floor_details.map { |entry| entry[:type] }.uniq, [:floor_detail]
    assert.equal! room.ceiling.map { |sprite| sprite[:type] }.uniq.sort, %i[ceiling door]
    assert.equal! room.objects.map { |entry| entry[:type] }.uniq.sort, %i[door light pedestal wall]
    (room.objects + room.floor_details).each do |entry|
      assert.equal! entry[:type], entry[:sprite][:type]
      assert.false! entry.key?(:kind)
      assert.false! entry.key?(:layer)
    end
    room.doors.each do |door|
      door[:parts].each do |part|
        assert.equal! part.values_at(:sprite, :open_sprite, :closed_sprite).map { |sprite| sprite[:type] },
                      %i[door door door]
      end
    end
  end

  def test_type_resolution_uses_object_class_then_tile_class_then_layer_default(args, assert)
    data = tiled_test_map(args)
    object = data['layers'].find { |layer| layer['name'] == 'Props' }['objects'].find { |entry| entry['id'] == 6 }
    # Modern object class takes precedence over legacy type and inherited Light.
    object['class'] = 'Prop'
    room = tiled_test_room(args, data)
    assert.equal! room.objects.find { |entry| entry[:id] == 6 }[:type], :prop
    assert.false!(room.lights.any? { |entry| entry[:id] == 6 })
    object['class'] = ''
    object['type'] = 'Prop'
    assert.equal! tiled_test_room(args, data).objects.find { |entry| entry[:id] == 6 }[:type], :prop
    object.delete('class')
    object['type'] = ''
    assert.equal! tiled_test_room(args, data).objects.find { |entry| entry[:id] == 6 }[:type], :light
    object['gid'] = 302 # Unclassified props tile, with no inherited class.
    assert.equal! tiled_test_room(args, data).objects.find { |entry| entry[:id] == 6 }[:type], :prop
  end

  def test_import_rejects_unknown_classes_and_unsupported_class_layer_combinations(args, assert)
    data = tiled_test_map(args)
    wall = data['layers'].find { |layer| layer['name'] == 'Walls' }['objects'].first
    wall['type'] = 'Typo'
    assert.true! tiled_test_error(args, data).include?('Unknown tile class "Typo" on Walls')
    wall['type'] = 'Light'
    assert.true! tiled_test_error(args, data).include?('Type light is not supported on Walls')
    wall['class'] = 123
    assert.true! tiled_test_error(args, data).include?('Unknown tile class 123 on Walls')
  end

  def test_modern_tile_classes_normalize_door_variants_and_caps(args, assert)
    data = tiled_test_map(args)
    tiles = data['tilesets'].find { |tileset| tileset['name'] == 'doors' }['tiles']
    tiles.each { |tile| tile['class'] = tile.delete('type') }
    room = tiled_test_room(args, data)
    room.doors.each do |door|
      room.set_door_open(door[:id], open: true)
      assert.equal! door[:type], :door
      assert.true!(door[:parts].all? { |part| part[:sprite][:type] == :door })
    end
  end

  def test_deserializer_returns_independent_data_and_does_not_mutate_the_export(args, assert)
    data = tiled_test_map(args)
    before = data.to_s
    first = Descent::TiledDeserializer.deserialize(data, path: 'tiled/ritual_gate.json',
                                                         image_loader: ->(image) { args.gtk.get_pixels(image) })
    second = Descent::TiledDeserializer.deserialize(data, path: 'tiled/ritual_gate.json',
                                                          image_loader: ->(image) { args.gtk.get_pixels(image) })
    assert.true! first.is_a?(Hash)
    assert.equal! data.to_s, before
    room = Descent::Room.new(**first)
    room.set_door_open(218, open: true)
    other = Descent::Room.new(**second)
    assert.false! other.doors.find { |door| door[:id] == 218 }[:open]
    assert.false! room.objects.first[:sprite].equal?(other.objects.first[:sprite])
    assert.equal! data.to_s, before
  end

  def test_deserializer_load_reads_the_export_without_constructing_a_room(args, assert)
    decoded = Descent::TiledDeserializer.load(args.gtk, path: 'tiled/ritual_gate.json')
    assert.true! decoded.is_a?(Hash)
    assert.equal! Descent::Room.new(**decoded).spawn, { x: 176, y: 176, facing: :south }
    invalid = tiled_test_map(args)
    invalid['type'] = 'tileset'
    assert.true! tiled_test_error(args, invalid).start_with?('tiled/ritual_gate.json:')
  end

  def test_tiled_export_loads_spawn_artwork_and_gameplay_metadata(args, assert)
    room = tiled_test_room(args)
    assert.equal! room.bounds, { x: 0, y: 0, w: 352, h: 384 }
    assert.equal! room.spawn, { x: 176, y: 176, facing: :south }
    assert.equal! [room.ground.length, room.floor_details.length, room.ceiling.length, room.doors.length,
                   room.lights.length, room.pedestals.length], [71, 1, 26, 4, 6, 4]
    assert.equal! room.collision_rects.length, 54
    assert.true!(room.objects.all? { |entry| entry[:type] != :spawn })
    assert.true!(room.floor_details.any? { |entry| entry[:id] == 161 })
    assert.false!(room.objects.any? { |entry| entry[:id] == 161 })
    assert.true!(room.ground.any? { |sprite| sprite[:path] == 'sprites/doors.png' })
    assert.true!(room.objects.any? { |entry| entry[:sprite][:path] == 'sprites/environment_tilesheet.png' })
    assert.true!(room.objects.any? { |entry| entry[:sprite][:path] == 'sprites/props_tilesheet.png' })
  end

  def test_tiled_light_offsets_follow_scale_flip_and_instance_properties(args, assert)
    room = tiled_test_room(args)
    lamp = room.lights.find { |light| light[:id] == 6 }
    assert.equal! lamp.values_at(:x, :y), [240, 260]
    assert.equal! lamp.values_at(:radius, :intensity, :color), [0, 0, '']
    small = room.lights.find { |light| light[:id] == 121 }
    mirrored = room.lights.find { |light| light[:id] == 122 }
    assert.equal! small.values_at(:x, :y), [271.5, 311]
    assert.equal! mirrored.values_at(:x, :y), [80.5, 311]
  end

  def test_pedestal_item_positions_follow_authored_offsets_scaling_and_flips(args, assert)
    room = tiled_test_room(args)
    assert.equal! room.pedestals.map { |entry| entry[:id] }, [2, 3, 4, 5]
    assert.equal! room.pedestals.map { |entry| entry[:item_position] },
                  [{ x: 199, y: 211.25 }, { x: 199, y: 163.25 },
                   { x: 153, y: 163.25 }, { x: 153, y: 211.25 }]
    assert.true!(room.pedestals.all? { |entry| room.objects.any? { |object| object.equal?(entry) } })

    data = tiled_test_map(args)
    pedestal = data['layers'].find { |layer| layer['name'] == 'Props' }['objects'].find { |entry| entry['id'] == 4 }
    pedestal['width'] = 64
    pedestal['height'] = 64
    pedestal['gid'] |= Descent::TiledDeserializer::VERTICAL
    pedestal['properties'].find { |prop| prop['name'] == 'offset_x' }['value'] = 10
    pedestal['properties'].find { |prop| prop['name'] == 'offset_y' }['value'] = 4
    moved = tiled_test_room(args, data).pedestals.find { |entry| entry[:id] == 4 }
    assert.equal! moved[:item_position], { x: 180, y: 148 }
  end

  def test_door_lock_uses_tile_default_and_placed_object_override(args, assert)
    data = tiled_test_map(args)
    east = data['layers'].find { |layer| layer['name'] == 'Props' }['objects'].find { |entry| entry['id'] == 216 }
    east['properties'].reject! { |prop| prop['name'] == 'locked' }
    tile = data['tilesets'].find { |tileset| tileset['name'] == 'doors' }['tiles'].find { |entry| entry['id'] == 10 }
    tile['properties'].find { |prop| prop['name'] == 'locked' }['value'] = true
    player = Descent::Player.new(x: 312, y: 176)
    room = tiled_test_room(args, data)
    room.toggle_nearest_door(point: { x: player.x, y: player.y }, collision_rect: player.collision_rect)
    assert.false! room.doors.find { |door| door[:id] == 216 }[:open]

    east['properties'] << { 'name' => 'locked', 'type' => 'bool', 'value' => false }
    room = tiled_test_room(args, data)
    room.toggle_nearest_door(point: { x: player.x, y: player.y }, collision_rect: player.collision_rect)
    assert.true! room.doors.find { |door| door[:id] == 216 }[:open]

    east['properties'].reject! { |prop| prop['name'] == 'locked' }
    tile['properties'].reject! { |prop| prop['name'] == 'locked' }
    room = tiled_test_room(args, data)
    room.toggle_nearest_door(point: { x: player.x, y: player.y }, collision_rect: player.collision_rect)
    assert.true! room.doors.find { |door| door[:id] == 216 }[:open]
  end

  def test_tiled_scaled_flipped_colliders_and_multiple_wall_shapes(args, assert)
    room = tiled_test_room(args)
    # Source rectangle (8.125,25.875,15,4), rendered at 32x24 rather than 32x32.
    assert.true! room.collision_rects.include?({ x: 192.125, y: 189.59375, w: 15, h: 3 })
    assert.true! room.collision_rects.include?({ x: 144.875, y: 189.59375, w: 15, h: 3 })
    # Both rectangles of the upper-right step survive deserialization.
    [{ x: 256, y: 288, w: 32, h: 6 }, { x: 256, y: 288, w: 6, h: 32 }].each do |rect|
      assert.true! room.collision_rects.include?(rect)
    end
  end

  def test_mounted_candle_can_move_on_the_ledge_without_retuning_sorting(args, assert)
    original = tiled_test_room(args)
    data = tiled_test_map(args)
    candle = data['layers'].find { |layer| layer['name'] == 'Props' }['objects'].find { |entry| entry['id'] == 121 }
    candle['y'] -= 8
    moved = tiled_test_room(args, data)
    before = original.objects.find { |entry| entry[:id] == 121 }
    after = moved.objects.find { |entry| entry[:id] == 121 }
    assert.equal! after[:depth], before[:depth]
    assert.equal! after[:sprite][:y], before[:sprite][:y] + 8
    assert.equal! moved.collision_rects, original.collision_rects
    assert.equal! moved.lights.find { |entry| entry[:id] == 121 }[:y],
                  original.lights.find { |entry| entry[:id] == 121 }[:y] + 8
  end

  def test_mounted_on_empty_defaults_and_prop_references(args, assert)
    data = tiled_test_map(args)
    original = tiled_test_room(args, data)
    floor_lamp = original.objects.find { |entry| entry[:id] == 6 }
    assert.equal! floor_lamp[:properties]['mounted_on'], 0
    assert.false! floor_lamp.key?(:mounted_on)
    pedestal = data['layers'].find { |layer| layer['name'] == 'Props' }['objects'].find { |entry| entry['id'] == 2 }
    pedestal['properties'] << { 'name' => 'mounted_on', 'type' => 'object', 'value' => 117 }
    room = tiled_test_room(args, data)
    assert.equal! room.pedestals.find { |entry| entry[:id] == 2 }[:mounted_on], 117
    assert.equal! room.collision_rects, original.collision_rects
  end

  def test_mounted_on_rejects_missing_and_non_wall_targets(args, assert)
    [9999, 121, 6, 161].each do |target|
      data = tiled_test_map(args)
      candle = data['layers'].find { |layer| layer['name'] == 'Props' }['objects'].find { |entry| entry['id'] == 121 }
      candle['properties'].find { |prop| prop['name'] == 'mounted_on' }['value'] = target
      assert.true! tiled_test_error(args, data).include?("mounted_on target #{target}")
    end
  end

  def test_tiled_rejects_missing_spawn_invalid_gids_and_broken_door_pairs(args, assert)
    data = tiled_test_map(args)
    props = data['layers'].find { |layer| layer['name'] == 'Props' }
    props['objects'].reject! { |object| object['point'] }
    assert.true! tiled_test_error(args, data).include?('exactly one point')
    data = tiled_test_map(args)
    data['layers'].first['data'][0] = 9999
    assert.true! tiled_test_error(args, data).include?('Invalid tile ID')
    data = tiled_test_map(args)
    door_tiles = data['tilesets'].find { |tileset| tileset['name'] == 'doors' }['tiles']
    door_tiles.find { |tile| tile['id'] == 2 }['properties'].find { |prop| prop['name'] == 'close_tile' }['value'] = 0
    assert.true! tiled_test_error(args, data).include?('Inconsistent Door pair')
  end
end
