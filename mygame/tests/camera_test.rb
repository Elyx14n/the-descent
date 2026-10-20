# frozen_string_literal: true

require 'app/camera'
require 'app/player'

class CameraTests
  # Control display scale without resizing the native window during a unit test.
  class CameraAtTestScale < Descent::Camera
    attr_writer :test_pixel_scale

    def initialize(x: 0, y: 0, pixel_scale: 1)
      @test_pixel_scale = pixel_scale
      super(x: x, y: y)
    end

    private

    def pixel_scale
      @test_pixel_scale
    end
  end

  DIAGONAL_AXIS = [-1, 1].freeze
  COORDS = %i[x y].freeze

  def test_follow_keeps_the_player_centered_at_any_world_position(_args, assert)
    camera = CameraAtTestScale.new
    positions = [[10.125, 20.5], [989.125, 20.5], [10.125, 979.5], [989.125, 979.5],
                 [-500.125, -300.5], [1500.125, 1300.5]]
    positions.each do |x, y|
      camera.follow(x: x, y: y)
      assert.equal! [camera.x, camera.y], [x, y]
      sprite = Descent::Player.new(x: x, y: y).sprite_to_primitive
      assert.equal! camera.for_drawing.to_draw_space(sprite).values_at(:x, :y), [160, 66]
    end
  end

  def test_composited_camera_keeps_scene_pixels_aligned_and_covers_the_native_view(_args, assert)
    camera = CameraAtTestScale.new(x: 0, y: 0)
    [-500.75, -0.5, 0, 0.125, 0.5, 500.875].each do |x|
      camera.follow(x: x, y: x + 0.375)
      scene = camera.for_compositing
      presentation = camera.for_drawing(snap: false)
      assert.equal! [scene.viewport_w, scene.viewport_h], [320, 180]
      assert.equal! scene.to_screen_space(scene.viewport_world), scene.viewport
      tile = scene.to_draw_space({ x: 32, y: 64 })
      assert.equal! tile.values_at(:x, :y), [tile[:x].round, tile[:y].round]
      expected = presentation.to_screen(x: 32, y: 64)
      assert.true! (tile[:x] - expected[:x]).abs <= 1
      assert.true! (tile[:y] - expected[:y]).abs <= 1
    end
  end

  def test_fractional_drawing_moves_both_diagonal_axes_together_and_keeps_the_player_centered(_args, assert)
    camera = CameraAtTestScale.new(x: 0, y: 0)
    DIAGONAL_AXIS.product(DIAGONAL_AXIS).each do |dx, dy|
      x = -371.125
      y = 227.5
      previous = nil
      60.times do
        camera.follow(x: x, y: y)
        drawing = camera.for_drawing(snap: false)
        marker = drawing.to_draw_space({ x: 0, y: 0 })
        if previous
          assert.true! (marker[:x] - previous[:x] + (dx * Math.sqrt(0.5))).abs < 0.00001
          assert.true! (marker[:y] - previous[:y] + (dy * Math.sqrt(0.5))).abs < 0.00001
        end
        sprite = drawing.to_draw_space({ x: x, y: y - 24, w: 64, h: 64 })
        assert.true! (sprite[:x] - 160).abs < 0.00001
        assert.true! (sprite[:y] - 66).abs < 0.00001
        previous = marker
        x += dx * Math.sqrt(0.5)
        y += dy * Math.sqrt(0.5)
      end
    end
  end

  def test_fractional_drawing_preserves_tile_adjacency_and_uses_its_own_viewport(_args, assert)
    camera = CameraAtTestScale.new(x: 500, y: 500)
    camera.follow(x: 500.4, y: 500.4)
    drawing = camera.for_drawing(snap: false)
    tiles = [{ x: 350, y: 420, w: 32, h: 32 }, { x: 382, y: 420, w: 32, h: 32 }]
    left, right = drawing.to_draw_space(tiles)
    assert.true! (left[:x] + left[:w] - right[:x]).abs < 0.00001
    assert.true! (left[:x] - 9.6).abs < 0.00001
    restored = drawing.to_world_space(left)
    assert.true! (restored[:x] - tiles.first[:x]).abs < 0.00001
    assert.true! (restored[:y] - tiles.first[:y]).abs < 0.00001
    # Snapped and fractional viewports differ at their left edge.
    strip = { x: 340, y: 420, w: 0.25, h: 1 }
    assert.equal! camera.find_all_intersect_viewport([strip]), [strip]
    assert.true! drawing.find_all_intersect_viewport([strip]).empty?
    camera.follow(x: 700, y: 700)
    assert.equal! drawing.to_draw_space(tiles.first), left
  end

  def test_draw_snapshot_refreshes_scale_and_position_without_changing_previous_values(_args, assert)
    camera = CameraAtTestScale.new(x: 371, y: 227)
    camera.follow(x: 351.25, y: 227.25)
    sprite = { x: 351.25, y: 227.25, w: 32, h: 32 }
    first = camera.for_drawing
    original = first.to_draw_space(sprite)
    assert.equal! original, camera.to_draw_space(sprite)
    assert.equal! first.to_screen_space(first.viewport_world), first.viewport

    camera.test_pixel_scale = 4
    second = camera.for_drawing
    assert.equal! second.to_draw_space(sprite), camera.to_draw_space(sprite)
    assert.false! second.viewport_world == first.viewport_world
    camera.follow(x: 400, y: 250)
    assert.equal! first.to_draw_space(sprite), original
    assert.equal! camera.for_drawing.to_draw_space(sprite), camera.to_draw_space(sprite)
    assert.equal! camera.to_draw_space([sprite, [sprite], nil]),
                  [camera.to_draw_space(sprite), [camera.to_draw_space(sprite)], nil]
  end

  def test_following_translates_the_viewport(_args, assert)
    camera = CameraAtTestScale.new(x: 371, y: 227)

    left = camera.follow(x: 100, y: 200).viewport_world
    right = camera.follow(x: 600, y: 200).viewport_world

    assert.true! right[:x] > left[:x]
    assert.equal! camera.viewport, { x: 0, y: 0, w: 320, h: 180 }
  end

  def test_diagonal_movement_keeps_the_drawn_player_fixed_at_screen_center(_args, assert)
    camera = CameraAtTestScale.new(x: 371, y: 227)
    [false, true].each do |sneak|
      DIAGONAL_AXIS.product(DIAGONAL_AXIS).each do |dx, dy|
        player = Descent::Player.new(x: 371, y: 227)
        input = { dx: dx, dy: dy, sneak: sneak, toggle_lamp: false }
        60.times do
          player.update_controls(input)
          camera.follow(x: player.x, y: player.y)
          sprite = camera.to_draw_space(player.sprite_to_primitive)
          assert.equal! sprite.values_at(:x, :y, :w, :h), [160, 66, 64, 64]
        end
        assert.true! player.x != player.x.round
      end
    end
  end

  def test_diagonal_camera_steps_do_not_reverse_with_different_fractional_axis_positions(_args, assert)
    camera = CameraAtTestScale.new(x: 371, y: 227)
    [-1, 1].product([-1, 1]).each do |dx, dy|
      player = Descent::Player.new(x: 371.125, y: 227.5)
      camera.follow(x: player.x, y: player.y)
      previous = camera.to_draw_space({ x: 350, y: 220 })
      60.times do
        player.update_controls({ dx: dx, dy: dy, sneak: false, toggle_lamp: false })
        camera.follow(x: player.x, y: player.y)
        marker = camera.to_draw_space({ x: 350, y: 220 })
        assert.true! (marker[:x] - previous[:x]) * dx <= 0
        assert.true! (marker[:y] - previous[:y]) * dy <= 0
        assert.equal! camera.to_draw_space(player.sprite_to_primitive).values_at(:x, :y), [160, 66]
        previous = marker
      end
    end
  end

  def test_hd_diagonal_scrolling_uses_display_pixels_and_preserves_tile_adjacency(_args, assert)
    [3, 4.25, 5.5, 6].each do |scale|
      camera = CameraAtTestScale.new(pixel_scale: scale)
      centered = [((160 * scale) + 0.5).floor.fdiv(scale),
                  (((90 * scale) + 0.5).floor.fdiv(scale) - 24)]
      DIAGONAL_AXIS.product(DIAGONAL_AXIS).each do |dx, dy|
        player = Descent::Player.new(x: 371.125, y: 227.5)
        camera.follow(x: player.x, y: player.y)
        previous = camera.to_draw_space({ x: 350, y: 220 })
        60.times do
          player.update_controls({ dx: dx, dy: dy, sneak: false, toggle_lamp: false })
          camera.follow(x: player.x, y: player.y)
          tiles = camera.to_draw_space([{ x: 350, y: 220, w: 32, h: 32 },
                                        { x: 382, y: 220, w: 32, h: 32 },
                                        { x: 350, y: 252, w: 32, h: 32 }])
          left, right, above = tiles
          COORDS.each do |axis|
            display_position = left[axis] * scale
            assert.true! (display_position - display_position.round).abs < 0.00001
            direction = axis == :x ? dx : dy
            distance = (previous[axis] - left[axis]) * direction * scale
            assert.true! distance >= -0.00001
            # A normalized diagonal advances ~0.707 logical pixels, plus at most
            # one physical pixel of rounding error, rather than a full logical step.
            assert.true! distance <= (Math.sqrt(0.5) * scale) + 1.00001
          end
          assert.true! (left[:x] + left[:w] - right[:x]).abs < 0.00001
          assert.true! (left[:y] + left[:h] - above[:y]).abs < 0.00001
          drawn = camera.to_draw_space(player.sprite_to_primitive)
          COORDS.each_with_index do |axis, index|
            assert.true! (drawn[axis] - centered[index]).abs < 0.00001
          end
          previous = left
        end
      end
    end
  end

  def test_to_screen_tracks_a_world_point_as_the_camera_moves(_args, assert)
    camera = CameraAtTestScale.new(x: 371, y: 227)
    marker = { x: 351, y: 227 }

    near = camera.follow(**marker).to_screen(**marker)
    assert.equal! near, { x: 160, y: 90 }

    panned = camera.follow(x: 381, y: 227).to_screen(**marker)
    assert.equal! panned, { x: 130, y: 90 }
  end

  def test_drawn_player_remains_stable_at_half_pixel_ties_in_positive_and_negative_worlds(_args, assert)
    camera = CameraAtTestScale.new(x: 0, y: 0)
    [-500.5, -160.5, -0.5, 0.5, 159.5, 160.5, 500.5].each do |position|
      player = Descent::Player.new(x: position, y: position)
      camera.follow(x: player.x, y: player.y)
      source = player.sprite_to_primitive
      sprite = camera.to_draw_space(source)
      assert.equal! sprite.values_at(:x, :y), [160, 66]
      assert.equal! player.sprite_to_primitive, source
      assert.equal! [player.x, player.y], [position, position]
    end
  end

  def test_camera_preserves_fractional_follow_positions(_args, assert)
    camera = CameraAtTestScale.new(x: 500, y: 500)
    camera.follow(x: 500.2, y: 500.4)

    assert.equal! [camera.x, camera.y], [500.2, 500.4]
    screen = camera.to_screen(x: 500.2, y: 500.4)
    assert.true! (screen[:x] - 160.2).abs < 0.00001
    assert.true! (screen[:y] - 90.4).abs < 0.00001
    assert.equal! camera.viewport_world[:w], 320
  end

  def test_adjacent_tiles_stay_on_whole_pixels_during_fractional_camera_motion(_args, assert)
    camera = CameraAtTestScale.new(x: 0, y: 0)
    tiles = [{ x: 0, y: 0, w: 32, h: 32 }, { x: 32, y: 0, w: 32, h: 32 },
             { x: 0, y: 32, w: 32, h: 32 }]
    [-0.9, -0.5, -0.25, 0, 0.25, 0.5, Math.sqrt(0.5), 0.9].each do |offset|
      camera.follow(x: offset, y: offset)
      left, right, above = camera.to_screen_space(tiles)
      [left, right, above].each do |tile|
        assert.equal! tile[:x], tile[:x].round
        assert.equal! tile[:y], tile[:y].round
      end
      assert.equal! left[:x] + left[:w], right[:x]
      assert.equal! left[:y] + left[:h], above[:y]
      assert.equal! camera.to_screen_space(camera.viewport_world), camera.viewport
    end
  end

  def test_culling_uses_the_snapped_viewport_at_a_fractional_camera_position(_args, assert)
    camera = CameraAtTestScale.new(x: 500, y: 500)
    camera.follow(x: 500.4, y: 500.4)
    # This thin strip is visible in the displayed viewport, but outside the unsnapped one.
    visible = { x: 340, y: 410, w: 0.25, h: 1 }
    hidden = visible.merge(x: 339)
    assert.equal! camera.find_all_intersect_viewport([hidden, visible]), [visible]
    assert.equal! camera.to_screen_space(visible)[:x], 0
  end

  def test_camera_conversions_round_trip_without_mutating_sprite_properties(_args, assert)
    camera = CameraAtTestScale.new(x: 0, y: 0)
    camera.follow(x: -300.25, y: -200.5)
    sprite = { x: -310.75, y: -180.25, w: 32, h: 48, path: 'sprites/test.png',
               anchor_x: 0.5, anchor_y: 0, source_x: 64, source_y: 32, source_w: 32, source_h: 48,
               r: 90, g: 255, b: 160 }
    original = sprite.dup
    screen = camera.to_screen_space(sprite)
    restored = camera.to_world_space(screen)

    assert.equal! sprite, original
    %i[x y w h].each { |key| assert.true! (restored[key] - sprite[key]).abs < 0.00001 }
    %i[path anchor_x anchor_y source_x source_y source_w source_h r g b].each do |key|
      assert.equal! screen[key], sprite[key]
      assert.equal! restored[key], sprite[key]
    end
    point = { x: -287.125, y: -190.75 }
    restored_point = camera.to_world_space(camera.to_screen_space(point))
    %i[x y].each { |key| assert.true! (restored_point[key] - point[key]).abs < 0.00001 }
  end

  def test_camera_converts_collections_in_both_directions(_args, assert)
    camera = CameraAtTestScale.new(x: 500, y: 500)
    world = [{ x: 500, y: 500 }, [{ x: 501, y: 502, w: 16, h: 8 }], nil]
    screen = [{ x: 160, y: 90 }, [{ x: 161, y: 92, w: 16, h: 8 }], nil]

    assert.equal! camera.to_screen_space(world), screen
    assert.equal! camera.to_world_space(screen), world
  end

  def test_visibility_uses_anchored_artwork_and_preserves_drawing_order(_args, assert)
    camera = CameraAtTestScale.new(x: 500, y: 500)
    view = camera.viewport_world
    # Anchors put part of each sprite inside the view even though its x is outside.
    right = { x: view[:x] + view[:w] + 4, y: 500, w: 32, h: 32, anchor_x: 0.5 }
    hidden = right.merge(x: right[:x] + 32)
    inside = { x: 500, y: 500, w: 32, h: 32 }
    left = { x: view[:x] - 4, y: 500, w: 32, h: 32, anchor_x: 0.5 }

    assert.equal! camera.find_all_intersect_viewport([right, hidden, inside, left]), [right, inside, left]
  end
end
