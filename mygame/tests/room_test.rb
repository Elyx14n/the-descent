# frozen_string_literal: true

require 'tests/support/room_helpers'

class RoomTests
  include RoomTestHelpers

  def test_mounted_lights_reach_front_floor_and_wall_faces_without_shining_through_the_wall(args, assert)
    room = tiled_test_room(args)
    frame = room.render_data
    offsets = [-16, 0, 16]
    [[121, 22, 117], [122, 80, 118]].each do |light_id, wall_id, host_id|
      source = frame[:light_sources].find { |entry| entry[:id] == light_id }
      wall = room.objects.find { |entry| entry[:id] == wall_id }
      host = room.objects.find { |entry| entry[:id] == host_id }
      assert.false! source[:ignore_owner_ids].include?(wall_id)
      assert.true! source[:y] < wall[:colliders].map { |rect| rect[:y] }.min
      prepared = Descent::Lighting.prepare(light_sources: [source], light_blockers: frame[:light_blockers])
      triangles = Descent::Lighting.triangles(light_polygons: prepared,
                                              camera: Descent::Camera.new(**room.spawn.slice(:x, :y)).for_drawing)
      assert.true! triangles.any?
      front = offsets.map do |offset|
        { sprite: {}, bases: [{ x: source[:x] + offset, y: source[:y] - 8, w: 1, h: 1 }] }
      end
      behind = { sprite: {}, bases: [{ x: source[:x], y: source[:y] + 10, w: 1, h: 1 }] }
      faces = frame[:light_receivers].select do |receiver|
        receiver[:sprite].equal?(wall[:sprite]) || receiver[:sprite].equal?(host[:sprite])
      end
      colors = Descent::Lighting.receiver_colors(light_receivers: front + [behind] + faces, light_polygons: prepared)
      front.each { |receiver| assert.true! colors[receiver[:sprite].object_id][0] > Descent::Lighting::AMBIENT }
      assert.equal! colors[behind[:sprite].object_id], [31, 31, 31]
      faces.each { |receiver| assert.true! colors[receiver[:sprite].object_id][0] > Descent::Lighting::AMBIENT }
    end
  end

  def test_foreground_faces_reject_backlighting_at_south_corners_and_door(args, assert)
    room = tiled_test_room(args)
    frame = room.render_data
    [[246, 80, 110, 50], [245, 112, 80, 20], [241, 144, 80, 20], [267, 176, 72, 20]].each do |id, x, back_y, front_y|
      entry = room.objects.find { |object| object[:id] == id }
      receiver = frame[:light_receivers].find { |item| item[:sprite].equal?(entry[:sprite]) }
      assert.equal! receiver[:front_y], entry[:sprite][:y]
      [back_y, front_y].each do |y|
        lights = Descent::Lighting.prepare(light_sources: [{ x: x, y: y, radius: 64 }],
                                           light_blockers: frame[:light_blockers])
        color = Descent::Lighting.receiver_colors(light_receivers: [receiver], light_polygons: lights)
        if y == back_y
          assert.equal! color[entry[:sprite].object_id], [31, 31, 31]
        else
          assert.true! color[entry[:sprite].object_id][0] > 31
        end
      end
    end
    [258, 193].each do |id| # Horizontal top-down strip and vertical side wall.
      sprite = room.objects.find { |entry| entry[:id] == id }[:sprite]
      receiver = frame[:light_receivers].find { |item| item[:sprite].equal?(sprite) }
      assert.false! receiver.key?(:front_y)
    end
    room.set_door_open(267, open: true)
    sprite = room.doors.find { |entry| entry[:id] == 267 }[:sprite]
    receiver = room.render_data[:light_receivers].find { |item| item[:sprite].equal?(sprite) }
    assert.equal! receiver[:front_y], 32
  end

  def test_render_collections_isolate_appends_and_keep_door_and_mounted_light_artwork_live(args, assert)
    room = tiled_test_room(args)
    frame = room.render_data
    original = room.render_data
    frame.each_value(&:clear)
    assert.equal! room.render_data, original

    door = room.doors.find { |entry| entry[:id] == 267 }
    candle = room.lights.find { |entry| entry[:id] == 121 }
    group = original[:groups].find { |entry| entry[:sprites].any? { |sprite| sprite.equal?(candle[:sprite]) } }
    assert.true! group
    assert.equal! group[:sprites].length, 2
    assert.equal! original[:groups].sum { |entry| entry[:sprites].count { |sprite| sprite.equal?(candle[:sprite]) } }, 1
    closed = door[:sprite].dup
    lit = candle[:sprite].dup
    room.set_door_open(267, open: true)
    room.set_light_enabled(121, enabled: false)
    assert.false! door[:sprite] == closed
    assert.false! candle[:sprite] == lit
    assert.true!(original[:groups].any? { |entry| entry[:sprites].any? { |sprite| sprite.equal?(door[:sprite]) } })
    assert.true! group[:sprites].last.equal?(candle[:sprite])
    # Lighting snapshots change with enabled state and active geometry; drawing
    # collections retain the same live sprite references across those changes.
    current = room.render_data
    %i[floor groups ceiling fade_units].each { |key| assert.equal! original[key], current[key] }

    replacement = tiled_test_room(args)
    assert.false! replacement.render_data[:groups].first.equal?(original[:groups].first)
  end

  def test_light_blockers_use_object_colliders_and_do_not_turn_caps_into_floor_obstacles(args, assert)
    room = tiled_test_room(args)
    blockers = room.render_data[:light_blockers]
    expected = room.objects.sum do |entry|
      entry[:type] == :door ? entry[:closed_colliders].length : entry[:colliders].length
    end
    assert.equal! blockers.length, expected
    wall = room.objects.find { |entry| entry[:id] == 11 }
    wall_blocker = blockers.find { |entry| entry[:sprite].equal?(wall[:sprite]) }
    assert.equal! wall_blocker[:bounds], wall[:colliders].first
    assert.equal! wall_blocker[:edges].length, 4
    assert.true! wall_blocker[:bounds][:h] < wall[:sprite][:h]
    room.ceiling.each do |cap|
      assert.false!(blockers.any? { |entry| entry[:sprite].equal?(cap) })
    end
    colliderless = room.objects.select { |entry| entry[:colliders].empty? && entry[:type] != :door }
    colliderless.each do |entry|
      assert.false!(blockers.any? { |blocker| blocker[:sprite].equal?(entry[:sprite]) })
    end
  end

  def test_light_sources_snapshot_enabled_state_and_share_mounted_host_bases(args, assert)
    room = tiled_test_room(args)
    frame = room.render_data
    candle = room.lights.find { |entry| entry[:id] == 121 }
    source = frame[:light_sources].find { |entry| entry[:id] == 121 }
    wall = room.objects.find { |entry| entry[:id] == candle[:mounted_on] }
    assert.equal! source[:ignore_owner_ids], [wall[:id]]
    receiver = frame[:light_receivers].find { |entry| entry[:sprite].equal?(candle[:sprite]) }
    host = frame[:light_receivers].find { |entry| entry[:sprite].equal?(wall[:sprite]) }
    assert.equal! receiver[:bases], host[:bases]
    assert.equal! source[:y], host[:bases].map { |base| base[:y] }.min - 1

    standalone = frame[:light_sources].find { |entry| entry[:id] == 6 }
    assert.equal! standalone[:ignore_owner_ids], [6]
    other = frame[:light_blockers].find { |entry| entry[:owner_ids] == [6] }
    assert.true! other
    assert.false! source[:ignore_owner_ids].include?(other[:owner_ids].first)

    room.set_light_enabled(121, enabled: false)
    assert.false!(room.render_data[:light_sources].any? { |entry| entry[:id] == 121 })
    assert.equal! frame[:light_sources].find { |entry| entry[:id] == 121 }, source
    source[:x] = -1000
    source[:ignore_owner_ids].clear
    room.set_light_enabled(121, enabled: true)
    assert.equal! room.render_data[:light_sources].find { |entry| entry[:id] == 121 }[:x], candle[:x]
    assert.equal! room.render_data[:light_sources].find { |entry| entry[:id] == 121 }[:ignore_owner_ids], [wall[:id]]
  end

  def test_light_blockers_follow_door_collision_but_ignore_flame_animation_and_fading(args, assert)
    room = tiled_test_room(args)
    door = room.doors.find { |entry| entry[:id] == 267 }
    candle = room.lights.find { |entry| entry[:id] == 6 }
    before = room.render_data[:light_blockers]
    closed = before.select { |entry| entry[:sprite].equal?(door[:sprite]) }
    original_candle = before.find { |entry| entry[:sprite].equal?(candle[:sprite]) }
    room.set_door_open(267, open: true)
    room.set_light_enabled(6, enabled: false)
    after = room.render_data[:light_blockers]
    opened = after.select { |entry| entry[:sprite].equal?(door[:sprite]) }
    assert.equal! opened.map { |entry| entry[:bounds] }, door[:open_colliders]
    assert.false! opened.map { |entry| entry[:edges] } == closed.map { |entry| entry[:edges] }
    assert.equal! after.find { |entry| entry[:sprite].equal?(candle[:sprite]) }[:edges], original_candle[:edges]
    room.set_light_enabled(6, enabled: true)
    room.update_animations(tick: 9)
    candle[:sprite][:a] = 64
    animated = room.render_data[:light_blockers].find { |entry| entry[:sprite].equal?(candle[:sprite]) }
    assert.equal! animated[:edges], original_candle[:edges]
    after.first[:owner_ids].clear
    after.first[:edges].clear
    after.first[:bounds][:w] = 0
    fresh = room.render_data[:light_blockers].first
    assert.true! fresh[:owner_ids].any?
    assert.true! fresh[:bounds][:w].positive?
    assert.equal! before.select { |entry| entry[:sprite].equal?(door[:sprite]) }, closed
  end

  def test_south_fade_units_pair_caps_faces_and_corners_without_joining_neighbor_columns(args, assert)
    room = tiled_test_room(args)
    [[128, 64, [241]], [96, 64, [245, 265]], [64, 96, [246]]].each do |x, y, ids|
      cap = room.ceiling.find { |sprite| sprite[:x] == x && sprite[:y] == y }
      unit = room.fade_units.find { |candidate| candidate[:sprites].any? { |sprite| sprite.equal?(cap) } }
      assert.equal! unit[:type], :wall
      members = room.objects.select do |entry|
        unit[:sprites].any? { |sprite| sprite.equal?(entry[:sprite]) }
      end
      assert.equal!(unit[:colliders], members.flat_map { |entry| entry[:colliders] })
      assert.equal! members.map { |entry| entry[:id] }.sort, ids.sort
      assert.equal! unit[:sprites].length, ids.length + 1
    end
  end

  def test_fade_units_include_mounted_artwork_and_doors_but_exclude_ordinary_props(args, assert)
    room = tiled_test_room(args)
    wall = room.objects.find { |entry| entry[:id] == 117 }
    candle = room.objects.find { |entry| entry[:id] == 121 }
    unit = room.fade_units.find do |candidate|
      candidate[:sprites].any? { |sprite| sprite.equal?(wall[:sprite]) }
    end
    assert.true!(unit[:sprites].any? { |sprite| sprite.equal?(candle[:sprite]) })
    # Mounted artwork shares opacity but cannot extend its host's fade range.
    candle[:colliders] = [{ x: 0, y: 0, w: 1000, h: 1000 }]
    room.set_door_open(267, open: true)
    assert.false!(unit[:colliders].any? { |rect| rect.equal?(candle[:colliders].first) })
    prop_types = %i[prop light pedestal]
    ordinary = room.objects.select { |entry| prop_types.include?(entry[:type]) && !entry[:mounted_on] }
    all_sprites = room.fade_units.flat_map { |candidate| candidate[:sprites] }
    assert.false!(ordinary.any? { |entry| all_sprites.any? { |sprite| sprite.equal?(entry[:sprite]) } })
    room.doors.each do |door|
      assert.true!(all_sprites.any? { |sprite| sprite.equal?(door[:sprite]) })
    end
  end

  def test_orphan_caps_and_colliderless_walls_cannot_trigger_fading(_args, assert)
    collections = RoomData.empty_collections
    base = { x: 32, y: 32, w: 32, h: 32, type: :wall, path: :solid, a: 255 }
    cap = base.merge(y: 64, type: :ceiling)
    orphan = cap.merge(x: 96)
    collections[:objects] << { id: 1, type: :wall, sprite: base, colliders: [] }
    collections[:ceiling].push(cap, orphan)
    room = Descent::Room.new(bounds: { x: 0, y: 0, w: 320, h: 180 }, spawn: { x: 48, y: 64 },
                             collections: collections)
    assert.equal! room.fade_units.length, 2
    assert.true!(room.fade_units.all? { |unit| unit[:colliders].empty? })
    [48, 112].each do |x|
      actor = Descent::Player.new(x: x, y: 64).render_data[:fade_actor]
      drawn = Descent::ForegroundFade.apply([actor[:sprite], base, cap, orphan], units: room.fade_units,
                                                                                 actors: [actor], viewport: room.bounds)
      assert.equal! drawn.last(3).map { |sprite| sprite[:a] }, [255, 255, 255]
    end
  end

  def test_door_fade_units_keep_references_and_refresh_active_colliders(args, assert)
    room = tiled_test_room(args)
    door = room.doors.find { |entry| entry[:id] == 267 }
    base, cap = door[:parts].map { |part| part[:sprite] }
    unit = room.fade_units.find { |candidate| candidate[:sprites].any? { |sprite| sprite.equal?(base) } }
    assert.equal! unit[:type], :door
    assert.true!(unit[:sprites].any? { |sprite| sprite.equal?(cap) })
    assert.equal! unit[:colliders], door[:closed_colliders]
    identity = unit.object_id
    closed = cap.dup
    room.set_door_open(267, open: true)
    assert.equal! unit.object_id, identity
    assert.equal! unit[:colliders], door[:open_colliders]
    assert.true!(unit[:sprites].any? { |sprite| sprite.equal?(cap) && sprite[:source_x].zero? })
    room.set_door_open(267, open: false)
    assert.equal! unit[:colliders], door[:closed_colliders]
    assert.equal! cap, closed
    frame = room.render_data
    frame[:fade_units].clear
    assert.true! room.fade_units.any?
  end

  def test_room_reuses_prepared_fade_geometry_after_door_changes(args, assert)
    room = tiled_test_room(args)
    units = room.fade_units
    assert.true! units.any?
    room.set_door_open(267, open: true)
    frame = room.render_data
    assert.true! room.fade_units.equal?(units)
    assert.true! frame[:fade_units].first.equal?(units.first)
    assert.true! room.doors.find { |door| door[:id] == 267 }[:open]
    assert.true! frame[:fade_units].first[:sprites].last.equal?(room.ceiling.first)
  end

  def test_player_processes_interaction_before_movement_and_animation(args, assert)
    room = tiled_test_room(args)
    room.doors.find { |door| door[:id] == 218 }[:properties]['locked'] = false
    player = Descent::Player.new(x: 176, y: 318)
    player.update({ dx: 0, dy: 1, sneak: false, toggle_lamp: true, interact: true }, room: room)
    assert.true! room.doors.find { |door| door[:id] == 218 }[:open]
    assert.equal! player.y, 319
    assert.false! player.lamp_on
    assert.equal! player.animation, :walk
  end

  def test_dead_player_cannot_interact_with_doors(args, assert)
    room = tiled_test_room(args)
    room.doors.find { |door| door[:id] == 218 }[:properties]['locked'] = false
    player = Descent::Player.new(x: 176, y: 318, sanity: 0)
    player.update({ dx: 0, dy: 1, sneak: false, toggle_lamp: true, interact: true }, room: room)
    assert.false! room.doors.find { |door| door[:id] == 218 }[:open]
    assert.equal! player.y, 318
    assert.true! player.lamp_on
    assert.equal! player.animation, :death
  end

  def test_locked_ritual_gate_rejects_player_interaction_until_unlocked(args, assert)
    room = tiled_test_room(args)
    gate = room.doors.find { |door| door[:id] == 218 }
    player = Descent::Player.new(x: 176, y: 318)
    artwork = gate[:parts].map { |part| part[:sprite].dup }
    colliders = room.collision_rects
    input = { dx: 0, dy: 0, sneak: false, toggle_lamp: false, interact: true }
    assert.true! gate[:properties]['locked']
    3.times { player.update(input, room: room) }
    assert.false! gate[:open]
    assert.equal! gate[:parts].map { |part| part[:sprite] }, artwork
    assert.equal! room.collision_rects, colliders

    # Future puzzle logic can release the authored lock; placement is not implemented.
    gate[:properties]['locked'] = false
    player.update(input, room: room)
    assert.true! gate[:open]
  end

  def test_locked_nearest_door_does_not_redirect_interaction_to_another_door(args, assert)
    data = tiled_test_map(args)
    east = data['layers'].find { |layer| layer['name'] == 'Props' }['objects'].find { |entry| entry['id'] == 216 }
    east['x'] = 160
    east['y'] = 96
    room = tiled_test_room(args, data)
    player = Descent::Player.new(x: 176, y: 318)
    room.toggle_nearest_interactable(point: { x: player.x, y: player.y }, collision_rect: player.collision_rect)
    assert.false! room.doors.find { |door| door[:id] == 218 }[:open]
    assert.false! room.doors.find { |door| door[:id] == 216 }[:open]
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
    object['gid'] = (590 + 22) | Descent::TiledDeserializer::HORIZONTAL | Descent::TiledDeserializer::VERTICAL
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

  def test_room_door_toggle_does_not_close_on_player_feet(args, assert)
    room = tiled_test_room(args)
    room.doors.find { |door| door[:id] == 218 }[:properties]['locked'] = false
    player = Descent::Player.new(x: 176, y: 316)
    room.toggle_nearest_interactable(point: { x: player.x, y: player.y }, collision_rect: player.collision_rect)
    door = room.doors.find { |candidate| candidate[:id] == 218 }
    assert.true! door[:open]
    player.y = 321
    room.toggle_nearest_interactable(point: { x: player.x, y: player.y }, collision_rect: player.collision_rect)
    assert.true! door[:open]
    player.y = 316
    room.toggle_nearest_interactable(point: { x: player.x, y: player.y }, collision_rect: player.collision_rect)
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
      input[:dx] = dx
      input[:dy] = 0
      45.times { player.update_controls(input, walls: room.collision_rects) }
      assert.equal! player.x, passage_x + (45 * dx)
    end
  end

  def test_door_toggle_does_not_open_leaf_onto_player_feet(args, assert)
    room = tiled_test_room(args)
    player = Descent::Player.new(x: 16, y: 160)
    door = room.doors.find { |candidate| candidate[:id] == 217 }
    room.toggle_nearest_interactable(point: { x: player.x, y: player.y }, collision_rect: player.collision_rect)
    assert.false! door[:open]
    player.y = 176
    room.toggle_nearest_interactable(point: { x: player.x, y: player.y }, collision_rect: player.collision_rect)
    assert.true! door[:open]
    player.x = 28
    room.toggle_nearest_interactable(point: { x: player.x, y: player.y }, collision_rect: player.collision_rect)
    assert.true! door[:open]
  end

  def test_player_can_walk_across_centered_floor_detail(args, assert)
    room = tiled_test_room(args)
    player = Descent::Player.new(x: 176, y: 180)
    input = { dx: 0, dy: -1, sneak: false, toggle_lamp: false }
    30.times { player.update_controls(input, walls: room.collision_rects) }
    assert.equal! player.y, 150
  end
end
