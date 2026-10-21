# frozen_string_literal: true

module Descent
  # Direction-aware drawing alignment from Ilmari Karonen's published algorithm:
  # https://gamedev.stackexchange.com/a/18801
  # Like fnnbrr's Unity adaptation, use supplied simulation velocity or infer
  # direction from precise positions, leaving gameplay coordinates unchanged:
  # https://gist.github.com/fnnbrr/4938adc5439ab70c55430b020790b531
  class CameraScroll
    def reset
      @previous = nil
    end

    def position(x:, y:, scale:, velocity: nil)
      previous_x, previous_y = @previous || [x, y]
      @previous = [x, y]
      dx = velocity ? velocity[:x] : x - previous_x
      dy = velocity ? velocity[:y] : y - previous_y
      draw_x = round_to_pixel(x, scale)
      draw_y = round_to_pixel(y, scale)

      # Snap the main movement axis, then follow the movement direction to find
      # the other coordinate. At rest, keep ordinary nearest-pixel placement.
      if dx.abs > dy.abs
        draw_y = round_to_pixel(y + ((draw_x - x) * dy / dx), scale)
      elsif !dy.zero?
        draw_x = round_to_pixel(x + ((draw_y - y) * dx / dy), scale)
      end
      { x: draw_x, y: draw_y }
    end

    private

    def round_to_pixel(value, scale)
      ((value * scale) + 0.5).floor.fdiv(scale)
    end
  end
end
