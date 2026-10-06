# frozen_string_literal: true

require 'app/collision_playground'
require 'tests/support/player_helpers'

def test_playground_advances_death_once_per_tick_and_respawns_with_idle(args, assert)
  player = Descent::Player.new(x: 60, y: 60) # Standing on the red tile.
  args.state.player = player
  args.state.playground = { walls: [], show_bounds: false }

  (0..240).each do |tick|
    Descent::CollisionPlayground.tick(args, tick_count: tick)
    sprite = player.sprite_to_primitive
    if tick < 120
      assert.equal! player.sanity, 100
      assert.equal! sprite[:source_x], (tick.div(8) % 8) * 64
    elsif tick < 240
      assert.equal! player.sanity, 0
      assert.equal! sprite[:path], 'sprites/player_death.png'
      assert.equal! sprite[:source_x], [(tick - 120).div(8), 7].min * 64
    else
      assert.equal! player.sanity, 100
      assert.equal! [player.x, player.y], [133, 60]
      assert.equal! sprite[:path], 'sprites/player_idle_lamp_on.png'
      assert.equal! sprite[:source_x], 0
    end
    args.outputs.primitives.clear
    args.outputs.borders.clear
    args.outputs[Descent::Camera::TARGET].primitives.clear
    args.outputs[Descent::Camera::TARGET].borders.clear
  end
end

def test_red_tile_death_renders_its_first_frame_immediately(args, assert)
  player = Descent::Player.new(x: 60, y: 60) # Standing on the red tile.
  input = { dx: 0, dy: 0, sneak: false, toggle_lamp: false }
  17.times { step_player(player, input) }
  assert.true! player.sprite_to_primitive[:source_x].positive?
  args.state.player = player
  args.state.playground = { walls: [], danger_death_at: Kernel.tick_count }

  Descent::CollisionPlayground.tick(args)

  assert.equal! player.sanity, 0
  sprite = player.sprite_to_primitive
  assert.equal! sprite[:path], 'sprites/player_death.png'
  assert.equal! sprite[:source_x], 0
  10.times { assert.equal! player.sprite_to_primitive, sprite }
end

def test_red_tile_delays_death_then_resets_without_extending_either_countdown(args, assert)
  player = Descent::Player.new(x: 60, y: 60) # Standing on the red tile.
  player.lamp_on = false
  args.state.player = player
  args.state.playground = { walls: Descent::CollisionPlayground::WALLS.map(&:dup) }

  Descent::CollisionPlayground.check_danger_zones(args, tick_count: 10)
  assert.equal! player.sanity, 100
  assert.equal! args.state.playground[:danger_death_at], 130
  assert.equal! args.state.playground[:respawn_at], nil
  (11...130).each do |tick|
    Descent::CollisionPlayground.check_danger_zones(args, tick_count: tick)
    assert.equal! player.sanity, 100
    assert.equal! args.state.playground[:danger_death_at], 130
  end
  Descent::CollisionPlayground.check_danger_zones(args, tick_count: 130)
  assert.equal! player.sanity, 0
  assert.equal! args.state.playground[:danger_death_at], nil
  (131...250).each do |tick|
    Descent::CollisionPlayground.check_danger_zones(args, tick_count: tick)
    assert.equal! player.sanity, 0
    assert.equal! args.state.playground[:respawn_at], 250
  end

  Descent::CollisionPlayground.check_danger_zones(args, tick_count: 250)
  assert.true! args.state.player.equal?(player)
  assert.equal! [player.x, player.y], [133, 60]
  assert.equal! player.sanity, 100
  assert.true! player.lamp_on
  assert.equal! args.state.playground[:respawn_at], nil
  Descent::CollisionPlayground.check_danger_zones(args, tick_count: 251)
  assert.equal! args.state.playground[:respawn_at], nil

  player.x = 60
  Descent::CollisionPlayground.check_danger_zones(args, tick_count: 300)
  assert.equal! args.state.playground[:danger_death_at], 420
  assert.equal! player.sanity, 100
end

def test_leaving_red_tile_cancels_danger_and_reentry_starts_fresh(args, assert)
  player = Descent::Player.new(x: 60, y: 60) # Standing on the red tile.
  args.state.player = player
  args.state.playground = {}
  Descent::CollisionPlayground.check_danger_zones(args, tick_count: 0)
  player.x = 133
  Descent::CollisionPlayground.check_danger_zones(args, tick_count: 119)
  assert.equal! args.state.playground[:danger_death_at], nil
  assert.equal! player.sanity, 100
  player.x = 60
  Descent::CollisionPlayground.check_danger_zones(args, tick_count: 120)
  assert.equal! args.state.playground[:danger_death_at], 240
  Descent::CollisionPlayground.check_danger_zones(args, tick_count: 239)
  assert.equal! player.sanity, 100
  # Stepping off exactly at the deadline still avoids death.
  player.x = 133
  Descent::CollisionPlayground.check_danger_zones(args, tick_count: 240)
  assert.equal! player.sanity, 100
  assert.equal! args.state.playground[:respawn_at], nil
end

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
    assert.true!(frames.last(100).all? { |frame| frame == 448 })
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
