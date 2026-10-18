# frozen_string_literal: true

module Descent
  module Raycasting
    ANGLE_BUCKET_COUNT = 64
    ANGLE_BUCKET_SCALE = ANGLE_BUCKET_COUNT.fdiv(Math::PI * 2)

    class << self
      def get_intersection(ray:, segment:)
        r_px = ray[:a][:x]
        r_py = ray[:a][:y]
        r_dx = ray[:b][:x] - ray[:a][:x]
        r_dy = ray[:b][:y] - ray[:a][:y]

        s_px = segment[:a][:x]
        s_py = segment[:a][:y]
        s_dx = segment[:b][:x] - segment[:a][:x]
        s_dy = segment[:b][:y] - segment[:a][:y]

        # Return if both the ray and segment's unit vectors are parallel, opposite, or zero length
        determinant = (r_dx * s_dy) - (r_dy * s_dx)
        return nil if determinant.abs < 0.00001

        # Any line can be written in parametric form as: Point + Direction * T
        # Ray X = r_px + r_dx * T1
        # Ray Y = r_py + r_dy * T1
        # Segment X = s_px + s_dx * T2
        # Segment Y = s_py + s_dy * T2
        t2 = ((r_dx * (s_py - r_py)) + (r_dy * (r_px - s_px))) / ((s_dx * r_dy) - (s_dy * r_dx)).to_f
        # Mostly horizontal ray → use X.
        # Mostly vertical ray → use Y
        t1 = if r_dx.abs >= r_dy.abs
               (s_px + (s_dx * t2) - r_px) / r_dx.to_f
             else
               (s_py + (s_dy * t2) - r_py) / r_dy.to_f
             end

        return nil unless t1 >= 0 && t2.between?(0, 1)

        { x: r_px + (r_dx * t1), y: r_py + (r_dy * t1), t: t1 }
      end

      def get_sight_polygon(sight_from_x, sight_from_y, segments:)
        points = segments.flat_map { |segment| [segment[:a], segment[:b]] }
        unique_points = points.uniq { |point| [point[:x], point[:y]] }

        # Generate all unique angles with tiny offsets for edge cases
        unique_angles = unique_points.flat_map do |point|
          angle = Math.atan2(point[:y] - sight_from_y, point[:x] - sight_from_x)
          [angle - 0.00001, angle, angle + 0.00001]
        end
        buckets = segment_angle_buckets(sight_from_x, sight_from_y, segments)

        intersects = unique_angles.filter_map do |angle|
          r_dx = Math.cos(angle)
          r_dy = Math.sin(angle)
          closest_t = nil
          buckets[angle_bucket(angle)].each do |s_dx, s_dy, offset_x, offset_y, t1_numerator|
            determinant = (r_dx * s_dy) - (r_dy * s_dx)
            next if determinant.abs < 0.00001

            t2_numerator = (offset_x * r_dy) - (offset_y * r_dx)
            # Equivalent to t1 >= 0 and 0 <= t2 <= 1, before division.
            if determinant.positive?
              next if t1_numerator.negative? || t2_numerator.negative? || t2_numerator > determinant
            elsif t1_numerator.positive? || t2_numerator.positive? || t2_numerator < determinant
              next
            end

            t1 = t1_numerator.fdiv(determinant)
            closest_t = t1 if closest_t.nil? || t1 < closest_t
          end
          next unless closest_t

          # Allocate just the final hit; the hot loop uses prepared numbers.
          { x: sight_from_x + (r_dx * closest_t), y: sight_from_y + (r_dy * closest_t), t: closest_t, angle: angle }
        end

        intersects.sort_by { |intersect| intersect[:angle] }
      end

      private

      # Index segment directions once per calculation. Each private numeric
      # record is [s_dx, s_dy, offset_x, offset_y, t1_numerator]. Nothing persists
      # between frames, so active door/light geometry stays live.
      def segment_angle_buckets(sight_from_x, sight_from_y, segments)
        buckets = Array.new(ANGLE_BUCKET_COUNT) { [] }
        segments.each do |segment|
          ax = segment[:a][:x] - sight_from_x
          ay = segment[:a][:y] - sight_from_y
          bx = segment[:b][:x] - sight_from_x
          by = segment[:b][:y] - sight_from_y
          next if ax == bx && ay == by

          s_dx = segment[:b][:x] - segment[:a][:x]
          s_dy = segment[:b][:y] - segment[:a][:y]
          t1_numerator = (ax * s_dy) - (ay * s_dx)
          prepared_segment = [s_dx, s_dy, ax, ay, t1_numerator]
          contains_source = t1_numerator.zero? && (ax * bx) + (ay * by) <= 0
          first_angle, last_angle = [Math.atan2(ay, ax), Math.atan2(by, bx)].minmax
          if contains_source
            buckets.each { |bucket| bucket << prepared_segment }
          elsif last_angle - first_angle > Math::PI
            (0..angle_bucket(first_angle)).each { |index| buckets[index] << prepared_segment }
            (angle_bucket(last_angle)...ANGLE_BUCKET_COUNT).each { |index| buckets[index] << prepared_segment }
          else
            (angle_bucket(first_angle)..angle_bucket(last_angle)).each { |index| buckets[index] << prepared_segment }
          end
        end
        buckets
      end

      def angle_bucket(angle)
        angle -= Math::PI * 2 if angle > Math::PI
        angle += Math::PI * 2 if angle < -Math::PI
        ((angle + Math::PI) * ANGLE_BUCKET_SCALE).to_i.clamp(0, ANGLE_BUCKET_COUNT - 1)
      end
    end
  end
end
