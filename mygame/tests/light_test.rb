# frozen_string_literal: true

require 'tests/support/room_helpers'

class LightTests
  include RoomTestHelpers

  def light_object(data, id = 6)
    data['layers'].find { |layer| layer['name'] == 'Props' }['objects'].find { |entry| entry['id'] == id }
  end

  def light_tiles(data)
    data['tilesets'].find { |tileset| tileset['image'] == '../sprites/lights.png' }['tiles']
  end

  def test_light_defaults_and_object_overrides_share_scenery_state(args, assert)
    data = tiled_test_map(args)
    object = light_object(data)
    tile = light_tiles(data).find { |entry| entry['id'] == 36 }
    object['properties'].reject! { |prop| prop['name'] == 'enabled' }
    tile['properties'].find { |prop| prop['name'] == 'enabled' }['value'] = false
    room = tiled_test_room(args, data)
    light = room.lights.find { |entry| entry[:id] == 6 }
    assert.true! room.objects.find { |entry| entry[:id] == 6 }.equal?(light)
    assert.false! light[:enabled]
    assert.equal! light[:sprite].values_at(:source_x, :source_y), [0, 0]
    object['properties'] << { 'name' => 'enabled', 'type' => 'bool', 'value' => true }
    assert.true! tiled_test_room(args, data).lights.find { |entry| entry[:id] == 6 }[:enabled]
    object['properties'].reject! { |prop| prop['name'] == 'enabled' }
    tile['properties'].reject! { |prop| prop['name'] == 'enabled' }
    assert.true!(tiled_test_room(args, data).lights.all? { |entry| entry[:enabled] })
  end

  def test_flames_follow_supplied_tick_boundaries_and_loop_without_a_clock(args, assert)
    room = tiled_test_room(args)
    floor = room.lights.find { |entry| entry[:id] == 6 }
    mounted = room.lights.find { |entry| entry[:id] == 121 }
    [[0, 32], [8, 32], [9, 64], [17, 64], [18, 96], [27, 128], [35, 128], [36, 32]].each do |tick, x|
      room.update_animations(tick: tick)
      assert.equal! floor[:sprite].values_at(:source_x, :source_y), [x, 0]
      assert.equal! mounted[:sprite].values_at(:source_x, :source_y), [x, 224]
      before = mounted[:sprite].dup
      room.update_animations(tick: tick)
      room.render_data
      assert.equal! mounted[:sprite], before
    end
    room.update_animations(tick: 9) # The consumer can rewind or skip time.
    assert.equal! floor[:sprite][:source_x], 64
  end

  def test_disabled_light_stays_static_and_reenables_at_current_frame(args, assert)
    room = tiled_test_room(args)
    light = room.lights.find { |entry| entry[:id] == 6 }
    sprite = light[:sprite]
    source = light.values_at(:x, :y, :radius, :intensity, :color)
    collision = room.collision_rects
    assert.true! room.set_light_enabled(6, enabled: false).equal?(light)
    [9, 18, 27].each do |tick|
      room.update_animations(tick: tick)
      assert.equal! sprite, light[:unlit_sprite]
    end
    assert.false! light[:enabled]
    room.set_light_enabled(6, enabled: true)
    assert.equal! sprite[:source_x], 128
    assert.true! light[:sprite].equal?(sprite)
    assert.equal! room.collision_rects, collision
    assert.equal! light.values_at(:x, :y, :radius, :intensity, :color), source
    begin
      room.set_light_enabled(9999, enabled: true)
      assert.true! false
    rescue ArgumentError => e
      assert.equal! e.message, 'Unknown light object 9999'
    end
  end

  def test_candelabra_bases_block_movement_in_both_light_states(args, assert)
    room = tiled_test_room(args)
    [6, 7, 8, 9].each do |id|
      light = room.lights.find { |entry| entry[:id] == id }
      base = { x: light[:sprite][:x] + 11, y: light[:sprite][:y] + 2, w: 10, h: 4 }
      assert.equal! light[:colliders], [base]
      assert.true! room.collision_rects.include?(base)
    end
    player = Descent::Player.new(x: 240, y: 220)
    input = { dx: 0, dy: 1, sneak: false, toggle_lamp: false }
    20.times { player.update_controls(input, walls: room.collision_rects) }
    assert.equal! player.y, 232
    room.set_light_enabled(6, enabled: false)
    room.update_animations(tick: 18)
    10.times { player.update_controls(input, walls: room.collision_rects) }
    assert.equal! player.y, 232
    room.set_light_enabled(6, enabled: true)
    10.times { player.update_controls(input, walls: room.collision_rects) }
    assert.equal! player.y, 232
  end

  def test_animation_and_unlit_variants_preserve_mounted_flipped_scaled_sprites(args, assert)
    data = tiled_test_map(args)
    object = light_object(data, 122)
    object['gid'] |= Descent::TiledDeserializer::VERTICAL
    object['opacity'] = 0.5
    room = tiled_test_room(args, data)
    light = room.lights.find { |entry| entry[:id] == 122 }
    sprite = light[:sprite]
    keys = %i[x y w h a flip_horizontally flip_vertically type]
    placement = sprite.values_at(*keys)
    unit = room.fade_units.find { |entry| entry[:sprites].any? { |member| member.equal?(sprite) } }
    assert.true! unit.is_a?(Hash)
    assert.equal! placement.last(3), [true, true, :light]
    bounds = []
    [0, 9, 18, 27].each do |tick|
      room.update_animations(tick: tick)
      assert.equal! sprite, light[:lit_sprite]
      assert.equal! sprite.values_at(*keys), placement
      bounds << sprite[:occlusion_bounds]
    end
    room.set_light_enabled(122, enabled: false)
    assert.equal! sprite, light[:unlit_sprite]
    assert.equal! sprite.values_at(*keys), placement
    assert.true!(bounds.any? { |rect| rect != sprite[:occlusion_bounds] })
    wall = room.objects.find { |entry| entry[:id] == 118 }
    assert.equal! light[:depth], wall[:depth]
    assert.true!(wall[:mounted_objects].any? { |entry| entry.equal?(light) })
    assert.true!(unit[:sprites].any? { |member| member.equal?(sprite) })
  end

  def test_animation_supports_unequal_and_fractional_tick_durations(args, assert)
    data = tiled_test_map(args)
    animation = light_tiles(data).find { |entry| entry['id'] == 36 }['animation']
    durations = [125, 50, 100, 125]
    animation.each_with_index { |frame, index| frame['duration'] = durations[index] }
    room = tiled_test_room(args, data)
    light = room.lights.find { |entry| entry[:id] == 6 }
    [[7, 32], [8, 64], [10, 64], [11, 96], [16, 96], [17, 128], [23, 128], [24, 32]].each do |tick, x|
      room.update_animations(tick: tick)
      assert.equal! light[:sprite][:source_x], x
    end
  end

  def test_light_loads_are_independent_and_do_not_mutate_the_export(args, assert)
    data = tiled_test_map(args)
    before = data.to_s
    first = tiled_test_room(args, data)
    other = tiled_test_room(args, data)
    first.set_light_enabled(6, enabled: false)
    first.update_animations(tick: 18)
    assert.true!(other.lights.all? { |entry| entry[:enabled] && entry[:sprite][:source_x] == 32 })
    assert.equal! data.to_s, before
  end

  def test_import_rejects_invalid_light_variants_and_animation(args, assert)
    [nil, -1, 40, '35', 36].each do |id|
      data = tiled_test_map(args)
      prop = light_object(data)['properties'].find { |entry| entry['name'] == 'unlit_id' }
      prop['value'] = id
      error = tiled_test_error(args, data)
      assert.true! error.start_with?('tiled/ritual_gate.json:')
      assert.true! error.include?(id == 36 ? 'static tile' : 'Invalid tile ID')
    end
    [nil, []].each do |animation|
      data = tiled_test_map(args)
      light_tiles(data).find { |entry| entry['id'] == 36 }['animation'] = animation
      assert.true! tiled_test_error(args, data).include?('animated lit Light')
    end
    [0, -1, nil, '150'].each do |duration|
      data = tiled_test_map(args)
      light_tiles(data).find { |entry| entry['id'] == 36 }['animation'].first['duration'] = duration
      assert.true! tiled_test_error(args, data).include?('positive milliseconds')
    end
    data = tiled_test_map(args)
    light_tiles(data).find { |entry| entry['id'] == 36 }['animation'].first['tileid'] = 40
    assert.true! tiled_test_error(args, data).include?('Invalid tile ID')
    data = tiled_test_map(args)
    light_object(data)['properties'].find { |entry| entry['name'] == 'enabled' }['value'] = 1
    assert.true! tiled_test_error(args, data).include?('enabled must be boolean')
  end

  def interaction_room(args, door_first: false)
    data = tiled_test_map(args)
    light_object(data).merge!('x' => 160, 'y' => 100)
    objects = data['layers'].find { |layer| layer['name'] == 'Props' }['objects']
    gate = objects.find { |entry| entry['id'] == 218 }
    objects.unshift(objects.delete(gate)) if door_first
    tiled_test_room(args, data)
  end

  def test_nearest_target_compares_doors_and_lights_and_consumes_blocked_presses(args, assert)
    room = interaction_room(args)
    light = room.lights.find { |entry| entry[:id] == 6 }
    player = Descent::Player.new(x: 176, y: 310)
    room.toggle_nearest_interactable(point: { x: player.x, y: player.y }, collision_rect: player.collision_rect)
    assert.false! light[:enabled] # Light is nearer than the locked gate.
    room.set_light_enabled(6, enabled: true)
    player.y = 319
    room.toggle_nearest_interactable(point: { x: player.x, y: player.y }, collision_rect: player.collision_rect)
    assert.true! light[:enabled] # Gate is nearer and locked; no redirect to light.
    gate = room.doors.find { |entry| entry[:id] == 218 }
    gate[:properties]['locked'] = false
    room.set_door_open(218, open: true)
    player.y = 321
    room.toggle_nearest_interactable(point: { x: player.x, y: player.y }, collision_rect: player.collision_rect)
    assert.true! gate[:open] # Closing would overlap the player's feet.
    assert.true! light[:enabled]
  end

  def test_interaction_ties_follow_authored_order(args, assert)
    player = Descent::Player.new(x: 176, y: 318)
    [false, true].each do |door_first|
      room = interaction_room(args, door_first: door_first)
      room.toggle_nearest_interactable(point: { x: player.x, y: player.y }, collision_rect: player.collision_rect)
      assert.equal! room.lights.find { |entry| entry[:id] == 6 }[:enabled], door_first
    end
  end

  def test_light_interaction_uses_sprite_rectangle_and_inclusive_reach(args, assert)
    room = tiled_test_room(args)
    light = room.lights.find { |entry| entry[:id] == 6 }
    player = Descent::Player.new(x: 240, y: 207) # Sprite bottom is 232: 25 pixels away.
    input = { dx: 0, dy: 0, sneak: false, interact: true }
    player.update(input, room: room)
    assert.true! light[:enabled]
    player.y = 208
    player.update(input, room: room)
    assert.false! light[:enabled]
    player.sanity = 0
    player.update(input, room: room)
    assert.false! light[:enabled]
  end
end
