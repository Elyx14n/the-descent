# frozen_string_literal: true

require 'app/simulation_clock'
require 'app/player'

class SimulationClockTests
  def test_whole_steps_track_elapsed_time_at_varied_callback_rates(_args, assert)
    [60, 59.94, 55, 50, 30].each do |rate|
      clock = Descent::SimulationClock.new(now_us: 0)
      (1..(rate * 10).floor).each do |frame|
        now = (frame * 1_000_000 / rate).round
        clock.advance(now_us: now).times { clock.step }
        lag = now.fdiv(1_000_000) - clock.tick.fdiv(60)
        assert.true! lag >= -0.000001 && lag < 1.fdiv(60)
        assert.true! clock.alpha >= 0 && clock.alpha < 1
      end
      clock.advance(now_us: 10_000_000).times { clock.step }
      assert.equal! clock.tick, 600
      assert.equal! clock.discarded_us, 0
    end
  end

  def test_overload_retains_fraction_but_discards_excess_whole_steps(_args, assert)
    clock = Descent::SimulationClock.new(now_us: 0)
    assert.equal! clock.advance(now_us: 210_000), 8
    8.times { clock.step }
    assert.true! (clock.alpha - 0.6).abs < 0.000001
    assert.true! (clock.discarded_us - (4 * 1_000_000.fdiv(60))).abs < 0.000001
    assert.equal! clock.advance(now_us: 220_000), 1
    clock.step
    assert.equal! clock.tick, 9
  end

  def test_irregular_callback_spacing_preserves_elapsed_time(_args, assert)
    clock = Descent::SimulationClock.new(now_us: 0)
    now = 0
    intervals = [500, 16_000, 35_000, 8_000, 75_000, 2_000, 20_000]
    500.times do |index|
      now += intervals[index % intervals.length]
      clock.advance(now_us: now).times { clock.step }
      assert.equal! clock.tick, (now * 60).div(1_000_000)
      assert.equal! clock.discarded_us, 0
    end
  end

  def test_initialization_reset_and_clock_discontinuities_do_not_catch_up(_args, assert)
    clock = Descent::SimulationClock.new(now_us: 100)
    assert.equal! clock.advance(now_us: 100), 0
    clock.advance(now_us: 20_100).times { clock.step }
    assert.equal! clock.tick, 1
    assert.equal! clock.advance(now_us: 270_100), 0
    assert.true! clock.discontinuity
    assert.equal! clock.alpha, 0
    assert.equal! clock.advance(now_us: 200_000), 0
    assert.true! clock.discontinuity
    clock.reset(now_us: 1_000_000)
    assert.equal! clock.tick, 1
    assert.equal! clock.advance(now_us: 1_000_000), 0
    assert.equal! clock.advance(now_us: 1_016_667), 1
  end

  def test_gameplay_and_animation_match_for_identical_simulation_action_traces(_args, assert)
    reference = nil
    [16_667, 20_000, 33_333, 7_000].each do |interval|
      clock = Descent::SimulationClock.new(now_us: 0)
      player = Descent::Player.new(x: 0, y: 0)
      now = 0
      while now < 10_000_000
        now = [now + interval, 10_000_000].min
        clock.advance(now_us: now).times do
          tick = clock.tick
          player.update_controls({ dx: tick < 300 ? 1 : -1, dy: 1, sneak: tick >= 450,
                                   toggle_lamp: tick == 100 })
          player.update_animation
          clock.step
        end
      end
      result = [player.x, player.y, player.lamp_on, player.sprite.animation_tick]
      reference ||= result
      assert.equal! result, reference
    end
  end
end
