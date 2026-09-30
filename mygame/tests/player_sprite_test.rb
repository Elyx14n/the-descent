# frozen_string_literal: true

require 'app/player'
require 'tests/support/player_helpers'

def test_player_sprite_and_collider_share_foot_position(_args, assert)
  player = Descent::Player.spawn(x: 180, y: 180)
  sprite = player.sprite
  feet = player.collider
  left = sprite[:x] - (sprite[:w] * sprite[:anchor_x])
  scale = sprite[:w].to_f / sprite[:source_w]

  assert.equal! sprite[:w], 96
  assert.equal! sprite[:h], 96
  assert.equal! feet[:x] + (feet[:w] / 2.0), left + (sprite[:w] / 2.0)
  # Standing frames have three transparent pixels below the feet.
  assert.equal! sprite[:y] + (3 * scale), feet[:y]
end

def test_lamp_spam_preserves_idle_and_walk_animation_timing(_args, assert)
  [0, 1].each do |dx|
    steady = Descent::Player.spawn(x: 180, y: 180)
    toggled = Descent::Player.spawn(x: 180, y: 180)
    input = { dx: dx, dy: 0, sneak: false, toggle_lamp: false }
    130.times do |tick|
      step_player(steady, input)
      step_player(toggled, input.merge(toggle_lamp: true))
      assert.equal! toggled.sprite[:source_x], steady.sprite[:source_x]
      assert.equal! toggled.sprite[:source_y], steady.sprite[:source_y]
      state = dx.zero? ? 'idle' : 'walk'
      lamp = tick.even? ? 'off' : 'on'
      assert.equal! toggled.sprite[:path], "sprites/player_#{state}_lamp_#{lamp}.png"
    end
  end
end

def test_idle_walk_and_death_transitions_still_reset_animation(_args, assert)
  player = Descent::Player.spawn(x: 180, y: 180)
  walk = { dx: 1, dy: 0, sneak: false, toggle_lamp: false }
  idle = walk.merge(dx: 0)
  17.times { step_player(player, walk) }
  assert.true! player.sprite[:source_x].positive?
  step_player(player, idle)
  assert.equal! player.sprite[:source_x], 0
  16.times { step_player(player, idle) }
  assert.true! player.sprite[:source_x].positive?
  step_player(player, walk)
  assert.equal! player.sprite[:source_x], 0
  16.times { step_player(player, walk) }
  player.sanity = 0
  step_player(player, walk)
  assert.equal! player.sprite[:source_x], 0
  assert.equal! player.sprite[:path], 'sprites/player_death.png'
end

def test_player_uses_all_eight_idle_and_walk_frames_with_either_lamp_state(_args, assert)
  [false, true].each do |lamp_on|
    [0, 1].each do |dx|
      player = Descent::Player.spawn(x: 180, y: 180)
      player.lamp_on = lamp_on
      input = { dx: dx, dy: 0, sneak: false, toggle_lamp: false }
      frames = []
      65.times do
        step_player(player, input)
        sprite = player.sprite
        frames << sprite[:source_x]
        state = dx.zero? ? 'idle' : 'walk'
        lamp = lamp_on ? 'on' : 'off'
        assert.equal! sprite[:path], "sprites/player_#{state}_lamp_#{lamp}.png"
        assert.true! sprite[:source_x] + sprite[:source_w] <= 256
        assert.true! sprite[:source_y] + sprite[:source_h] <= 128
      end
      assert.equal! frames.uniq.sort, [0, 32, 64, 96, 128, 160, 192, 224]
      assert.equal! frames.first, frames.last
    end
  end
end
