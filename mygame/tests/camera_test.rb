# frozen_string_literal: true

require 'app/camera'
require 'app/player'

# Control display scale without resizing the native window during a unit test.
class CameraAtTestScale < Descent::Camera
  def initialize(bounds:, pixel_scale: 1)
    @test_pixel_scale = pixel_scale
    super(bounds: bounds)
  end

  private

  def pixel_scale
    @test_pixel_scale
  end
end

CAMERA_TEST_BOUNDS = { x: 21, y: 27, w: 700, h: 400 }.freeze

def test_camera_target_size_is_independent_of_world_size_and_origin(args, assert)
  [{ x: 21, y: 27, w: 100, h: 100 },
   { x: -20_000, y: -30_000, w: 100_000, h: 100_000 }].each do |bounds|
    camera = CameraAtTestScale.new(bounds: bounds)
    target = camera.scene(args)
    assert.equal! [target.w, target.h], [320, 180]
  end
end

def test_world_smaller_than_the_viewport_is_centered_whole(_args, assert)
  camera = CameraAtTestScale.new(bounds: { x: 21, y: 27, w: 100, h: 100 })
  camera.follow(x: -500, y: -500)

  assert.equal! [camera.x, camera.y], [71, 77]
  bottom_left = camera.to_screen(x: 21, y: 27)
  top_right = camera.to_screen(x: 121, y: 127)
  assert.equal! bottom_left, { x: 110, y: 40 }
  assert.equal! top_right, { x: 210, y: 140 }
end

def test_small_world_axis_centers_while_large_axis_scrolls(_args, assert)
  camera = CameraAtTestScale.new(bounds: { x: -50, y: -500, w: 100, h: 1000 })
  camera.follow(x: 1000, y: 200.25)

  assert.equal! camera.x, 0
  assert.equal! camera.y, 200.25
  assert.equal! camera.to_screen(x: 0, y: 200.25), { x: 160, y: 90.25 }
end

def test_large_room_is_larger_than_the_viewport_so_the_camera_scrolls(_args, assert)
  camera = CameraAtTestScale.new(bounds: CAMERA_TEST_BOUNDS)

  left = camera.follow(x: 100, y: 200).viewport_world
  right = camera.follow(x: 600, y: 200).viewport_world

  assert.true! right[:x] > left[:x]
  assert.equal! camera.viewport_sprite, { x: 0, y: 0, w: 320, h: 180, path: Descent::Camera::TARGET }
end

def test_diagonal_movement_keeps_the_drawn_player_fixed_at_screen_center(_args, assert)
  camera = CameraAtTestScale.new(bounds: CAMERA_TEST_BOUNDS)
  [false, true].each do |sneak|
    [-1, 1].product([-1, 1]).each do |dx, dy|
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
  camera = CameraAtTestScale.new(bounds: CAMERA_TEST_BOUNDS)
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
    camera = CameraAtTestScale.new(bounds: CAMERA_TEST_BOUNDS, pixel_scale: scale)
    centered = [((160 * scale) + 0.5).floor.fdiv(scale),
                (((90 * scale) + 0.5).floor.fdiv(scale) - 24)]
    [-1, 1].product([-1, 1]).each do |dx, dy|
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
        %i[x y].each do |axis|
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
        %i[x y].each_with_index do |axis, index|
          assert.true! (drawn[axis] - centered[index]).abs < 0.00001
        end
        previous = left
      end
    end
  end
end

def test_a_clamped_camera_never_walks_the_player_backwards(_args, assert)
  camera = CameraAtTestScale.new(bounds: CAMERA_TEST_BOUNDS)
  player = Descent::Player.new(x: 40, y: 60)
  input = { dx: 1, dy: 1, sneak: false, toggle_lamp: false }

  on_screen = 20.times.map do
    player.update_controls(input)
    camera.follow(x: player.x, y: player.y)
    camera.to_draw_space(player.sprite_to_primitive)[:x]
  end

  assert.true!(on_screen.each_cons(2).all? { |before, after| after >= before })
  assert.true! on_screen.last > on_screen.first
end

def test_to_screen_tracks_a_world_point_as_the_camera_moves(_args, assert)
  camera = CameraAtTestScale.new(bounds: CAMERA_TEST_BOUNDS)
  marker = { x: 351, y: 227 }

  near = camera.follow(**marker).to_screen(**marker)
  assert.equal! near, { x: 160, y: 90 }

  panned = camera.follow(x: 381, y: 227).to_screen(**marker)
  assert.equal! panned, { x: 130, y: 90 }
end

def test_large_world_scrolls_and_clamps_to_its_edges(_args, assert)
  bounds = { x: -1000, y: -2000, w: 3000, h: 4000 }
  camera = CameraAtTestScale.new(bounds: bounds)

  centered = camera.follow(x: -400.25, y: -500.5).viewport_world
  assert.equal! centered[:x], -560
  assert.equal! centered[:y], -590

  at_origin = camera.follow(x: -50_000, y: -50_000).viewport_world
  assert.true! (at_origin[:x] - bounds[:x]).abs < 0.00001
  assert.equal! at_origin[:y], bounds[:y]

  at_far_edge = camera.follow(x: 50_000, y: 50_000).viewport_world
  assert.true! (at_far_edge[:x] + at_far_edge[:w] - 2000).abs < 0.00001
  assert.equal! at_far_edge[:y] + at_far_edge[:h], 2000
end

def test_drawn_player_remains_stable_at_half_pixel_ties_in_positive_and_negative_worlds(_args, assert)
  camera = CameraAtTestScale.new(bounds: { x: -1000, y: -1000, w: 2000, h: 2000 })
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

def test_player_drawing_crosses_the_camera_clamp_without_backwards_steps(_args, assert)
  camera = CameraAtTestScale.new(bounds: { x: 0, y: 0, w: 1000, h: 1000 })
  player = Descent::Player.new(x: 154.25, y: 500.25)
  xs = 30.times.map do
    player.update_controls({ dx: 1, dy: 1, sneak: true, toggle_lamp: false })
    camera.follow(x: player.x, y: player.y)
    sprite = camera.to_draw_space(player.sprite_to_primitive)
    assert.equal! sprite[:y], 66
    sprite[:x]
  end
  assert.true!(xs.each_cons(2).all? { |before, after| after >= before })
  assert.equal! xs.last, 160
end

def test_camera_preserves_fractional_follow_positions(_args, assert)
  camera = CameraAtTestScale.new(bounds: { x: 0, y: 0, w: 1000, h: 1000 })
  camera.follow(x: 500.2, y: 500.4)

  assert.equal! [camera.x, camera.y], [500.2, 500.4]
  screen = camera.to_screen(x: 500.2, y: 500.4)
  assert.true! (screen[:x] - 160.2).abs < 0.00001
  assert.true! (screen[:y] - 90.4).abs < 0.00001
  assert.equal! camera.viewport_world[:w], 320
end

def test_adjacent_tiles_stay_on_whole_pixels_during_fractional_camera_motion(_args, assert)
  camera = CameraAtTestScale.new(bounds: { x: -1000, y: -1000, w: 2000, h: 2000 })
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
  camera = CameraAtTestScale.new(bounds: { x: 0, y: 0, w: 1000, h: 1000 })
  camera.follow(x: 500.4, y: 500.4)
  # This thin strip is visible in the displayed viewport, but outside the unsnapped one.
  visible = { x: 340, y: 410, w: 0.25, h: 1 }
  hidden = visible.merge(x: 339)
  assert.equal! camera.find_all_intersect_viewport([hidden, visible]), [visible]
  assert.equal! camera.to_screen_space(visible)[:x], 0
end

def test_camera_conversions_round_trip_without_mutating_sprite_properties(_args, assert)
  camera = CameraAtTestScale.new(bounds: { x: -1000, y: -1000, w: 2000, h: 2000 })
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
  camera = CameraAtTestScale.new(bounds: { x: 0, y: 0, w: 1000, h: 1000 })
  world = [{ x: 500, y: 500 }, [{ x: 501, y: 502, w: 16, h: 8 }], nil]
  screen = [{ x: 160, y: 90 }, [{ x: 161, y: 92, w: 16, h: 8 }], nil]

  assert.equal! camera.to_screen_space(world), screen
  assert.equal! camera.to_world_space(screen), world
end

def test_visibility_uses_anchored_artwork_and_preserves_drawing_order(_args, assert)
  camera = CameraAtTestScale.new(bounds: { x: 0, y: 0, w: 1000, h: 1000 })
  view = camera.viewport_world
  # Anchors put part of each sprite inside the view even though its x is outside.
  right = { x: view[:x] + view[:w] + 4, y: 500, w: 32, h: 32, anchor_x: 0.5 }
  hidden = right.merge(x: right[:x] + 32)
  inside = { x: 500, y: 500, w: 32, h: 32 }
  left = { x: view[:x] - 4, y: 500, w: 32, h: 32, anchor_x: 0.5 }

  assert.equal! camera.find_all_intersect_viewport([right, hidden, inside, left]), [right, inside, left]
end
