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
            if previous
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

  def test_pausing_and_speed_changes_preserve_the_diagonal_phase(_args, assert)
    scroll = Descent::CameraScroll.new
    distances = [0, 0.707, 1.414, 1.414, 1.414, 1.768, 2.122, 2.829]
    positions = distances.map { |distance| scroll.position(x: 0.125 + distance, y: 0.5 + distance, scale: 1) }
    assert.equal! positions.map { |point| point[:x] }, [0, 1, 1, 1, 1, 2, 2, 3]
    assert.equal! positions.map { |point| point[:y] }, [1, 2, 2, 2, 2, 3, 3, 4]
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
          assert.equal! scroll.position(**point, scale: 1), raster
        end
      end
    end
  end

  def test_teleports_resets_and_scale_changes_start_a_fresh_phase(_args, assert)
    scroll = Descent::CameraScroll.new
    scroll.position(x: 0.125, y: 0.5, scale: 1)
    assert.equal! scroll.position(x: 0.832, y: 1.207, scale: 1), { x: 1, y: 2 }
    scroll.reset
    assert.equal! scroll.position(x: 0.832, y: 1.207, scale: 1), { x: 1, y: 1 }
    assert.equal! scroll.position(x: -100.125, y: 200.5, scale: 1), { x: -100, y: 201 }
    assert.equal! scroll.position(x: -100.125, y: 200.5, scale: 2), { x: -100, y: 200.5 }
  end
end
