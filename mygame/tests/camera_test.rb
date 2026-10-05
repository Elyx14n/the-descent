# frozen_string_literal: true

require 'app/camera'
require 'app/collision_playground'

def test_camera_target_size_is_independent_of_world_size_and_origin(args, assert)
  [{ x: 21, y: 27, w: 100, h: 100 },
   { x: -20_000, y: -30_000, w: 100_000, h: 100_000 }].each do |bounds|
    camera = Descent::Camera.new(bounds: bounds)
    target = camera.scene(args)
    assert.equal! [target.w, target.h], [320, 180]
  end
end

def test_world_smaller_than_the_viewport_is_centered_whole(_args, assert)
  camera = Descent::Camera.new(bounds: { x: 21, y: 27, w: 100, h: 100 })
  camera.follow(x: -500, y: -500)

  assert.equal! [camera.x, camera.y], [71, 77]
  bottom_left = camera.to_screen(x: 21, y: 27)
  top_right = camera.to_screen(x: 121, y: 127)
  assert.equal! bottom_left, { x: 110, y: 40 }
  assert.equal! top_right, { x: 210, y: 140 }
end

def test_small_world_axis_centers_while_large_axis_scrolls(_args, assert)
  camera = Descent::Camera.new(bounds: { x: -50, y: -500, w: 100, h: 1000 })
  camera.follow(x: 1000, y: 200.25)

  assert.equal! camera.x, 0
  assert.equal! camera.y, 200.25
  assert.equal! camera.to_screen(x: 0, y: 200.25), { x: 160, y: 90 }
end

def test_playground_world_is_larger_than_the_viewport_so_the_camera_scrolls(_args, assert)
  camera = Descent::Camera.new(bounds: Descent::CollisionPlayground::WORLD_BOUNDS)

  left = camera.follow(x: 100, y: 200).viewport_world
  right = camera.follow(x: 600, y: 200).viewport_world

  assert.true! right[:x] > left[:x]
  assert.equal! camera.viewport_sprite, { x: 0, y: 0, w: 320, h: 180, path: Descent::Camera::TARGET }
end

def test_diagonal_movement_holds_the_player_still_on_screen(_args, assert)
  camera = Descent::Camera.new(bounds: Descent::CollisionPlayground::WORLD_BOUNDS)
  player = Descent::Player.new(x: 371, y: 227) # Clear of every world edge.
  input = { dx: 1, dy: 1, sneak: false, toggle_lamp: false }

  20.times do
    player.update_controls(input)
    camera.follow(x: player.x, y: player.y)
    sprite = camera.to_screen_space(player.sprite_to_primitive)
    # The horizontal feet anchor stays centered; padding puts the sprite 3px below it.
    assert.true! (sprite[:x] - 160).abs < 0.00001
    assert.true! (sprite[:y] - 87).abs < 0.00001
    assert.equal! [sprite[:w], sprite[:h]], [32, 32]
  end

  assert.true! player.x > 371
end

def test_a_clamped_camera_never_walks_the_player_backwards(_args, assert)
  camera = Descent::Camera.new(bounds: Descent::CollisionPlayground::WORLD_BOUNDS)
  player = Descent::Player.new(x: 40, y: 60)
  input = { dx: 1, dy: 1, sneak: false, toggle_lamp: false }

  on_screen = 20.times.map do
    player.update_controls(input)
    camera.follow(x: player.x, y: player.y)
    camera.to_screen_space(player.sprite_to_primitive)[:x]
  end

  assert.true!(on_screen.each_cons(2).all? { |before, after| after > before })
end

def test_to_screen_tracks_a_world_point_as_the_camera_moves(_args, assert)
  camera = Descent::Camera.new(bounds: Descent::CollisionPlayground::WORLD_BOUNDS)
  marker = { x: 351, y: 227 }

  near = camera.follow(**marker).to_screen(**marker)
  assert.equal! near, { x: 160, y: 90 }

  panned = camera.follow(x: 381, y: 227).to_screen(**marker)
  assert.equal! panned, { x: 130, y: 90 }
end

def test_large_world_scrolls_and_clamps_to_its_edges(_args, assert)
  bounds = { x: -1000, y: -2000, w: 3000, h: 4000 }
  camera = Descent::Camera.new(bounds: bounds)

  centered = camera.follow(x: -400.25, y: -500.5).viewport_world
  assert.equal! centered[:x], -560.25
  assert.equal! centered[:y], -590.5

  at_origin = camera.follow(x: -50_000, y: -50_000).viewport_world
  assert.true! (at_origin[:x] - bounds[:x]).abs < 0.00001
  assert.equal! at_origin[:y], bounds[:y]

  at_far_edge = camera.follow(x: 50_000, y: 50_000).viewport_world
  assert.true! (at_far_edge[:x] + at_far_edge[:w] - 2000).abs < 0.00001
  assert.equal! at_far_edge[:y] + at_far_edge[:h], 2000
end

def test_camera_preserves_fractional_follow_positions(_args, assert)
  camera = Descent::Camera.new(bounds: { x: 0, y: 0, w: 1000, h: 1000 })
  camera.follow(x: 500.2, y: 500.4)

  assert.equal! [camera.x, camera.y], [500.2, 500.4]
  assert.equal! camera.to_screen(x: 500.2, y: 500.4), { x: 160, y: 90 }
  assert.equal! camera.viewport_world[:w], 320
end

def test_camera_conversions_round_trip_without_mutating_sprite_properties(_args, assert)
  camera = Descent::Camera.new(bounds: { x: -1000, y: -1000, w: 2000, h: 2000 })
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
  camera = Descent::Camera.new(bounds: { x: 0, y: 0, w: 1000, h: 1000 })
  world = [{ x: 500, y: 500 }, [{ x: 501, y: 502, w: 16, h: 8 }], nil]
  screen = [{ x: 160, y: 90 }, [{ x: 161, y: 92, w: 16, h: 8 }], nil]

  assert.equal! camera.to_screen_space(world), screen
  assert.equal! camera.to_world_space(screen), world
end

def test_visibility_uses_anchored_artwork_and_preserves_drawing_order(_args, assert)
  camera = Descent::Camera.new(bounds: { x: 0, y: 0, w: 1000, h: 1000 })
  view = camera.viewport_world
  # Anchors put part of each sprite inside the view even though its x is outside.
  right = { x: view[:x] + view[:w] + 4, y: 500, w: 32, h: 32, anchor_x: 0.5 }
  hidden = right.merge(x: right[:x] + 32)
  inside = { x: 500, y: 500, w: 32, h: 32 }
  left = { x: view[:x] - 4, y: 500, w: 32, h: 32, anchor_x: 0.5 }

  assert.equal! camera.find_all_intersect_viewport([right, hidden, inside, left]), [right, inside, left]
end

def test_playground_renders_visible_world_and_debug_bounds_through_the_camera(args, assert)
  player = Descent::Player.new(x: 600.25, y: 300.5)
  args.state.player = player
  walls = Descent::CollisionPlayground::WALLS.map(&:dup)
  walls << { id: :offscreen, x: 1000, y: 300, w: 32, h: 32 }
  walls << { id: :partial, x: 395, y: 300, w: 16, h: 8 }
  args.state.playground = { walls: walls, show_bounds: true }
  Descent::CollisionPlayground.tick(args, tick_count: 0)

  camera = args.state.playground[:camera]
  scene = args.outputs[Descent::Camera::TARGET]
  primitives = scene.primitives.flatten
  sprite = primitives.find { |p| p[:path] == 'sprites/player_idle_lamp_on.png' }
  assert.equal! sprite, camera.to_screen_space(player.sprite_to_primitive)
  assert.equal! [sprite[:w], sprite[:h]], [32, 32]
  visible_ids = primitives.map { |p| p[:id] }
  assert.false! visible_ids.include?(:offscreen)
  # Retain the wall that straddles the left edge while culling the distant red tile.
  assert.true! visible_ids.include?(:partial)
  assert.false!(primitives.any? { |p| p.values_at(:r, :g) == [220, 50] })
  foot_border = scene.borders.flatten.find { |p| p.values_at(:r, :g) == [90, 255] }
  assert.equal! foot_border, camera.to_screen_space(player.collision_rect.merge(r: 90, g: 255, b: 160))

  blits = args.outputs.primitives.flatten.select { |p| p[:path] == Descent::Camera::TARGET }
  assert.equal! blits, [camera.viewport_sprite]
  assert.equal! [scene.w, scene.h], [320, 180]
end

def test_playground_refreshes_camera_bounds_without_resetting_player(args, assert)
  player = Descent::Player.new(x: 371.25, y: 227.5)
  stale = Descent::Camera.new(bounds: { x: 0, y: 0, w: 100, h: 100 })
  args.state.player = player
  args.state.playground = { walls: [], show_bounds: false, camera: stale }

  Descent::CollisionPlayground.tick(args, tick_count: 0)

  assert.true! args.state.player.equal?(player)
  camera = args.state.playground[:camera]
  assert.false! camera.equal?(stale)
  assert.true! camera.bounds.equal?(Descent::CollisionPlayground::WORLD_BOUNDS)
  assert.equal! [camera.x, camera.y], [player.x, player.y]
end
