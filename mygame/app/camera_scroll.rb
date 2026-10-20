# frozen_string_literal: true

module Descent
  # Presentation history only. Pair native-pixel steps during a straight
  # diagonal so differing world-coordinate fractions cannot stagger its axes.
  class CameraScroll
    EPSILON = 0.000001

    def reset
      @previous = @raster = @origin = @direction = nil
    end

    def position(x:, y:, scale:)
      point = [x * scale, y * scale]
      reset if @scale != scale
      @scale = scale
      if !@previous || point.zip(@previous).any? { |a, b| (a - b).abs > 4 * scale }
        @origin = @direction = nil
        @raster = nearest(point)
      else
        advance(point)
      end
      @previous = point
      { x: @raster[0].fdiv(scale), y: @raster[1].fdiv(scale) }
    end

    private

    def advance(point)
      dx = point[0] - @previous[0]
      dy = point[1] - @previous[1]
      return if dx.abs < EPSILON && dy.abs < EPSILON

      if dx.abs > EPSILON && (dx.abs - dy.abs).abs < EPSILON
        direction = [dx <=> 0, dy <=> 0]
        if @direction != direction
          @origin = @previous
          @base = nearest(@previous)
        end
        @direction = direction
        distance = ((point[0] - @origin[0]).abs + 0.5).floor
        @raster = @base.zip(direction).map { |base, sign| base + (sign * distance) }
      else
        @origin = @direction = nil
        @raster = nearest(point)
      end
    end

    def nearest(point)
      point.map { |value| (value + 0.5).floor }
    end
  end
end
