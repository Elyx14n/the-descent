# frozen_string_literal: true

require 'app/entity'
require 'app/enemy'
require 'app/player'

def test_static_entity_renders_and_scales_its_collider(_args, assert)
  entity = Descent::Entity.new(
    x: 40, y: 60, scale: 2,
    sprite: Descent::Sprite.new(path: 'sprites/enemy.png', frame_size: 64, foot_padding: 6),
    collider: Descent::Collider.new(w: 24, h: 8)
  )
  sprite = entity.sprite_to_primitive
  assert.equal! sprite[:path], 'sprites/enemy.png'
  assert.equal! [sprite[:x], sprite[:y], sprite[:w], sprite[:h]], [40, 48, 128, 128]
  assert.equal! entity.collision_rect, { x: 16, y: 60, w: 48, h: 16 }
end

def test_enemy_uses_components_for_movement_animation_and_reset(_args, assert)
  enemy = Descent::Enemy.new(x: 100, y: 100)
  assert.equal! enemy.sprite_to_primitive[:path], 'sprites/enemy.png'
  enemy.update
  assert.false! enemy.moving?
  frames = []
  49.times do
    enemy.update(dx: 1)
    enemy.update_animation
    frames << enemy.sprite_to_primitive[:source_x]
  end
  assert.equal! enemy.x, 247
  assert.equal! frames.uniq, [0, 64, 128, 192]
  assert.equal! frames.first, frames.last
  enemy.reset(x: 50, y: 60)
  assert.false! enemy.moving?
  assert.equal! enemy.facing, :south
  assert.equal! enemy.sprite_to_primitive[:source_x], 0
  assert.equal! enemy.collision_rect, { x: 14, y: 60, w: 72, h: 24 }
end

def test_scaled_player_stops_with_its_feet_at_the_wall(_args, assert)
  player = Descent::Player.new(x: 20, y: 0, scale: 2)
  wall = { x: 30, y: 0, w: 20, h: 20 }
  10.times do
    player.update_controls({ dx: 1, dy: 0, sneak: false, toggle_lamp: false }, walls: [wall])
  end
  feet = player.collision_rect
  assert.equal! feet[:x] + feet[:w], wall[:x]
  assert.false! Geometry.intersect_rect?(feet, wall)
  assert.equal! player.sprite_to_primitive[:w], 64
end
