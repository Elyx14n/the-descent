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

      def occupied_regions(sprite)
        unless sprite.key?(:occlusion_regions)
          rect = occupied_bounds(sprite)
          return rect ? [rect] : []
        end

        sprite[:occlusion_regions].map { |local| transform_rect(sprite, local) }
      end

      # Exposed boundaries for consumers such as raycasting. Fade-region edges
      # are an overlap shortcut and must not be used as lighting boundaries.
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

      # Public so callers can transform one region at a time and short-circuit
      # without allocating world rectangles for every region in the crop.
      def transform_rect(sprite, local)
        frame = bounds(sprite)
        x = sprite[:flip_horizontally] ? sprite[:source_w] - local[:x] - local[:w] : local[:x]
        y = sprite[:flip_vertically] ? sprite[:source_h] - local[:y] - local[:h] : local[:y]
        scale_x = sprite[:w].fdiv(sprite[:source_w])
        scale_y = sprite[:h].fdiv(sprite[:source_h])
        { x: frame[:x] + (x * scale_x), y: frame[:y] + (y * scale_y),
          w: local[:w] * scale_x, h: local[:h] * scale_y }
      end
    end
  end
end
