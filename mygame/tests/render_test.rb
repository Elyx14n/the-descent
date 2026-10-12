# frozen_string_literal: true

require 'tests/support/room_helpers'

class RenderTests
  include RoomTestHelpers

  def test_render_target_size_is_independent_of_world_size_and_origin(args, assert)
    [{ x: 21, y: 27, w: 100, h: 100 },
     { x: -20_000, y: -30_000, w: 100_000, h: 100_000 }].each do |bounds|
      clear_room_test_outputs(args)
      Descent::Render.draw(args, frame: {}, camera: Descent::Camera.new(bounds: bounds))
      target = args.outputs[Descent::Render::TARGET]
      assert.equal! [target.w, target.h], [320, 180]
    end
  end

  def test_render_plain_frame_sorts_stably_culls_and_preserves_input_data(args, assert)
    camera = Descent::Camera.new(bounds: { x: 0, y: 0, w: 320, h: 180 })
    sprite = { x: 100.25, y: 50.75, w: 32, h: 32, path: :solid }
    first = sprite.merge(r: 1)
    second = sprite.merge(r: 2)
    hidden = sprite.merge(x: 1000, r: 3)
    foreground = sprite.merge(r: 4)
    floor = sprite.merge(r: 5)
    frame = { floor: [floor], groups: [{ depth: 30, sprites: [first, second] },
                                       { depth: 30, sprites: [foreground] }, { depth: 40, sprites: [hidden] }],
              ceiling: [sprite.merge(r: 6)], hud: [{ x: 10, y: 10, text: 'HUD' }] }
    original = frame.to_s
    clear_room_test_outputs(args)
    Descent::Render.draw(args, frame: frame, camera: camera)
    drawn = args.outputs[Descent::Render::TARGET].primitives.flatten
    assert.equal! drawn.map { |primitive| primitive[:r] }, [5, 1, 2, 4, 6]
    assert.equal! frame.to_s, original
    assert.equal! first.values_at(:x, :y), [100.25, 50.75]
    assert.true! args.outputs.primitives.flatten.include?(frame[:hud].first)
  end

  def test_render_composites_scene_using_metadata_sampling_and_places_hud_above_it(args, assert)
    camera = Descent::Camera.new(bounds: { x: 0, y: 0, w: 320, h: 180 })
    sprite = { x: 100, y: 50, w: 32, h: 32, path: :solid }
    hud = { x: 10, y: 10, text: 'HUD' }
    clear_room_test_outputs(args)
    Descent::Render.draw(args, frame: { floor: [sprite], hud: [hud] }, camera: camera)
    artwork = args.outputs[Descent::Render::TARGET].primitives.flatten
    assert.equal! artwork, [camera.to_draw_space(sprite)]
    screen = args.outputs.primitives.flatten
    assert.equal! screen, [camera.viewport.merge(path: Descent::Render::TARGET), hud]
    assert.false!(artwork.any? { |primitive| primitive.key?(:scale_quality_enum) })
    assert.false!(screen.any? { |primitive| primitive.key?(:scale_quality_enum) })
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
    args.state.room_preview = { room: room, camera: camera, player: player, show_bounds: false }
    [286, 288, 290].each do |y|
      player.y = y
      camera.follow(x: player.x, y: player.y)
      clear_room_test_outputs(args)
      render_room_test(args)
      sprites = args.outputs[Descent::Render::TARGET].primitives.flatten
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

  def test_y_sort_moves_player_behind_and_in_front_of_fixture(args, assert)
    room = tiled_test_room(args)
    fixture = room.objects.find { |entry| entry[:id] == 6 }
    camera = Descent::Camera.new(bounds: room.bounds)
    player = Descent::Player.new(x: 240, y: fixture[:depth] + 3)
    args.state.room_preview = { room: room, camera: camera, player: player, show_bounds: false }

    [3, -3].each do |offset|
      player.y = fixture[:depth] + offset
      camera.follow(x: player.x, y: player.y)
      clear_room_test_outputs(args)
      render_room_test(args)
      sprites = args.outputs[Descent::Render::TARGET].primitives.flatten
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
    args.state.room_preview = { room: room, camera: camera, player: player, show_bounds: false }
    clear_room_test_outputs(args)
    render_room_test(args)
    sprites = args.outputs[Descent::Render::TARGET].primitives.flatten

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
    player = Descent::Player.new(x: detail[:sprite][:x] + 16)
    args.state.room_preview = { room: room, camera: camera, player: player, show_bounds: false }

    [3, -3].each do |offset|
      player.y = detail[:sprite][:y] + offset
      camera.follow(x: player.x, y: player.y)
      clear_room_test_outputs(args)
      render_room_test(args)
      sprites = args.outputs[Descent::Render::TARGET].primitives.flatten
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
end
