# frozen_string_literal: true

require 'app/sprite_geometry'

class SpriteGeometryTests
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
    sprite[:occlusion_regions] = [sprite[:occlusion_bounds]]
    assert.equal! Descent::SpriteGeometry.occupied_regions(sprite), [{ x: 86, y: 74, w: 6, h: 6 }]
  end

  def test_all_flips_follow_unequal_scaling_without_retaining_previous_geometry(_args, assert)
    local = { x: 2, y: 24, w: 3, h: 3 }
    sprite = { x: 100, y: 200, w: 64, h: 48, anchor_x: 0.5, anchor_y: 1,
               source_w: 32, source_h: 32, occlusion_bounds: local, occlusion_regions: [local] }
    [[false, false, 72, 188], [true, false, 122, 188],
     [false, true, 72, 159.5], [true, true, 122, 159.5]].each do |flip_h, flip_v, x, y|
      sprite[:flip_horizontally] = flip_h
      sprite[:flip_vertically] = flip_v
      before = sprite.to_s
      expected = { x: x, y: y, w: 6, h: 4.5 }
      assert.equal! Descent::SpriteGeometry.occupied_bounds(sprite), expected
      assert.equal! Descent::SpriteGeometry.occupied_regions(sprite), [expected]
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
    assert.equal! Descent::SpriteGeometry.occupied_regions(sprite), [frame]
    sprite[:occlusion_bounds] = nil
    sprite[:occlusion_regions] = []
    assert.equal! Descent::SpriteGeometry.bounds(sprite), frame
    assert.equal! Descent::SpriteGeometry.occupied_bounds(sprite), nil
    assert.equal! Descent::SpriteGeometry.occupied_regions(sprite), []
  end
end
