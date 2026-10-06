# frozen_string_literal: true

require 'app/player'
require 'tests/support/player_helpers'

def test_player_facing_still_selects_rows_while_animation_advances(_args, assert)
  player = Descent::Player.new
  { north: 64, south: 192, east: 0, west: 128 }.each do |facing, source_y|
    player.reset(x: 100, y: 100, facing: facing)
    assert.equal! player.sprite_to_primitive[:source_y], source_y
    9.times { player.update_animation }
    primitive = player.sprite_to_primitive
    assert.equal! primitive[:source_y], source_y
    assert.equal! primitive[:source_x], 64
  end
end

def test_player_can_render_before_first_update_including_when_created_dead(_args, assert)
  [100, 0].each do |sanity|
    player = Descent::Player.new(sanity: sanity)
    sprite = player.sprite_to_primitive
    path = sanity.positive? ? 'sprites/player_idle_lamp_on.png' : 'sprites/player_death.png'
    assert.equal! sprite[:path], path
    assert.equal! sprite[:source_x], 0
    10.times { assert.equal! player.sprite_to_primitive, sprite }
    input = { dx: 0, dy: 0, sneak: false, toggle_lamp: false }
    8.times do
      step_player(player, input)
      assert.equal! player.sprite_to_primitive[:source_x], 0
    end
    step_player(player, input)
    assert.equal! player.sprite_to_primitive[:source_x], 64
  end
end

def test_reset_while_walking_clears_movement_and_restarts_idle(_args, assert)
  player = Descent::Player.new
  input = { dx: 1, dy: 0, sneak: false, toggle_lamp: false }
  17.times { step_player(player, input) }
  player.lamp_on = false
  player.sanity = 25
  player.reset(x: 20, y: 30, facing: :west)

  assert.false! player.moving?
  assert.equal! player.facing, :west
  assert.equal! player.sanity, 100
  assert.true! player.lamp_on
  assert.equal! player.sprite_to_primitive[:path], 'sprites/player_idle_lamp_on.png'
  8.times do
    step_player(player, input.merge(dx: 0))
    assert.equal! player.sprite_to_primitive[:source_x], 0
  end
  step_player(player, input.merge(dx: 0))
  assert.equal! player.sprite_to_primitive[:source_x], 64
end

def test_player_sprite_and_collider_share_foot_position(_args, assert)
  player = Descent::Player.new(x: 180.25, y: 180.75)
  sprite = player.sprite_to_primitive
  feet = player.collision_rect
  left = sprite[:x] - (sprite[:w] * sprite[:anchor_x])
  scale = sprite[:w].to_f / sprite[:source_w]

  assert.equal! sprite[:w], 192
  assert.equal! sprite[:h], 192
  assert.equal! feet[:x] + (feet[:w] / 2.0), left + (sprite[:w] / 2.0)
  # Standing frames have 24 transparent pixels below the feet.
  assert.equal! sprite[:y] + (24 * scale), feet[:y]
end

def test_lamp_spam_preserves_idle_and_walk_animation_timing(_args, assert)
  [0, 1].each do |dx|
    steady = Descent::Player.new(x: 180, y: 180)
    toggled = Descent::Player.new(x: 180, y: 180)
    input = { dx: dx, dy: 0, sneak: false, toggle_lamp: false }
    130.times do |tick|
      step_player(steady, input)
      step_player(toggled, input.merge(toggle_lamp: true))
      assert.equal! toggled.sprite_to_primitive[:source_x], steady.sprite_to_primitive[:source_x]
      assert.equal! toggled.sprite_to_primitive[:source_y], steady.sprite_to_primitive[:source_y]
      state = dx.zero? ? 'idle' : 'walk'
      lamp = tick.even? ? 'off' : 'on'
      assert.equal! toggled.sprite_to_primitive[:path], "sprites/player_#{state}_lamp_#{lamp}.png"
    end
  end
end

def test_idle_walk_and_death_transitions_still_reset_animation(_args, assert)
  player = Descent::Player.new(x: 180, y: 180)
  walk = { dx: 1, dy: 0, sneak: false, toggle_lamp: false }
  idle = walk.merge(dx: 0)
  17.times { step_player(player, walk) }
  assert.true! player.sprite_to_primitive[:source_x].positive?
  step_player(player, idle)
  assert.equal! player.sprite_to_primitive[:source_x], 0
  16.times { step_player(player, idle) }
  assert.true! player.sprite_to_primitive[:source_x].positive?
  step_player(player, walk)
  assert.equal! player.sprite_to_primitive[:source_x], 0
  16.times { step_player(player, walk) }
  player.sanity = 0
  step_player(player, walk)
  assert.equal! player.sprite_to_primitive[:source_x], 0
  assert.equal! player.sprite_to_primitive[:path], 'sprites/player_death.png'
end

def test_player_uses_all_eight_idle_and_walk_frames_with_either_lamp_state(_args, assert)
  [false, true].each do |lamp_on|
    [0, 1].each do |dx|
      player = Descent::Player.new(x: 180, y: 180)
      player.lamp_on = lamp_on
      input = { dx: dx, dy: 0, sneak: false, toggle_lamp: false }
      frames = []
      65.times do
        step_player(player, input)
        sprite = player.sprite_to_primitive
        frames << sprite[:source_x]
        state = dx.zero? ? 'idle' : 'walk'
        lamp = lamp_on ? 'on' : 'off'
        assert.equal! sprite[:path], "sprites/player_#{state}_lamp_#{lamp}.png"
        assert.true! sprite[:source_x] + sprite[:source_w] <= 512
        assert.true! sprite[:source_y] + sprite[:source_h] <= 256
      end
      assert.equal! frames.uniq.sort, [0, 64, 128, 192, 256, 320, 384, 448]
      assert.equal! frames.first, frames.last
    end
  end
end

def test_death_south_animation_anchors_feet_and_drops_head_south(_args, assert)
  player = Descent::Player.new(x: 180, y: 180)
  feet = player.collision_rect
  scale = player.scale

  # Standing facing south: feet align with collider:
  standing_sprite = player.sprite_to_primitive
  assert.equal! standing_sprite[:y] + (24 * scale), feet[:y]

  # Trigger death facing south:
  player.sanity = 0
  first_dead_frame = player.sprite_to_primitive
  assert.equal! first_dead_frame[:path], 'sprites/player_death.png'
  assert.equal! first_dead_frame[:source_x], 0
  assert.equal! first_dead_frame[:source_y], 192
  assert.equal! first_dead_frame[:y] + (24 * scale), feet[:y]

  # Advance through death animation to final frame (8 frames * 8 ticks):
  input = { dx: 0, dy: 0, sneak: false, toggle_lamp: false }
  60.times { step_player(player, input) }

  last_dead_frame = player.sprite_to_primitive
  assert.equal! last_dead_frame[:source_x], 448
  assert.equal! last_dead_frame[:source_y], 192

  # In final frame, the feet remain anchored at collider foot position:
  assert.equal! last_dead_frame[:y] + (24 * scale), feet[:y]

  # The fallen head is at DR_y = 7 in the source sprite:
  head_world_y = last_dead_frame[:y] + (7 * scale)
  # Head must be South (lower y in DragonRuby coordinates) of the feet:
  assert.true! head_world_y < feet[:y]
  assert.equal! head_world_y, feet[:y] - (17 * scale)
end
