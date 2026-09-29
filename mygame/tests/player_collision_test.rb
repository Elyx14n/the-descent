# frozen_string_literal: true

require 'app/player'
require 'app/collision_playground'

def collision_player(left = 0, bottom = 0)
  player = Descent::Player.spawn(pos_x: 0, pos_y: bottom)
  player.pos_x = left - player.collider[:x]
  player
end

def collision_input(horizontal, vertical, sneak: false)
  { move_x: horizontal, move_y: vertical, sneak: sneak, toggle_lamp: false }
end

# Each case approaches a face from a valid spawn, then continues pushing against it.
def test_player_stops_at_all_wall_faces(_args, assert)
  cases = [
    [1, 0, { x: 26, y: -100, w: 20, h: 200 }, :x, 2],
    [-1, 0, { x: -21, y: -100, w: 20, h: 200 }, :x, -1],
    [0, 1, { x: -100, y: 18, w: 200, h: 20 }, :y, 2],
    [0, -1, { x: -100, y: -21, w: 200, h: 20 }, :y, -1]
  ]
  cases.each do |horizontal, vertical, wall, axis, expected|
    player = collision_player
    20.times { player.update(collision_input(horizontal, vertical), walls: [wall]) }
    assert.equal! player.collider[axis], expected
    assert.false! Geometry.intersect_rect?(player.collider, wall)
  end
end

def test_player_slides_along_wall(_args, assert)
  player = collision_player
  wall = { x: 24, y: -100, w: 20, h: 200 }
  10.times { player.update(collision_input(1, 1), walls: [wall]) }
  assert.equal! player.collider[:x], 0
  assert.true! (player.pos_y - (30 / Math.sqrt(2))).abs < 0.0001
  assert.false! Geometry.intersect_rect?(player.collider, wall)
end

def test_wall_order_does_not_change_nearest_stop(_args, assert)
  walls = [{ x: 26, y: -100, w: 20, h: 200 }, { x: 25, y: -100, w: 20, h: 200 }]
  [walls, walls.reverse].each do |ordered|
    player = collision_player
    player.update(collision_input(1, 0), walls: ordered)
    assert.equal! player.collider[:x], 1
    assert.true! Geometry.find_all_intersect_rect(player.collider, walls).empty?
  end
end

def test_player_stops_in_corner(_args, assert)
  walls = [{ x: 26, y: -100, w: 20, h: 200 }, { x: -100, y: 18, w: 200, h: 20 }]
  [walls, walls.reverse].each do |ordered|
    player = collision_player
    20.times { player.update(collision_input(1, 1), walls: ordered) }
    assert.equal! player.collider[:x], 2
    assert.equal! player.collider[:y], 2
    assert.true! Geometry.find_all_intersect_rect(player.collider, walls).empty?
    assert.equal! player.sprite[:source_x], 0
  end
end

def test_player_passes_doorway_but_not_wall(_args, assert)
  clear = collision_player(924, 300)
  blocked = collision_player(910, 300)
  30.times do
    [clear, blocked].each do |player|
      player.update(collision_input(0, 1), walls: Descent::CollisionPlayground::WALLS)
    end
  end
  assert.equal! clear.collider[:y], 390
  assert.equal! blocked.collider[:y], 324
end

def test_movement_speed_and_sneak_remain_consistent(_args, assert)
  walk = collision_player
  diagonal = collision_player
  sneak = collision_player
  walk.update(collision_input(1, 0))
  diagonal.update(collision_input(1, 1))
  sneak.update(collision_input(1, 0, sneak: true))
  distance = Math.sqrt((diagonal.collider[:x]**2) + (diagonal.collider[:y]**2))
  assert.true! (distance - walk.collider[:x]).abs < 0.0001
  assert.equal! sneak.collider[:x], walk.collider[:x] / 2
end
