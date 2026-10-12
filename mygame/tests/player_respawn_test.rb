# frozen_string_literal: true

require 'app/player'
require 'tests/support/player_helpers'

class PlayerRespawnTests
  include PlayerTestHelpers

  def test_death_animation_plays_once_and_can_play_again_after_reset(_args, assert)
    player = Descent::Player.new(x: 180, y: 180)
    input = { dx: 0, dy: 0, sneak: false, toggle_lamp: false }
    2.times do
      player.sanity = 0
      frames = []
      200.times do
        step_player(player, input)
        frames << player.sprite_to_primitive[:source_x]
      end
      assert.equal! frames.uniq, [0, 64, 128, 192, 256, 320, 384, 448]
      assert.true!(frames.each_cons(2).all? { |before, after| after >= before })
      assert.true!(frames.last(100).all?(448))
      player.reset(x: 400, y: 180)
    end
  end

  def test_dead_player_animates_without_moving_or_toggling_lamp(_args, assert)
    player = Descent::Player.new(x: 180, y: 180)
    input = { dx: 1, dy: 1, sneak: false, toggle_lamp: true }
    player.sanity = 0
    17.times { step_player(player, input) }
    assert.equal! [player.x, player.y], [180, 180]
    assert.true! player.lamp_on
    assert.false! player.moving?
    assert.equal! player.sprite_to_primitive[:path], 'sprites/player_death.png'
    assert.true! player.sprite_to_primitive[:source_x].positive?

    player.reset(x: 400, y: 180)
    assert.equal! player.facing, :south
    assert.equal! player.sprite_to_primitive[:path], 'sprites/player_idle_lamp_on.png'
    assert.equal! player.sprite_to_primitive[:source_x], 0
    step_player(player, input.merge(dx: 0, dy: 0, toggle_lamp: false))
    assert.equal! player.sprite_to_primitive[:source_x], 0
  end
end
