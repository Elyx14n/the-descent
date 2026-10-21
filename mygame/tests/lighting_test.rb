# frozen_string_literal: true

require 'app/lighting'
require 'app/camera'

class LightingTests
  def test_visible_base_corners_do_not_flicker_during_fractional_movement(_args, assert)
    bases = [[192.125, 189.59375], [192.125, 141.59375],
             [144.875, 141.59375], [144.875, 189.59375]].map do |x, y|
      { x: x, y: y, w: 15, h: 3 }
    end
    blockers = bases.map.with_index { |base, index| lighting_test_rect_blocker(base, owner: index) }
    receivers = bases.map { |base| { sprite: {}, bases: [base] } }
    20.times do |index|
      source = { x: 170 + (index * 0.25), y: 176, radius: 64 }
      lights = Descent::Lighting.prepare(light_sources: [source], light_blockers: blockers)
      colors = Descent::Lighting.receiver_colors(light_receivers: receivers, light_polygons: lights)
      receivers.each do |receiver|
        base = receiver[:bases].first
        dx = source[:x].clamp(base[:x], base[:x] + base[:w]) - source[:x]
        dy = source[:y].clamp(base[:y], base[:y] + base[:h]) - source[:y]
        expected = Descent::Lighting::AMBIENT + (255 * (1 - Math.hypot(dx, dy).fdiv(source[:radius])))
        assert.true! (colors[receiver[:sprite].object_id][0] - expected).abs < 0.000001
      end
    end
  end

  def test_room_light_radius_defaults_to_48_and_positive_source_radius_is_preserved(_args, assert)
    sources = [{ x: 0, y: 0, radius: 0 }, { x: 0, y: 0, radius: 64 }, { x: 0, y: 0, radius: 30 }]
    lights = Descent::Lighting.prepare(light_sources: sources, light_blockers: [])
    assert.equal! lights.map { |light| light[:source][:radius] }, [48, 64, 30]
    assert.equal! sources.first[:radius], 0
  end

  def test_near_wall_face_receives_light_while_a_receiver_behind_it_stays_ambient(_args, assert)
    source = { x: 0, y: 0, radius: 64, intensity: 1 }
    blocker = lighting_test_blocker(10, owner: :wall)
    lights = Descent::Lighting.prepare(light_sources: [source], light_blockers: [blocker])
    face = { x: 10, y: -20, w: 1, h: 70, a: 64 }
    behind = { x: 20, y: 0, w: 1, h: 30 }
    receivers = [{ sprite: face, bases: [blocker[:sprite]] },
                 { sprite: behind, bases: [{ x: 20, y: 0, w: 1, h: 1 }] }]
    colors = Descent::Lighting.receiver_colors(light_receivers: receivers, light_polygons: lights)
    assert.true! colors[face.object_id][0] > Descent::Lighting::AMBIENT
    assert.equal! colors[behind.object_id], [31, 31, 31]
    tinted = Descent::Lighting.tint(face, color: colors[face.object_id])
    assert.equal! tinted[:a], 64
    assert.false! face.key?(:r)
  end

  def test_colored_light_and_empty_light_set_keep_authored_tints_and_alpha(_args, assert)
    source = { x: 0, y: 0, radius: 48, color: '#ffff0000', intensity: 0.5 }
    sprite = { r: 128, g: 64, b: 32, a: 90 }
    receivers = [{ sprite: sprite, bases: [{ x: 0, y: 0, w: 1, h: 1 }] }]
    lights = Descent::Lighting.prepare(light_sources: [source], light_blockers: [])
    colors = Descent::Lighting.receiver_colors(light_receivers: receivers, light_polygons: lights)
    assert.true! colors[sprite.object_id][0] > 31
    assert.equal! colors[sprite.object_id].last(2), [31, 31]
    dark = Descent::Lighting.receiver_colors(light_receivers: receivers, light_polygons: [])
    assert.equal! dark[sprite.object_id], [31, 31, 31]
    tinted = Descent::Lighting.tint(sprite, color: [255, 255, 255])
    assert.equal! tinted, sprite
  end

  def test_unblocked_radius_is_circular_and_ignores_geometry_in_square_corners(_args, assert)
    [-23.375, 40.125].each do |x|
      source = { x: x, y: 17.625, radius: 96, ignore_owner_ids: [] }
      corner_blocker = {
        owner_ids: [:corner], sprite: { x: x + 80, y: source[:y] + 80, w: 8, h: 40 },
        edges: [{ x: x + 80, y: source[:y] + 80, x2: x + 80, y2: source[:y] + 120 }]
      }
      [[], [corner_blocker]].each do |blockers|
        polygon = Descent::Lighting.prepare(light_sources: [source], light_blockers: blockers).first[:sight_polygon]
        assert.true! polygon.length >= 3
        polygon.each_with_index do |point, index|
          following = polygon[(index + 1) % polygon.length]
          distance = Math.hypot(point[:x] - source[:x], point[:y] - source[:y])
          middle_x = (point[:x] + following[:x]) / 2.0
          middle_y = (point[:y] + following[:y]) / 2.0
          middle_distance = Math.hypot(middle_x - source[:x], middle_y - source[:y])
          assert.true! distance <= source[:radius] + 0.000001
          # Even halfway along a chord, the boundary is within half a native pixel.
          assert.true! middle_distance >= source[:radius] - 0.5
        end
      end
    end
  end

  def test_preparation_keeps_crossing_edges_and_applies_per_source_exclusions(_args, assert)
    source = { id: :player, x: 0, y: 0, radius: 10, ignore_owner_ids: [:own] }
    blockers = [lighting_test_blocker(2, owner: :own), lighting_test_blocker(5, owner: :other)]
    before = [source, blockers].to_s
    light = Descent::Lighting.prepare(light_sources: [source], light_blockers: blockers).first
    polygon = light[:sight_polygon]
    segments = polygon.each_with_index.map do |point, index|
      { a: point, b: polygon[(index + 1) % polygon.length] }
    end
    ray = { a: { x: 0, y: 0 }, b: { x: 1, y: 0 } }
    hit = segments.filter_map { |segment| Descent::Raycasting.get_intersection(ray: ray, segment: segment) }
                  .min_by { |point| point[:t] }
    # Both endpoints lie beyond the radius; the edge still crosses the light.
    assert.true! (hit[:x] - 5).abs < 0.000001
    assert.equal! light[:source], source
    assert.equal! [source, blockers].to_s, before
    assert.equal! Descent::Lighting.prepare(light_sources: [], light_blockers: blockers), []
  end

  def test_triangle_fan_converts_all_vertices_closes_and_ignores_degenerate_polygons(_args, assert)
    camera = Descent::Camera.new(x: 400, y: 400)
    camera.follow(x: 210, y: 140)
    camera = camera.for_drawing
    source = { x: 190.25, y: 120.5 }
    points = [{ x: 180.25, y: 110.5 }, { x: 200.25, y: 110.5 }, { x: 190.25, y: 130.5 }]
    lights = [{ source: source, sight_polygon: points }, { source: source, sight_polygon: [] }]
    before = lights.to_s
    triangles = Descent::Lighting.triangles(light_polygons: lights, camera: camera)
    assert.equal! triangles.length, 3
    first = triangles.first
    assert.equal! first.values_at(:x, :y), camera.to_screen(**source).values_at(:x, :y)
    assert.equal! first.values_at(:x2, :y2), camera.to_screen(**points[0]).values_at(:x, :y)
    assert.equal! first.values_at(:x3, :y3), camera.to_screen(**points[1]).values_at(:x, :y)
    assert.equal! first[:path], Descent::Lighting::LIGHT_MASK_TARGET
    assert.equal! first.values_at(:source_x, :source_y), [64, 64]
    assert.equal! first[:source_x2], 64 + ((first[:x2] - first[:x]) * 128.fdiv(96))
    assert.equal! first[:source_y2], 64 + ((first[:y2] - first[:y]) * 128.fdiv(96))
    assert.equal! triangles.last.values_at(:x3, :y3), first.values_at(:x2, :y2)
    assert.equal! lights.to_s, before
  end

  def lighting_test_blocker(x, owner:)
    { owner_ids: [owner], sprite: { x: x, y: -20, w: 1, h: 40 },
      edges: [{ x: x, y: -20, x2: x, y2: 20 }] }
  end

  def lighting_test_rect_blocker(rect, owner:)
    x, y, w, h = rect.values_at(:x, :y, :w, :h)
    corners = [[x, y], [x + w, y], [x + w, y + h], [x, y + h]]
    edges = corners.each_with_index.map do |point, index|
      following = corners[(index + 1) % corners.length]
      { x: point[0], y: point[1], x2: following[0], y2: following[1] }
    end
    { owner_ids: [owner], sprite: rect, bounds: rect, edges: edges }
  end
end
