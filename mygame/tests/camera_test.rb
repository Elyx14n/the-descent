# frozen_string_literal: true

require 'app/camera'
require 'app/collision_playground'

def test_camera_sizes_its_target_to_the_world_far_edge(args, assert)
  camera = Descent::Camera.new(bounds: { x: 21, y: 27, w: 384, h: 181 })
  target = camera.scene(args)

  # World coordinates are target coordinates, so the target must reach the
  # far edge rather than only cover the world's own width and height.
  assert.equal! target.w, 405
  assert.equal! target.h, 208
end

def test_playground_target_covers_its_whole_world(args, assert)
  camera = Descent::Camera.new(bounds: Descent::CollisionPlayground::WORLD_BOUNDS)
  target = camera.scene(args)

  assert.equal! target.w, 721
  assert.equal! target.h, 427
end

def test_world_smaller_than_the_viewport_is_centered_whole(_args, assert)
  camera = Descent::Camera.new(bounds: { x: 0, y: 0, w: 100, h: 100 })
  camera.follow(x: -500, y: -500) # Off in a corner; a world this small never scrolls.
  sprite = camera.viewport_sprite

  assert.equal! sprite[:path], Descent::Camera::TARGET
  assert.equal! [sprite[:source_x], sprite[:source_w]], [0, 100]
  assert.equal! [sprite[:source_y], sprite[:source_h]], [0, 100]
  # 100 world pixels at 3x, centered on a 1280x720 screen.
  assert.equal! [sprite[:x], sprite[:w]], [490, 300]
  assert.equal! [sprite[:y], sprite[:h]], [210, 300]
end

def test_playground_world_is_larger_than_the_viewport_so_the_camera_scrolls(_args, assert)
  camera = Descent::Camera.new(bounds: Descent::CollisionPlayground::WORLD_BOUNDS)

  left = camera.follow(x: 100, y: 200).viewport_sprite
  right = camera.follow(x: 600, y: 200).viewport_sprite

  assert.true! right[:source_x] > left[:source_x]
  # Both fill the screen rather than being centered in it.
  assert.equal! [left[:x], left[:w]], [0, 1280]
  assert.equal! [right[:x], right[:w]], [0, 1280]
end

def test_diagonal_movement_holds_the_player_still_on_screen(_args, assert)
  camera = Descent::Camera.new(bounds: Descent::CollisionPlayground::WORLD_BOUNDS)
  player = Descent::Player.new(x: 371, y: 227) # Clear of every world edge.
  input = { dx: 1, dy: 1, sneak: false, toggle_lamp: false }

  # A diagonal step is 1/sqrt(2) world pixels, so the position is never whole.
  on_screen = 20.times.map do
    player.update_controls(input)
    window = camera.follow(x: player.x, y: player.y).viewport_sprite
    sprite = player.sprite_to_primitive
    [(sprite[:x] - window[:source_x]) * Descent::Camera::ZOOM,
     (sprite[:y] - window[:source_y]) * Descent::Camera::ZOOM]
  end

  assert.true! player.x > 371 # It really moved.
  # While followed, it holds one screen position instead of oscillating.
  assert.equal! on_screen.uniq.length, 1
end

def test_a_clamped_camera_never_walks_the_player_backwards(_args, assert)
  camera = Descent::Camera.new(bounds: Descent::CollisionPlayground::WORLD_BOUNDS)
  player = Descent::Player.new(x: 40, y: 60) # Pinned against the left edge.
  input = { dx: 1, dy: 1, sneak: false, toggle_lamp: false }

  on_screen = 20.times.map do
    player.update_controls(input)
    window = camera.follow(x: player.x, y: player.y).viewport_sprite
    (player.sprite_to_primitive[:x] - window[:source_x]) * Descent::Camera::ZOOM
  end

  # The camera cannot scroll here, so the player crosses the screen in whole
  # magnified pixels. Monotonic steps are motion; any step back is jitter.
  assert.true!(on_screen.each_cons(2).all? { |before, after| after >= before })
  assert.true! on_screen.last > on_screen.first
end

def test_to_screen_tracks_a_world_point_as_the_camera_moves(_args, assert)
  camera = Descent::Camera.new(bounds: Descent::CollisionPlayground::WORLD_BOUNDS)
  marker = { x: 312, y: 131 }

  near = camera.follow(x: 312, y: 131).to_screen(**marker)
  # Centred on the marker, it lands in the middle of the screen.
  assert.true!((near[:x] - (Descent::Camera::SCREEN_W / 2)).abs <= Descent::Camera::ZOOM)

  # Panning right moves the marker left on screen, by the magnified distance.
  panned = camera.follow(x: 362, y: 131).to_screen(**marker)
  assert.equal! panned[:x], near[:x] - (50 * Descent::Camera::ZOOM)
  assert.equal! panned[:y], near[:y]
end

def test_large_world_scrolls_and_clamps_to_its_edges(_args, assert)
  camera = Descent::Camera.new(bounds: { x: 0, y: 0, w: 1000, h: 1000 })

  centered = camera.follow(x: 500, y: 500).viewport_sprite
  assert.equal! [centered[:x], centered[:w]], [0, 1280]
  assert.equal! [centered[:y], centered[:h]], [0, 720]
  assert.equal! centered[:source_x], 287 # 500 - (1280 / 3 / 2), rounded.
  assert.equal! centered[:source_y], 380 # 500 - (720 / 3 / 2).

  at_origin = camera.follow(x: -5000, y: -5000).viewport_sprite
  assert.equal! [at_origin[:source_x], at_origin[:source_y]], [0, 0]

  at_far_edge = camera.follow(x: 5000, y: 5000).viewport_sprite
  assert.equal! at_far_edge[:source_x], 573 # 1000 - 1280 / 3, rounded.
  assert.equal! at_far_edge[:source_y], 760 # 1000 - 720 / 3.
end

def test_scrolling_origin_snaps_to_whole_world_pixels(_args, assert)
  camera = Descent::Camera.new(bounds: { x: 0, y: 0, w: 1000, h: 1000 })

  # Magnified pixels only stay square while the sampled origin is an integer.
  [500.2, 500.4, 500.9, 501.5].each do |position|
    sprite = camera.follow(x: position, y: position).viewport_sprite
    assert.equal! sprite[:source_x], sprite[:source_x].to_i
    assert.equal! sprite[:source_y], sprite[:source_y].to_i
  end
end

def test_playground_renders_its_world_through_the_camera(args, assert)
  spawn = Descent::CollisionPlayground::PLAYER_SPAWN
  args.state.player = Descent::Player.new(x: spawn[:x], y: spawn[:y])
  args.state.playground = { walls: Descent::CollisionPlayground::WALLS.map(&:dup), show_bounds: true }
  Descent::CollisionPlayground.tick(args, tick_count: 0)

  scene = args.outputs[Descent::Camera::TARGET]
  world = scene.primitives.flatten
  # The player and both props are drawn in world pixels, inside the room.
  assert.true!(world.any? { |p| p[:path] == 'sprites/player_idle_lamp_on.png' && p[:w] == 32 })
  assert.true!(world.all? { |p| p[:x] < Descent::Camera::SCREEN_W })

  # Exactly one screen-space primitive carries the world: the viewport blit.
  blits = args.outputs.primitives.flatten.select { |p| p[:path] == Descent::Camera::TARGET }
  assert.equal! blits.length, 1
  assert.equal! [blits.first[:x], blits.first[:w]], [0, Descent::Camera::SCREEN_W]
end
