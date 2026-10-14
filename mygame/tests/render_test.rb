# frozen_string_literal: true

require 'tests/support/room_helpers'

class RenderTests
  include RoomTestHelpers

  def test_narrow_side_walls_and_closed_doors_stay_opaque_even_when_crossing_the_actor_center(args, assert)
    room = tiled_test_room(args)
    camera = Descent::Camera.new(bounds: room.bounds)
    [193, 166, 217, 216].each do |id|
      base = room.objects.find { |entry| entry[:id] == id }[:sprite]
      visible = Descent::ForegroundFade.alpha_bounds(base)
      [base[:x] + 16, visible[:x] + (visible[:w] / 2)].each do |x|
        actor = Descent::Player.new(x: x, y: base[:y] + 8).render_data
        frame = room.render_data
        frame[:groups] << actor
        frame[:fade_actors] = [actor[:fade_actor]]
        camera.follow(x: x, y: base[:y] + 8)
        clear_room_test_outputs(args)
        Descent::Render.draw(args, frame: frame, camera: camera)
        position = camera.to_draw_space(base)
        drawn = args.outputs[Descent::Render::TARGET].primitives.flatten.find do |sprite|
          sprite.except(:a) == position.except(:a)
        end
        assert.equal! drawn[:a], 255
      end
      assert.equal! base[:a], 255
    end
  end

  def test_render_preserves_opacity_history_when_an_actor_leaves_the_column(args, assert)
    room = tiled_test_room(args)
    camera = Descent::Camera.new(bounds: room.bounds)
    camera.follow(x: 144, y: 90)
    cap = room.ceiling.find { |sprite| sprite[:x] == 128 && sprite[:y] == 64 }
    state = {}
    alphas = []
    out_ticks = Descent::ForegroundFade::FADE_OUT_TICKS
    in_ticks = Descent::ForegroundFade::FADE_IN_TICKS
    [[0, 144, 68], [out_ticks, 144, 68], [out_ticks + 1, 180, 100],
     [out_ticks + in_ticks + 1, 180, 100]].each do |tick, x, y|
      actor = Descent::Player.new(x: x, y: y).render_data
      frame = room.render_data
      frame[:groups] << actor
      frame[:fade_actors] = [actor[:fade_actor]]
      original = frame.to_s
      clear_room_test_outputs(args)
      Descent::Render.draw(args, frame: frame, camera: camera, fade_state: state, tick: tick)
      position = camera.to_draw_space(cap)
      drawn = args.outputs[Descent::Render::TARGET].primitives.flatten.find do |sprite|
        sprite.except(:a) == position.except(:a)
      end
      alphas << drawn[:a]
      assert.equal! frame.to_s, original
    end
    assert.true! alphas[0] > alphas[1]
    assert.true! alphas[2] > alphas[1]
    assert.true! alphas[2] < 255
    assert.equal! alphas.last, 255
  end

  def test_south_reveal_leaves_neighboring_columns_and_north_gate_opaque(args, assert)
    room = tiled_test_room(args)
    camera = Descent::Camera.new(bounds: room.bounds)
    neighboring_columns = [96, 160]
    [[144, 68], [176, 318]].each do |x, y|
      camera.follow(x: x, y: y)
      actor = Descent::Player.new(x: x, y: y).render_data
      frame = room.render_data
      frame[:groups] << actor
      frame[:fade_actors] = [actor[:fade_actor]]
      clear_room_test_outputs(args)
      Descent::Render.draw(args, frame: frame, camera: camera)
      drawn = args.outputs[Descent::Render::TARGET].primitives.flatten
      if y == 68
        # Neighbor caps previously faded solely because the empty 64px frame overlapped them.
        neighboring_columns.each do |cap_x|
          cap = room.ceiling.find { |sprite| sprite[:x] == cap_x && sprite[:y] == 64 }
          assert.true! drawn.include?(camera.to_draw_space(cap))
        end
        cap = room.ceiling.find { |sprite| sprite[:x] == 128 && sprite[:y] == 64 }
        assert.false! drawn.include?(camera.to_draw_space(cap))
      else
        room.doors.find { |door| door[:id] == 218 }[:parts].each do |part|
          assert.true! drawn.include?(camera.to_draw_space(part[:sprite]))
        end
      end
    end
  end

  def test_render_fades_after_sorting_and_preserves_floor_props_hud_and_frame(args, assert)
    camera = Descent::Camera.new(bounds: { x: 0, y: 0, w: 320, h: 180 })
    actor = Descent::Player.new(x: 48, y: 80).render_data
    wall = { x: 32, y: 32, w: 32, h: 32, path: :solid, r: 1, a: 255 }
    cap = wall.merge(y: 64, r: 2, a: 100)
    prop = wall.merge(r: 3)
    floor = wall.merge(r: 4)
    hud = { x: 10, y: 10, text: 'HUD' }
    frame = { floor: [floor], groups: [{ depth: 32, sprites: [wall, prop] }, actor], ceiling: [cap],
              fade_units: [{ type: :wall, base: wall, footprint: wall, sprites: [wall, cap] }],
              fade_actors: [actor[:fade_actor]], hud: [hud] }
    original = frame.to_s
    clear_room_test_outputs(args)
    Descent::Render.draw(args, frame: frame, camera: camera)
    drawn = args.outputs[Descent::Render::TARGET].primitives.flatten
    assert.equal! drawn.select { |sprite| sprite[:r] }.map { |sprite| [sprite[:r], sprite[:a]] },
                  [[4, 255], [1, 159], [3, 255], [2, 63]]
    assert.equal! frame.to_s, original
    assert.true! args.outputs.primitives.flatten.include?(hud)
  end

  def test_render_restores_opacity_on_retreat_and_keeps_camera_translation_out_of_falloff(args, assert)
    room = tiled_test_room(args)
    camera = Descent::Camera.new(bounds: room.bounds)
    wall = room.objects.find { |entry| entry[:id] == 241 }[:sprite]
    camera_positions = [80, 120]
    # At 68 the center line crosses the cap's artwork; 80 only crossed its padding.
    [68, 96, 68].each do |y|
      actor = Descent::Player.new(x: 144, y: y).render_data
      frame = room.render_data
      frame[:groups] << actor
      frame[:fade_actors] = [actor[:fade_actor]]
      expected = y == 68 ? 72 : 255
      camera_positions.each do |camera_y|
        camera.follow(x: 144, y: camera_y)
        clear_room_test_outputs(args)
        Descent::Render.draw(args, frame: frame, camera: camera)
        assert.true! args.outputs[Descent::Render::TARGET].primitives.flatten.include?(
          camera.to_draw_space(wall.merge(a: expected))
        )
      end
    end
    assert.equal! wall[:a], 255
  end

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
