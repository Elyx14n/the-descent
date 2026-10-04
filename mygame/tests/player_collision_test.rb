# frozen_string_literal: true

require 'app/player'
require 'app/collision_playground'

def collision_player(left = 0, bottom = 0)
  player = Descent::Player.new(x: 0, y: bottom)
  player.x = left - player.collision_rect[:x]
  player
end

def collision_input(horizontal, vertical, sneak: false)
  { dx: horizontal, dy: vertical, sneak: sneak, toggle_lamp: false }
end

# Each case approaches a face from a valid spawn, then continues pushing against it.
def test_player_stops_at_all_wall_faces(_args, assert)
  cases = [
    [1, 0, { x: 26, y: -100, w: 20, h: 200 }, :x, 2],
    [-1, 0, { x: -21, y: -100, w: 20, h: 200 }, :x, -1],
    [0, 1, { x: -100, y: 8, w: 200, h: 20 }, :y, 2],
    [0, -1, { x: -100, y: -21, w: 200, h: 20 }, :y, -1]
  ]
  cases.each do |horizontal, vertical, wall, axis, expected|
    player = collision_player
    20.times { player.update_controls(collision_input(horizontal, vertical), walls: [wall]) }
    assert.equal! player.collision_rect[axis], expected
    assert.false! Geometry.intersect_rect?(player.collision_rect, wall)
  end
end

def test_player_slides_along_wall(_args, assert)
  player = collision_player
  wall = { x: 24, y: -100, w: 20, h: 200 }
  10.times { player.update_controls(collision_input(1, 1), walls: [wall]) }
  assert.equal! player.collision_rect[:x], 0
  assert.true! (player.y - (30 / Math.sqrt(2))).abs < 0.0001
  assert.false! Geometry.intersect_rect?(player.collision_rect, wall)
end

def test_wall_order_does_not_change_nearest_stop(_args, assert)
  walls = [{ x: 26, y: -100, w: 20, h: 200 }, { x: 25, y: -100, w: 20, h: 200 }]
  [walls, walls.reverse].each do |ordered|
    player = collision_player
    player.update_controls(collision_input(1, 0), walls: ordered)
    assert.equal! player.collision_rect[:x], 1
    assert.true! Geometry.find_all_intersect_rect(player.collision_rect, walls).empty?
  end
end

def test_player_stops_in_corner(_args, assert)
  walls = [{ x: 26, y: -100, w: 20, h: 200 }, { x: -100, y: 8, w: 200, h: 20 }]
  [walls, walls.reverse].each do |ordered|
    player = collision_player
    20.times { player.update_controls(collision_input(1, 1), walls: ordered) }
    assert.equal! player.collision_rect[:x], 2
    assert.equal! player.collision_rect[:y], 2
    assert.true! Geometry.find_all_intersect_rect(player.collision_rect, walls).empty?
    assert.false! player.moving?
  end
end

def test_player_passes_doorway_but_not_wall(_args, assert)
  clear = collision_player(924, 300)
  blocked = collision_player(910, 300)
  30.times do
    [clear, blocked].each do |player|
      player.update_controls(collision_input(0, 1), walls: Descent::CollisionPlayground::WALLS)
    end
  end
  assert.equal! clear.collision_rect[:y], 390
  assert.equal! blocked.collision_rect[:y], 334
end

def test_movement_speed_and_sneak_remain_consistent(_args, assert)
  walk = collision_player
  diagonal = collision_player
  sneak = collision_player
  walk.update(collision_input(1, 0))
  diagonal.update(collision_input(1, 1))
  sneak.update(collision_input(1, 0, sneak: true))
  distance = Math.sqrt((diagonal.collision_rect[:x]**2) + (diagonal.collision_rect[:y]**2))
  assert.true! (distance - walk.collision_rect[:x]).abs < 0.0001
  assert.equal! sneak.collision_rect[:x], walk.collision_rect[:x] / 2
end
