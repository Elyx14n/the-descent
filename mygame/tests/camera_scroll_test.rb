# frozen_string_literal: true

require 'app/camera_scroll'

class CameraScrollTests
  def test_diagonal_pixels_advance_together_across_directions_speeds_and_fractional_phases(_args, assert)
    directions = [-1, 1].product([-1, 1])
    phases = [[0.125, 0.5], [-0.75, -0.125], [0.5, 0.5]]
    speeds = [0.5, 1]
    directions.each do |dx, dy|
      speeds.each do |speed|
        phases.each do |x, y|
          scroll = Descent::CameraScroll.new
          previous = nil
          80.times do |step|
            position = { x: x + (dx * step * speed * Math.sqrt(0.5)),
                         y: y + (dy * step * speed * Math.sqrt(0.5)) }
            raster = scroll.position(**position, scale: 1)
            # The first moving sample establishes direction after initialization.
            if previous && step > 1
              sx = (raster[:x] - previous[:x]) * dx
              sy = (raster[:y] - previous[:y]) * dy
              assert.equal! sx, sy
              assert.true! sx.between?(0, 1)
            end
            assert.true! (raster[:x] - position[:x]).abs <= 1
            assert.true! (raster[:y] - position[:y]).abs <= 1
            previous = raster
          end
        end
      end
    end
  end

  def test_stopping_returns_to_nearest_placement_as_in_the_published_renderer(_args, assert)
    scroll = Descent::CameraScroll.new
    scroll.position(x: 0.125, y: 0.5, scale: 1)
    scroll.position(x: 1.539, y: 1.914, scale: 1)
    point = { x: 2.246, y: 2.621, scale: 1 }
    assert.equal! scroll.position(**point), { x: 3, y: 3 }
    assert.equal! scroll.position(**point), { x: 2, y: 3 }
    assert.equal! scroll.position(**point), { x: 2, y: 3 }
  end

  def test_supplied_velocity_controls_alignment_without_render_frame_history(_args, assert)
    scroll = Descent::CameraScroll.new
    point = { x: 2.246, y: 2.621, scale: 1 }
    velocity = { x: 1, y: 1 }
    assert.equal! scroll.position(**point, velocity: velocity), { x: 3, y: 3 }
    assert.equal! scroll.position(**point, velocity: velocity), { x: 3, y: 3 }
    assert.equal! scroll.position(**point, velocity: { x: 0, y: 0 }), { x: 2, y: 3 }
    assert.equal! velocity, { x: 1, y: 1 }
  end

  def test_direction_aware_rounding_handles_shallow_and_steep_slopes_in_both_directions(_args, assert)
    routes = [
      [[0, 0], [1.4, 0.6], [1, 0]],
      [[0, 0], [0.6, 1.4], [0, 1]],
      [[0, 0], [-1.4, 0.6], [-1, 0]],
      [[0, 0], [0.6, -1.4], [0, -1]],
      [[0, 0], [-1.4, -0.6], [-1, 0]],
      [[0, 0], [-0.6, -1.4], [0, -1]],
      [[0, 0], [1.4, -0.6], [1, 0]],
      [[0, 0], [-0.6, 1.4], [0, 1]]
    ]
    routes.each do |start, finish, expected|
      scroll = Descent::CameraScroll.new
      scroll.position(x: start[0], y: start[1], scale: 1)
      assert.equal! scroll.position(x: finish[0], y: finish[1], scale: 1).values_at(:x, :y), expected
    end
  end

  def test_repeated_turns_and_wall_sliding_do_not_accumulate_camera_error(_args, assert)
    scroll = Descent::CameraScroll.new
    directions = [[1, 1], [1, 0], [1, -1], [0, -1], [-1, -1], [-1, 0], [-1, 1], [0, 1]]
    point = { x: 0.125, y: 0.5 }
    20.times do
      directions.each do |dx, dy|
        5.times do
          point[:x] += dx * Math.sqrt(0.5)
          point[:y] += dy * Math.sqrt(0.5)
          raster = scroll.position(**point, scale: 1)
          assert.true! (raster[:x] - point[:x]).abs <= 1
          assert.true! (raster[:y] - point[:y]).abs <= 1
        end
      end
    end
  end

  def test_resets_discard_direction_and_scale_changes_use_the_current_grid(_args, assert)
    scroll = Descent::CameraScroll.new
    scroll.position(x: 1.539, y: 1.914, scale: 1)
    assert.equal! scroll.position(x: 2.246, y: 2.621, scale: 1), { x: 3, y: 3 }
    scroll.reset
    assert.equal! scroll.position(x: 2.246, y: 2.621, scale: 1), { x: 2, y: 3 }
    scroll.reset
    assert.equal! scroll.position(x: -100.125, y: 200.5, scale: 1), { x: -100, y: 201 }
    assert.equal! scroll.position(x: -100.125, y: 200.5, scale: 2), { x: -100, y: 200.5 }
  end
end
