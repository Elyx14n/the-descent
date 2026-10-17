# frozen_string_literal: true

require 'app/sprite_geometry'
require 'app/occluder_data'

class SpriteGeometryTests
  def polygon_sprite(rings)
    { x: 0, y: 0, w: 32, h: 32, source_w: 32, source_h: 32, occlusion_polygons: rings }
  end

  def test_sloped_spans_find_a_valid_slice_between_endpoints_and_midpoint(_args, assert)
    sprite = polygon_sprite([[[10, 0], [20, 0], [4, 8], [2, 8]]])
    # At x=7, center and width>6 coincide only for 3 <= y < 4.
    assert.true! Descent::SpriteGeometry.crosses_span?(sprite, x: 7, y: 0, height: 8, width: 6)
    assert.false! Descent::SpriteGeometry.crosses_span?(sprite, x: 7, y: 0, height: 8, width: 7)
    assert.false! Descent::SpriteGeometry.crosses_span?(sprite, x: 7, y: 4, height: 4, width: 6)
    assert.false! Descent::SpriteGeometry.crosses_span?(sprite, x: 7, y: 0, height: 3, width: 6)
    assert.true! Descent::SpriteGeometry.crosses_span?(sprite, x: 7, y: 0, height: 3.001, width: 6)
  end

  def test_polygon_width_and_half_open_center_boundaries(_args, assert)
    sprite = polygon_sprite([[[2, 2], [10, 2], [10, 6], [2, 6]]])
    assert.true! Descent::SpriteGeometry.crosses_span?(sprite, x: 2, y: 2, height: 4, width: 7.999)
    assert.false! Descent::SpriteGeometry.crosses_span?(sprite, x: 2, y: 2, height: 4, width: 8)
    assert.false! Descent::SpriteGeometry.crosses_span?(sprite, x: 10, y: 2, height: 4, width: 7)
    assert.false! Descent::SpriteGeometry.crosses_span?(sprite, x: 5, y: 6, height: 4, width: 7)
    assert.false! Descent::SpriteGeometry.crosses_span?(sprite, x: 5, y: 0, height: 2, width: 7)
  end

  def test_concave_spans_do_not_join_across_a_notch(_args, assert)
    sprite = polygon_sprite([[[0, 0], [10, 0], [10, 10], [8, 10], [8, 2], [2, 2], [2, 10], [0, 10]]])
    assert.false! Descent::SpriteGeometry.crosses_span?(sprite, x: 5, y: 2, height: 8, width: 1)
    assert.false! Descent::SpriteGeometry.crosses_span?(sprite, x: 1, y: 2, height: 8, width: 3)
    assert.true! Descent::SpriteGeometry.crosses_span?(sprite, x: 1, y: 2, height: 8, width: 1)
    assert.true! Descent::SpriteGeometry.crosses_span?(sprite, x: 5, y: 1.999, height: 8, width: 9)
  end

  def test_generated_edges_keep_exact_parity_for_every_atlas_tile(args, assert)
    data = Descent::OccluderData.load(args.gtk)
    data['tilesets'].each do |tileset|
      tileset['tiles'].each do |tile|
        sprite = { x: 40, y: 60, w: 48, h: 64, anchor_x: 0.5, anchor_y: 1,
                   source_w: tileset['tile_width'], source_h: tileset['tile_height'],
                   flip_horizontally: true, occlusion_polygons: tile['polygons'] }
        edges = Descent::SpriteGeometry.edges(sprite)
        assert.equal! edges.length, tile['polygons'].sum(&:length)
      end
    end
  end

  def test_polygon_boundaries_follow_anchors_unequal_scaling_and_all_flips(_args, assert)
    local = [[[1, 2], [3, 2], [3, 4], [1, 4]], [[7, 6], [9, 6], [9, 8], [7, 8]]]
    sprite = { x: 100, y: 200, w: 20, h: 30, anchor_x: 0.5, anchor_y: 1,
               source_w: 10, source_h: 10, occlusion_polygons: local }
    before = local.to_s
    [[false, false, 92, 176], [true, false, 108, 176],
     [false, true, 92, 194], [true, true, 108, 194]].each do |flip_h, flip_v, x, y|
      sprite[:flip_horizontally] = flip_h
      sprite[:flip_vertically] = flip_v
      polygons = Descent::SpriteGeometry.polygons(sprite)
      assert.equal! polygons.length, 2
      assert.equal! polygons.first.first, [x, y]
      edges = Descent::SpriteGeometry.edges(sprite)
      assert.equal! edges.length, 8
      assert.equal! edges.first.values_at(:x, :y), [x, y]
      assert.equal! edges[3].values_at(:x2, :y2), [x, y]
      assert.equal! edges[4].values_at(:x, :y), polygons.last.first
      assert.equal! edges.last.values_at(:x2, :y2), polygons.last.first
      assert.true! Descent::SpriteGeometry.crosses_span?(sprite, x: flip_h ? 106 : 94,
                                                                 y: flip_v ? 190 : 178, height: 2, width: 3)
      assert.false! Descent::SpriteGeometry.crosses_span?(sprite, x: 100, y: 175, height: 20, width: 1)
      assert.equal! local.to_s, before
    end
  end

  def test_alpha_bounds_resolve_source_offsets_scaling_and_sprite_anchors(_args, assert)
    sprite = { x: 64, y: 128, w: 64, h: 64, anchor_x: 0.5, anchor_y: 1,
               source_w: 32, source_h: 32, occlusion_bounds: { x: 2, y: 24, w: 3, h: 3 } }
    assert.equal! Descent::SpriteGeometry.occupied_bounds(sprite), { x: 36, y: 112, w: 6, h: 6 }
    sprite[:flip_horizontally] = true
    sprite[:flip_vertically] = true
    assert.equal! Descent::SpriteGeometry.occupied_bounds(sprite), { x: 86, y: 74, w: 6, h: 6 }
  end

  def test_all_flips_follow_unequal_scaling_without_retaining_previous_geometry(_args, assert)
    local = { x: 2, y: 24, w: 3, h: 3 }
    sprite = { x: 100, y: 200, w: 64, h: 48, anchor_x: 0.5, anchor_y: 1,
               source_w: 32, source_h: 32, occlusion_bounds: local }
    [[false, false, 72, 188], [true, false, 122, 188],
     [false, true, 72, 159.5], [true, true, 122, 159.5]].each do |flip_h, flip_v, x, y|
      sprite[:flip_horizontally] = flip_h
      sprite[:flip_vertically] = flip_v
      before = sprite.to_s
      expected = { x: x, y: y, w: 6, h: 4.5 }
      assert.equal! Descent::SpriteGeometry.occupied_bounds(sprite), expected
      assert.equal! sprite.to_s, before
    end
    sprite[:x] += 10
    assert.equal! Descent::SpriteGeometry.occupied_bounds(sprite), { x: 132, y: 159.5, w: 6, h: 4.5 }
  end

  def test_missing_measurements_use_frame_bounds_but_measured_empty_artwork_stays_empty(_args, assert)
    sprite = { x: 20, y: 30, w: 10, h: 20, anchor_x: 0.5, anchor_y: 1 }
    frame = { x: 15, y: 10, w: 10, h: 20 }
    assert.equal! Descent::SpriteGeometry.bounds(sprite), frame
    assert.equal! Descent::SpriteGeometry.occupied_bounds(sprite), frame
    sprite[:occlusion_bounds] = nil
    sprite[:occlusion_polygons] = []
    assert.equal! Descent::SpriteGeometry.bounds(sprite), frame
    assert.equal! Descent::SpriteGeometry.occupied_bounds(sprite), nil
  end
end
