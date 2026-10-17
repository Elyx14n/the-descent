# frozen_string_literal: true

require 'app/raycasting'

class RaycastingTests
  def test_short_axis_aligned_rays_still_hit_crossing_segments(_args, assert)
    origin = { x: 0, y: 0 }
    cases = [
      [{ x: 0.000001, y: 0 }, { a: { x: 1, y: -10 }, b: { x: 1, y: 10 } }, [1, 0]],
      [{ x: 0, y: 0.000001 }, { a: { x: -10, y: 1 }, b: { x: 10, y: 1 } }, [0, 1]]
    ]
    cases.each do |direction_point, segment, expected|
      intersection = Descent::Raycasting.get_intersection(ray: { a: origin, b: direction_point }, segment: segment)
      assert.true! intersection
      assert.equal! intersection.values_at(:x, :y), expected
      assert.equal! intersection[:t], 1_000_000
    end
  end

  def test_sight_polygon_agrees_with_reference_intersections_for_fractional_origins(_args, assert)
    segments = polygon_segments([[-10, -10], [10, -10], [10, 10], [-10, 10]]) +
               polygon_segments([[2, -3], [4, -3], [4, 3], [2, 3]]) +
               polygon_segments([[-4, -1], [-2, -1], [-2, 1], [-4, 1]]) +
               polygon_segments([[-7, 2], [-3, 3], [-5, 6]]) +
               polygon_segments([[-7, -7], [-2, -7], [-2, -5], [-5, -5], [-5, -2], [-7, -2]])
    before = segments.to_s
    [[0, 0], [0.375, -0.625]].each do |x, y|
      polygon = Descent::Raycasting.get_sight_polygon(x, y, segments: segments)
      assert.equal! polygon.map { |point| point[:angle] }, polygon.map { |point| point[:angle] }.sort
      outline = polygon_segments(polygon.map { |point| point.values_at(:x, :y) })
      48.times do |index|
        angle = (index + 0.37) * Math::PI / 24
        ray = { a: { x: x, y: y }, b: { x: x + Math.cos(angle), y: y + Math.sin(angle) } }
        expected = closest_reference_intersection(ray, segments)
        actual = closest_reference_intersection(ray, outline)
        assert.true! expected && actual
        assert.true! (actual[:t] - expected[:t]).abs < 0.001
      end
    end
    assert.equal! segments.to_s, before
    assert.equal! Descent::Raycasting.get_sight_polygon(0, 0, segments: []), []
  end

  def test_segment_containing_source_intersects_all_nonparallel_directions(_args, assert)
    segments = polygon_segments([[-5, -5], [5, -5], [5, 5], [-5, 5]])
    segments << { a: { x: 0, y: -2 }, b: { x: 0, y: 2 } }
    polygon = Descent::Raycasting.get_sight_polygon(0, 0, segments: segments)
    nonparallel = polygon.reject { |point| Math.cos(point[:angle]).abs < 0.00001 }
    assert.true! nonparallel.any?
    assert.true!(nonparallel.all? { |point| point[:t].zero? && point[:x].zero? && point[:y].zero? })
  end

  def test_sight_polygon_is_stable_for_reordered_crossing_and_degenerate_edges(_args, assert)
    border = polygon_segments([[-10, -10], [10, -10], [10, 10], [-10, 10]])
    groups = [
      polygon_segments([[2, -3], [4, -3], [4, 3], [2, 3]]),
      polygon_segments([[-7, 2], [-3, 3], [-5, 6]]),
      polygon_segments([[-7, -7], [-2, -7], [-2, -5], [-5, -5], [-5, -2], [-7, -2]]),
      [{ a: { x: -20, y: 7 }, b: { x: 20, y: 7 } }], # crosses border; endpoints outside
      [{ a: { x: 0, y: -2 }, b: { x: 0, y: 2 } }], # vertical segment containing source
      [{ a: { x: 1, y: 1 }, b: { x: 1, y: 1 } }],
      []
    ]
    before = groups.to_s
    [[0, 0], [0.375, -0.625], [2, -3], [4, 3], [-8, 7]].each do |x, y|
      expected = Descent::Raycasting.get_sight_polygon(x, y, segments: border + groups.flatten(1))
      actual = Descent::Raycasting.get_sight_polygon(x, y, segments: border + groups.reverse.flatten(1))
      assert.equal! actual.length, expected.length
      actual.zip(expected).each do |hit, reference|
        assert.equal! hit[:angle], reference[:angle]
        assert.true! (hit[:t] - reference[:t]).abs < 0.000001
      end
    end
    assert.equal! groups.to_s, before
  end

  def test_bucket_candidates_match_reference_hits_across_wraparound_and_source_contacts(_args, assert)
    border = polygon_segments([[-10, -10], [10, -10], [10, 10], [-10, 10]])
    groups = [
      polygon_segments([[-6, -1], [-4, -1], [-4, 1], [-6, 1]]), # spans -PI/PI
      polygon_segments([[2, -0.000001], [4, 0], [2, 0.000001]]),
      [{ a: { x: -2, y: 0 }, b: { x: 2, y: 0 } }], # crosses source
      [{ a: { x: 0, y: 0 }, b: { x: -3, y: 2 } }], # source at endpoint
      [{ a: { x: -2, y: 1 }, b: { x: -2, y: 1 } }]
    ]
    origins = [[0, 0], [0.375, -0.625], [-2, 1], [-10, 0]]
    reversed = groups.map { |group| group.map { |segment| { a: segment[:b], b: segment[:a] } } }
    [groups.first(2), groups, reversed].each do |ordered_groups|
      segments = border + ordered_groups.flatten(1)
      origins.each do |x, y|
        polygon = Descent::Raycasting.get_sight_polygon(x, y, segments: segments)
        # Compare the same source-relative unit rays as the optimized loop;
        # adding/subtracting the world origin can move a tangent by one ULP.
        relative_segments = segments.map do |segment|
          { a: { x: segment[:a][:x] - x, y: segment[:a][:y] - y },
            b: { x: segment[:b][:x] - x, y: segment[:b][:y] - y } }
        end
        expected_angles = segments.flat_map { |segment| [segment[:a], segment[:b]] }.uniq.flat_map do |point|
          angle = Math.atan2(point[:y] - y, point[:x] - x)
          [angle - 0.00001, angle, angle + 0.00001]
        end.sort
        assert.equal! polygon.map { |hit| hit[:angle] }, expected_angles
        polygon.each do |hit|
          ray = { a: { x: 0, y: 0 }, b: { x: Math.cos(hit[:angle]), y: Math.sin(hit[:angle]) } }
          expected = closest_reference_intersection(ray, relative_segments)
          assert.true! expected
          assert.true! (hit[:t] - expected[:t]).abs < 0.000001
        end
      end
    end
  end

  def polygon_segments(points)
    points.each_with_index.map do |point, index|
      following = points[(index + 1) % points.length]
      { a: { x: point[0], y: point[1] }, b: { x: following[0], y: following[1] } }
    end
  end

  def closest_reference_intersection(ray, segments)
    intersections = segments.filter_map do |segment|
      Descent::Raycasting.get_intersection(ray: ray, segment: segment)
    end
    intersections.min_by { |intersection| intersection[:t] }
  end
end
