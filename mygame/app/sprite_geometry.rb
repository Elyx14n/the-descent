# frozen_string_literal: true

module Descent
  # World-space geometry derived from the current sprite and generated crop-local
  # occluders. No camera, cache, fade policy, or lighting policy participates.
  module SpriteGeometry
    class << self
      def bounds(sprite)
        { x: sprite[:x] - (sprite[:w] * sprite.fetch(:anchor_x, 0)),
          y: sprite[:y] - (sprite[:h] * sprite.fetch(:anchor_y, 0)),
          w: sprite[:w], h: sprite[:h] }
      end

      def occupied_bounds(sprite)
        return bounds(sprite) unless sprite.key?(:occlusion_bounds)

        local = sprite[:occlusion_bounds]
        return unless local

        transform_rect(sprite, local)
      end

      # One line per generated edge, including the closing edge of each ring.
      def edges(sprite)
        polygons(sprite).flat_map do |ring|
          ring.each_with_index.map do |point, index|
            following = ring[(index + 1) % ring.length]
            { x: point[0], y: point[1], x2: following[0], y2: following[1] }
          end
        end
      end

      # Does a continuous horizontal span cross x, exceed width, and overlap
      # the vertical body interval with positive height? Bounds are broad phase
      # only; disconnected pieces and concave notches remain independent.
      def crosses_span?(sprite, x:, y:, height:, width:)
        rect = occupied_bounds(sprite)
        return false unless rect && rect[:w] > width && rect[:x] <= x && x < rect[:x] + rect[:w] &&
                            rect[:y] < y + height && rect[:y] + rect[:h] > y
        return true unless sprite.key?(:occlusion_polygons)

        polygons(sprite).any? { |ring| ring_crosses_span?(ring, x, y, y + height, width) }
      end

      def polygons(sprite)
        frame = bounds(sprite)
        sprite.fetch(:occlusion_polygons, []).map do |ring|
          ring.map do |x, y|
            x = sprite[:source_w] - x if sprite[:flip_horizontally]
            y = sprite[:source_h] - y if sprite[:flip_vertically]
            [frame[:x] + (x * sprite[:w].fdiv(sprite[:source_w])),
             frame[:y] + (y * sprite[:h].fdiv(sprite[:source_h]))]
          end
        end
      end

      # Transform the broad-phase bounds without altering polygon vertices.
      def transform_rect(sprite, local)
        frame = bounds(sprite)
        x = sprite[:flip_horizontally] ? sprite[:source_w] - local[:x] - local[:w] : local[:x]
        y = sprite[:flip_vertically] ? sprite[:source_h] - local[:y] - local[:h] : local[:y]
        scale_x = sprite[:w].fdiv(sprite[:source_w])
        scale_y = sprite[:h].fdiv(sprite[:source_h])
        { x: frame[:x] + (x * scale_x), y: frame[:y] + (y * scale_y),
          w: local[:w] * scale_x, h: local[:h] * scale_y }
      end

      private

      def ring_crosses_span?(ring, x, bottom, top, width)
        levels = ([bottom, top] + ring.map(&:last).select { |y| y > bottom && y < top }).uniq.sort
        levels.each_cons(2).any? do |low, high|
          middle = (low + high) / 2.0
          crossings = []
          ring.each_with_index do |point, index|
            following = ring[(index + 1) % ring.length]
            next unless (point[1] <= middle && following[1] > middle) ||
                        (following[1] <= middle && point[1] > middle)

            slope = (following[0] - point[0]).fdiv(following[1] - point[1])
            crossings << [point[0] + ((low - point[1]) * slope), point[0] + ((high - point[1]) * slope)]
          end
          crossings = crossings.sort_by { |a, b| a + b }
          crossings.each_slice(2).any? { |left, right| span_crosses?(left, right, x, width) }
        end
      end

      # Between vertex heights the left/right boundaries are linear. Clip a
      # normalized height interval against all three inequalities together;
      # checking only its endpoints or midpoint would miss narrow valid slices.
      def span_crosses?(left, right, x, width)
        lower = 0.0
        upper = 1.0
        constraints = [[x - left[0], x - left[1], false],
                       [right[0] - x, right[1] - x, true],
                       [right[0] - left[0] - width, right[1] - left[1] - width, true]]
        constraints.each do |start, finish, strict|
          if start == finish
            return false if strict ? start <= 0 : start.negative?

            next
          end
          crossing = -start.fdiv(finish - start)
          if finish > start
            lower = [lower, crossing].max
          else
            upper = [upper, crossing].min
          end
          return false unless lower < upper
        end
        true
      end
    end
  end
end
