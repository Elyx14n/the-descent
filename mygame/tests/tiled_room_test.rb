# frozen_string_literal: true

require 'app/room_scene'

def tiled_test_map(args)
  args.gtk.parse_json_file('tiled/ritual_gate.json')
end

def tiled_test_room(args, data = nil)
  Descent::TiledRoom.new(data || tiled_test_map(args), path: 'tiled/ritual_gate.json').load
end

def tiled_test_error(data)
  Descent::TiledRoom.new(data, path: 'tiled/ritual_gate.json').load
  nil
rescue ArgumentError => e
  e.message
end

def clear_room_test_outputs(args)
  args.outputs.primitives.clear
  args.outputs.borders.clear
  args.outputs[Descent::Camera::TARGET].primitives.clear
  args.outputs[Descent::Camera::TARGET].borders.clear
end

def test_direct_render_comparison_preserves_world_placement_and_drawing_order(args, assert)
  args.state.room_scene = { show_bounds: false }
  Descent::RoomScene.reload(args)
  player = args.state.player
  args.state.room_scene[:camera].follow(x: player.x, y: player.y)
  clear_room_test_outputs(args)
  Descent::RoomScene.render(args)
  expected = args.outputs[Descent::Camera::TARGET].primitives.flatten
  args.state.room_scene[:direct_render] = true
  clear_room_test_outputs(args)
  Descent::RoomScene.render(args)
  drawn = args.outputs.primitives.flatten.reject { |primitive| primitive[:text] }
  assert.equal! drawn, expected
  assert.false!(drawn.any? { |primitive| primitive[:path] == Descent::Camera::TARGET })
  assert.equal! player.sprite_to_primitive[:w], 64
  args.state.room_scene[:direct_render] = false
end

def test_nearest_sampling_comparison_keeps_the_same_sprite_geometry_and_camera(args, assert)
  args.state.room_scene = { show_bounds: false }
  Descent::RoomScene.reload(args)
  camera = args.state.room_scene[:camera]
  player = args.state.player
  camera.follow(x: player.x, y: player.y)
  clear_room_test_outputs(args)
  Descent::RoomScene.render(args)
  expected = args.outputs[Descent::Camera::TARGET].primitives.flatten
  args.state.room_scene[:nearest_filter] = true
  clear_room_test_outputs(args)
  Descent::RoomScene.render(args)
  sampled = args.outputs[Descent::Camera::TARGET].primitives.flatten
  expected = expected.map { |sprite| sprite.merge(scale_quality_enum: 0) }
  assert.equal! sampled, expected
  viewport = args.outputs.primitives.flatten.find { |sprite| sprite[:path] == Descent::Camera::TARGET }
  assert.equal! viewport, camera.viewport_sprite.merge(scale_quality_enum: 0)
  assert.true! args.state.room_scene[:camera].equal?(camera)
  assert.equal! [player.x, player.y], [176, 176]
  args.state.room_scene[:nearest_filter] = false
end

def test_tiled_export_loads_spawn_artwork_and_gameplay_metadata(args, assert)
  room = tiled_test_room(args)
  assert.equal! room.bounds, { x: 0, y: 0, w: 352, h: 384 }
  assert.equal! room.spawn, { x: 176, y: 176, facing: :south }
  assert.equal! [room.ground.length, room.floor_details.length, room.ceiling.length, room.doors.length,
                 room.lights.length, room.interactables.length], [71, 1, 26, 4, 6, 4]
  assert.equal! room.collision_rects.length, 54
  assert.true!(room.objects.all? { |entry| entry[:kind] != 'Spawn' })
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

def test_mounted_candles_draw_with_their_ledges_and_sort_with_the_player(args, assert)
  room = tiled_test_room(args)
  pairs = [[121, 117], [122, 118]].map do |candle_id, wall_id|
    [candle_id, wall_id].map { |id| room.objects.find { |entry| entry[:id] == id } }
  end
  pairs.each do |candle, wall|
    assert.equal! candle[:mounted_on], wall[:id]
    assert.true! wall[:mounted_objects].include?(candle)
    assert.equal! candle[:depth], wall[:depth]
    assert.equal! candle[:sprite][:y], 298
  end
  camera = Descent::Camera.new(bounds: room.bounds)
  player = Descent::Player.new(x: 176)
  args.state.room_scene = { room: room, camera: camera, show_bounds: false }
  args.state.player = player
  [286, 288, 290].each do |y|
    player.y = y
    camera.follow(x: player.x, y: player.y)
    clear_room_test_outputs(args)
    Descent::RoomScene.render(args)
    sprites = args.outputs[Descent::Camera::TARGET].primitives.flatten
    player_index = sprites.index(camera.to_draw_space(player.sprite_to_primitive))
    pairs.each do |candle, wall|
      candle_index = sprites.index(camera.to_draw_space(candle[:sprite]))
      wall_index = sprites.index(camera.to_draw_space(wall[:sprite]))
      assert.true! wall_index && candle_index && player_index
      assert.equal! candle_index, wall_index + 1
      assert.equal! sprites.count(camera.to_draw_space(candle[:sprite])), 1
      if y > wall[:depth]
        assert.true! player_index < candle_index
      else
        assert.true! candle_index < player_index
      end
    end
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

def test_mounted_on_empty_defaults_and_interactable_references(args, assert)
  data = tiled_test_map(args)
  original = tiled_test_room(args, data)
  floor_lamp = original.objects.find { |entry| entry[:id] == 6 }
  assert.equal! floor_lamp[:properties]['mounted_on'], 0
  assert.false! floor_lamp.key?(:mounted_on)
  statue = data['layers'].find { |layer| layer['name'] == 'Props' }['objects'].find { |entry| entry['id'] == 2 }
  statue['properties'].find { |prop| prop['name'] == 'mounted_on' }['value'] = 117
  room = tiled_test_room(args, data)
  assert.equal! room.interactables.find { |entry| entry[:id] == 2 }[:mounted_on], 117
  assert.equal! room.collision_rects, original.collision_rects
end

def test_mounted_on_rejects_missing_and_non_wall_targets(args, assert)
  [9999, 121, 6, 161].each do |target|
    data = tiled_test_map(args)
    candle = data['layers'].find { |layer| layer['name'] == 'Props' }['objects'].find { |entry| entry['id'] == 121 }
    candle['properties'].find { |prop| prop['name'] == 'mounted_on' }['value'] = target
    assert.true! tiled_test_error(data).include?("mounted_on target #{target}")
  end
end

def test_player_feet_stop_at_rebuilt_south_wall_edges_and_can_retreat(args, assert)
  room = tiled_test_room(args)
  # Approach each level of the rebuilt southern boundary with the original feet.
  [[300, 112, 1, 316], [270, 80, 1, 278], [52, 112, -1, 36],
   [84, 80, -1, 74], [240, 48, 1, 246], [112, 48, -1, 106]].each do |x, y, dx, stop|
    player = Descent::Player.new(x: x, y: y)
    input = { dx: dx, dy: 0, sneak: false, toggle_lamp: false }
    50.times { player.update_controls(input, walls: room.collision_rects) }
    assert.equal! [player.x, player.y], [stop, y]
    assert.true! Geometry.find_all_intersect_rect(player.collision_rect, room.collision_rects).empty?
    input[:dx] = -dx
    8.times { player.update_controls(input, walls: room.collision_rects) }
    assert.equal! [player.x, player.y], [stop - (8 * dx), y]
  end
end

def test_tiled_door_changes_base_cap_and_collision_together(args, assert)
  room = tiled_test_room(args)
  door = room.doors.find { |candidate| candidate[:id] == 218 }
  assert.false! door[:open]
  assert.equal! door[:parts].length, 2
  base, cap = door[:parts].map { |part| part[:sprite] }
  assert.equal! base.values_at(:source_x, :source_y), [32, 0]
  assert.equal! cap.values_at(:source_x, :source_y), [32, 32]
  assert.true! room.collision_rects.include?(door[:closed_colliders].first)
  assert.true!(room.ceiling.any? { |sprite| sprite.equal?(cap) })

  room.set_door_open(218, open: true)
  assert.equal! base.values_at(:source_x, :source_y), [64, 0]
  assert.equal! cap.values_at(:source_x, :source_y), [64, 32]
  assert.false! room.collision_rects.include?(door[:closed_colliders].first)
  room.set_door_open(218, open: false)
  assert.equal! base.values_at(:source_x, :source_y), [32, 0]
  assert.true! room.collision_rects.include?(door[:closed_colliders].first)

  # The south cap pair opens to local tile ID 0, which is real artwork.
  south = room.doors.find { |candidate| candidate[:id] == 267 }
  room.set_door_open(267, open: true)
  assert.equal! south[:parts].last[:sprite].values_at(:source_x, :source_y), [0, 32] # Local ID 0 is real artwork.
end

def test_tiled_open_authored_door_starts_open_and_can_close(args, assert)
  data = tiled_test_map(args)
  props = data['layers'].find { |layer| layer['name'] == 'Props' }
  object = props['objects'].find { |entry| entry['id'] == 218 }
  object['gid'] = 590 + 15
  room = tiled_test_room(args, data)
  door = room.doors.find { |candidate| candidate[:id] == 218 }
  assert.true! door[:open]
  assert.false! room.collision_rects.include?(door[:closed_colliders].first)
  assert.equal! door[:parts].last[:sprite][:source_x], 64 # Cap follows the base's starting state.
  room.set_door_open(218, open: false)
  assert.true! room.collision_rects.include?({ x: 160, y: 320, w: 32, h: 4 })
end

def test_tiled_east_and_west_doors_use_the_active_tiles_collision(args, assert)
  room = tiled_test_room(args)
  [[216, { x: 320, y: 160, w: 6, h: 32 }, { x: 320, y: 160, w: 32, h: 4 }],
   [217, { x: 26, y: 160, w: 6, h: 32 }, { x: 0, y: 160, w: 32, h: 4 }]].each do |id, closed, opened|
    door = room.doors.find { |candidate| candidate[:id] == id }
    assert.equal! door[:closed_colliders], [closed]
    assert.equal! door[:open_colliders], [opened]
    assert.true! room.collision_rects.include?(closed)
    assert.false! room.collision_rects.include?(opened)
    room.set_door_open(id, open: true)
    assert.true! room.collision_rects.include?(opened)
    assert.false! room.collision_rects.include?(closed)
    room.set_door_open(id, open: false)
    assert.true! room.collision_rects.include?(closed)
    assert.false! room.collision_rects.include?(opened)
  end
end

def test_tiled_open_authored_door_preserves_scaled_and_flipped_collision(args, assert)
  data = tiled_test_map(args)
  object = data['layers'].find { |layer| layer['name'] == 'Props' }['objects'].find { |entry| entry['id'] == 217 }
  object['gid'] = (590 + 22) | Descent::TiledRoom::HORIZONTAL | Descent::TiledRoom::VERTICAL
  object['width'] = 64
  object['height'] = 64
  room = tiled_test_room(args, data)
  door = room.doors.find { |candidate| candidate[:id] == 217 }
  assert.true! door[:open]
  assert.equal! door[:open_colliders], [{ x: 0, y: 216, w: 64, h: 8 }]
  assert.true! room.collision_rects.include?(door[:open_colliders].first)
  room.set_door_open(217, open: false)
  assert.equal! door[:closed_colliders], [{ x: 0, y: 160, w: 12, h: 64 }]
  assert.true! room.collision_rects.include?(door[:closed_colliders].first)
  assert.false! room.collision_rects.include?(door[:open_colliders].first)
end

def test_tiled_south_door_uses_collision_added_to_its_open_tile(args, assert)
  data = tiled_test_map(args)
  tiles = data['tilesets'].find { |tileset| tileset['name'] == 'doors' }['tiles']
  tiles.find { |tile| tile['id'] == 13 }['objectgroup'] = {
    'objects' => [{ 'x' => 0, 'y' => 0, 'width' => 6, 'height' => 32 }]
  }
  room = tiled_test_room(args, data)
  room.set_door_open(267, open: true)
  assert.true! room.collision_rects.include?({ x: 160, y: 32, w: 6, h: 32 })
  assert.false! room.collision_rects.include?({ x: 160, y: 32, w: 32, h: 4 })
end

def test_tiled_rejects_missing_spawn_invalid_gids_and_broken_door_pairs(args, assert)
  data = tiled_test_map(args)
  props = data['layers'].find { |layer| layer['name'] == 'Props' }
  props['objects'].reject! { |object| object['point'] }
  assert.true! tiled_test_error(data).include?('exactly one point')
  data = tiled_test_map(args)
  data['layers'].first['data'][0] = 9999
  assert.true! tiled_test_error(data).include?('Invalid tile ID')
  data = tiled_test_map(args)
  door_tiles = data['tilesets'].find { |tileset| tileset['name'] == 'doors' }['tiles']
  door_tiles.find { |tile| tile['id'] == 2 }['properties'].find { |prop| prop['name'] == 'close_tile' }['value'] = 0
  assert.true! tiled_test_error(data).include?('Inconsistent Door pair')
end

def test_room_scene_uses_spawn_reuses_loaded_data_and_renders_through_camera(args, assert)
  args.state.room_scene = { show_bounds: true }
  args.state.player = nil
  clear_room_test_outputs(args)
  Descent::RoomScene.tick(args)
  player = args.state.player
  room = args.state.room_scene[:room]
  camera = args.state.room_scene[:camera]
  target = args.outputs[Descent::Camera::TARGET]
  assert.equal! [player.x, player.y], [176, 176]
  assert.equal! [target.w, target.h], [320, 180]
  sprite = target.primitives.flatten.find { |primitive| primitive[:path] == 'sprites/player_idle_lamp_on.png' }
  assert.equal! sprite, camera.to_draw_space(player.sprite_to_primitive)
  assert.equal! sprite.values_at(:w, :h), [64, 64]
  foot_border = camera.to_screen_space(player.collision_rect.merge(r: 90, g: 255, b: 160))
  assert.true! target.borders.flatten.include?(foot_border)
  blits = args.outputs.primitives.flatten.select { |primitive| primitive[:path] == :scene }
  assert.equal! blits, [camera.viewport_sprite]
  clear_room_test_outputs(args)
  Descent::RoomScene.tick(args)
  assert.true! args.state.room_scene[:room].equal?(room)
  assert.true! args.state.player.equal?(player)
  player.x = 100
  Descent::RoomScene.reload(args)
  assert.equal! [args.state.player.x, args.state.player.y], [176, 176]
  assert.false! args.state.player.equal?(player)
  assert.equal! args.state.player.collision_rect[:w], 8
  assert.false! args.state.room_scene[:room].equal?(room)
  previous = args.state.room_scene[:room]
  previous.instance_variable_set(:@floor_details, nil) # Room loaded before the new field existed.
  clear_room_test_outputs(args)
  Descent::RoomScene.tick(args)
  assert.false! args.state.room_scene[:room].equal?(previous)
  assert.equal! args.state.room_scene[:room].floor_details.length, 1
end

def test_room_door_toggle_does_not_close_on_player_feet(args, assert)
  room = tiled_test_room(args)
  player = Descent::Player.new(x: 176, y: 316)
  Descent::RoomScene.toggle_nearest_door(room, player)
  door = room.doors.find { |candidate| candidate[:id] == 218 }
  assert.true! door[:open]
  player.y = 321
  Descent::RoomScene.toggle_nearest_door(room, player)
  assert.true! door[:open]
  player.y = 316
  Descent::RoomScene.toggle_nearest_door(room, player)
  assert.false! door[:open]
end

def test_imported_door_blocks_walking_until_opened(args, assert)
  room = tiled_test_room(args)
  player = Descent::Player.new(x: 176, y: 300)
  input = { dx: 0, dy: 1, sneak: false, toggle_lamp: false }
  30.times { player.update_controls(input, walls: room.collision_rects) }
  assert.equal! player.y, 318
  room.set_door_open(218, open: true)
  10.times { player.update_controls(input, walls: room.collision_rects) }
  assert.equal! player.y, 328
end

def test_open_east_and_west_door_leaves_block_feet_but_allow_passage(args, assert)
  room = tiled_test_room(args)
  [[217, 16, 40, -1], [216, 336, 312, 1]].each do |id, leaf_x, passage_x, dx|
    room.set_door_open(id, open: true)
    player = Descent::Player.new(x: leaf_x, y: 150)
    input = { dx: 0, dy: 1, sneak: false, toggle_lamp: false }
    20.times { player.update_controls(input, walls: room.collision_rects) }
    assert.equal! player.y, 158
    player.reset(x: passage_x, y: 176)
    input.merge!(dx: dx, dy: 0)
    45.times { player.update_controls(input, walls: room.collision_rects) }
    assert.equal! player.x, passage_x + (45 * dx)
  end
end

def test_door_toggle_does_not_open_leaf_onto_player_feet(args, assert)
  room = tiled_test_room(args)
  player = Descent::Player.new(x: 16, y: 160)
  door = room.doors.find { |candidate| candidate[:id] == 217 }
  Descent::RoomScene.toggle_nearest_door(room, player)
  assert.false! door[:open]
  player.y = 176
  Descent::RoomScene.toggle_nearest_door(room, player)
  assert.true! door[:open]
  player.x = 28
  Descent::RoomScene.toggle_nearest_door(room, player)
  assert.true! door[:open]
end

def test_y_sort_moves_player_behind_and_in_front_of_fixture(args, assert)
  room = tiled_test_room(args)
  fixture = room.objects.find { |entry| entry[:id] == 6 }
  camera = Descent::Camera.new(bounds: room.bounds)
  args.state.room_scene = { room: room, camera: camera, show_bounds: false }
  player = Descent::Player.new(x: 240, y: fixture[:depth] + 3)
  args.state.player = player

  [3, -3].each do |offset|
    player.y = fixture[:depth] + offset
    camera.follow(x: player.x, y: player.y)
    clear_room_test_outputs(args)
    Descent::RoomScene.render(args)
    sprites = args.outputs[Descent::Camera::TARGET].primitives.flatten
    player_sprite = camera.to_draw_space(player.sprite_to_primitive)
    fixture_sprite = camera.to_draw_space(fixture[:sprite])
    assert.true! Geometry.intersect_rect?(player_sprite, fixture_sprite)
    player_index = sprites.index(player_sprite)
    fixture_index = sprites.index(fixture_sprite)
    assert.true! player_index && fixture_index
    if offset.positive?
      assert.true! player_index < fixture_index # North: the fixture covers the player.
    else
      assert.true! player_index > fixture_index # South: the player covers the fixture.
    end
  end
end

def test_y_sort_combines_walls_and_props_between_ground_and_ceiling(args, assert)
  room = tiled_test_room(args)
  player = Descent::Player.new(x: 240, y: 236)
  camera = Descent::Camera.new(bounds: room.bounds)
  camera.follow(x: player.x, y: player.y)
  args.state.player = player
  args.state.room_scene = { room: room, camera: camera, show_bounds: false }
  clear_room_test_outputs(args)
  Descent::RoomScene.render(args)
  sprites = args.outputs[Descent::Camera::TARGET].primitives.flatten

  # A northern Prop must render before a more southern Wall, regardless of layers.
  indices = [121, 225, 6].map do |id|
    entry = room.objects.find { |object| object[:id] == id }
    sprites.index(camera.to_draw_space(entry[:sprite]))
  end
  assert.true!(indices.all?)
  assert.true! indices[0] < indices[1]
  assert.true! indices[1] < indices[2]

  object_indices = camera.find_all_intersect_viewport(room.objects.map { |entry| entry[:sprite] }).map do |sprite|
    sprites.index(camera.to_draw_space(sprite))
  end
  object_indices << sprites.index(camera.to_draw_space(player.sprite_to_primitive))
  ground_indices = camera.find_all_intersect_viewport(room.ground).map do |sprite|
    sprites.index(camera.to_draw_space(sprite))
  end
  ceiling_indices = camera.find_all_intersect_viewport(room.ceiling).map do |sprite|
    sprites.index(camera.to_draw_space(sprite))
  end
  assert.true! ground_indices.any? && ceiling_indices.any?
  assert.true! ground_indices.max < object_indices.min
  assert.true! ceiling_indices.min > object_indices.max
end

def test_floor_detail_stays_above_ground_and_below_player_from_both_sides(args, assert)
  room = tiled_test_room(args)
  detail = room.floor_details.first
  camera = Descent::Camera.new(bounds: room.bounds)
  args.state.room_scene = { room: room, camera: camera, show_bounds: false }
  player = Descent::Player.new(x: detail[:sprite][:x] + 16)
  args.state.player = player

  [3, -3].each do |offset|
    player.y = detail[:sprite][:y] + offset
    camera.follow(x: player.x, y: player.y)
    clear_room_test_outputs(args)
    Descent::RoomScene.render(args)
    sprites = args.outputs[Descent::Camera::TARGET].primitives.flatten
    player_sprite = camera.to_draw_space(player.sprite_to_primitive)
    detail_sprite = camera.to_draw_space(detail[:sprite])
    assert.true! Geometry.intersect_rect?(player_sprite, detail_sprite)
    detail_index = sprites.index(detail_sprite)
    ground_indices = camera.find_all_intersect_viewport(room.ground).map do |sprite|
      sprites.index(camera.to_draw_space(sprite))
    end
    scenery_indices = camera.find_all_intersect_viewport(room.objects.map { |entry| entry[:sprite] }).map do |sprite|
      sprites.index(camera.to_draw_space(sprite))
    end
    assert.true! detail_index && ground_indices.any? && scenery_indices.any?
    assert.true! ground_indices.max < detail_index
    assert.true! detail_index < scenery_indices.min
    assert.true! detail_index < sprites.index(player_sprite)
  end
end

def test_player_can_walk_across_centered_floor_detail(args, assert)
  room = tiled_test_room(args)
  player = Descent::Player.new(x: 176, y: 180)
  input = { dx: 0, dy: -1, sneak: false, toggle_lamp: false }
  30.times { player.update_controls(input, walls: room.collision_rects) }
  assert.equal! player.y, 150
end
