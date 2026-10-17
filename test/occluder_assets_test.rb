# frozen_string_literal: true

require 'minitest/autorun'
require 'tmpdir'
require_relative '../lib/occluder_assets'

class OccluderAssetsTest < Minitest::Test
  def image(*rows)
    result = ChunkyPNG::Image.new(rows.first.length, rows.length, ChunkyPNG::Color::TRANSPARENT)
    rows.each_with_index do |row, y|
      row.chars.each_with_index { |pixel, x| result[x, y] = ChunkyPNG::Color::WHITE if pixel == '#' }
    end
    result
  end

  def test_empty_and_single_pixel_at_crop_boundary
    generator = OccluderAssets.new(tolerance: 0)
    assert_empty generator.outline(image('...'))[:polygons]
    assert_equal [[[0, 0], [1, 0], [1, 1], [0, 1]]], generator.outline(image('#'))[:polygons]
  end

  def test_fills_holes_and_preserves_detached_pieces
    result = OccluderAssets.new(tolerance: 0).outline(image('###..', '#.#.#', '###..'))
    assert_equal [[[0, 0], [3, 0], [3, 3], [0, 3]], [[4, 1], [5, 1], [5, 2], [4, 2]]], result[:polygons]
    assert_equal [[0, 0, 3, 3], [4, 1, 1, 1]], result[:regions]
    assert_equal [0, 0, 5, 3], result[:bounds]
  end

  def test_keeps_a_wall_and_smaller_cap_without_connecting_them_at_both_tolerances
    sprite = image('####....', '####....', '........', '......##', '......##')
    [1, 2].each do |tolerance|
      result = OccluderAssets.new(tolerance: tolerance).outline(sprite)
      assert_equal 2, result[:polygons].length
      factory = RGeo::Geos.factory
      shapes = result[:polygons].map do |ring|
        points = ring.map { |x, y| factory.point(x, y) }
        factory.polygon(factory.linear_ring(points + [points.first]))
      end
      assert shapes.all?(&:valid?)
      assert factory.multi_polygon(shapes).valid?, 'Simplification must preserve separate parts without overlaps'
      assert shapes.any? { |shape| shape.intersects?(factory.point(2, 4)) }, 'The wall must remain'
      assert shapes.any? { |shape| shape.intersects?(factory.point(7, 1)) }, 'The smaller cap must remain'
      refute shapes.any? { |shape| shape.intersects?(factory.point(5, 2.5)) }, 'The gap must stay empty'
      refute result[:regions].any? { |x, y, w, h| x <= 5 && x + w > 5 && y <= 2.5 && y + h > 2.5 },
             'Derived fade regions must not bridge separate pieces'
    end
  end

  def test_filled_hole_does_not_leave_a_redundant_inner_island_boundary
    sprite = image('#######..', '#.....#..', '#.....#.#', '#..#..#..', '#.....#..', '#.....#..', '#######..')
    result = OccluderAssets.new(tolerance: 0).outline(sprite)
    assert_equal 2, result[:polygons].length, 'The filled shell and the external piece each need one boundary'
    assert_equal [[0, 0, 7, 7], [8, 4, 1, 1]], result[:regions]
  end

  def test_preserves_large_l_shaped_notch_and_thin_wall
    generator = OccluderAssets.new(tolerance: 1)
    l_shape = image('######', '######', '....##', '....##', '....##', '....##')
    factory = RGeo::Geos.factory
    points = generator.outline(l_shape)[:polygons].fetch(0).map { |x, y| factory.point(x, y) }
    shape = factory.polygon(factory.linear_ring(points + [points.first]))
    assert shape.valid?
    refute shape.contains?(factory.point(2, 2)), 'The large empty notch must remain empty'
    assert shape.contains?(factory.point(2, 5)), 'The broad arm must remain occupied'
    assert shape.contains?(factory.point(5, 2)), 'The narrow arm must remain occupied'
    wall = generator.outline(image('#', '#', '#', '#'))[:polygons].fetch(0)
    assert_equal [0, 1], wall.map(&:first).minmax
    assert_equal [0, 4], wall.map(&:last).minmax
  end

  def test_alpha_controls_occupancy_independently_of_rgb
    sprite = image('..')
    sprite[0, 0] = ChunkyPNG::Color.rgba(255, 128, 64, 0)
    sprite[1, 0] = ChunkyPNG::Color.rgba(0, 0, 0, 1)
    assert_equal [[[1, 0], [2, 0], [2, 1], [1, 1]]], OccluderAssets.new(tolerance: 0).outline(sprite)[:polygons]
  end

  def test_simplification_reduces_detail_and_retains_a_valid_polygon
    sprite = image('########', '########', '#######.', '########', '########')
    exact = OccluderAssets.new(tolerance: 0).outline(sprite)[:polygons].fetch(0)
    coarse = OccluderAssets.new(tolerance: 1).outline(sprite)[:polygons].fetch(0)
    assert_operator coarse.length, :<, exact.length
    assert_operator coarse.length, :>=, 3
    factory = RGeo::Geos.factory
    points = coarse.map { |x, y| factory.point(x, y) }
    assert factory.polygon(factory.linear_ring(points + [points.first])).valid?
  end

  def test_exports_all_embedded_tilesets_reproducibly_without_modifying_the_map
    map = File.expand_path('../mygame/tiled/ritual_gate.json', __dir__)
    original = File.binread(map)
    Dir.mktmpdir do |output|
      generator = OccluderAssets.new
      data = generator.generate(map, output: output)
      first = File.binread(File.join(output, 'occluders.json'))
      generator.generate(map, output: output)
      assert first == File.binread(File.join(output, 'occluders.json')), 'Regeneration must be byte-for-byte identical'
      assert_equal original, File.binread(map)
      assert_equal 4, data[:tilesets].length
      assert(data[:tilesets].all? { |tileset| tileset[:tiles].length.positive? })
      assert_equal ['occluders.json'], Dir.children(output)
      assert(data[:tilesets].all? { |tileset| tileset[:tiles].all? { |tile| tile.key?(:regions) } })
    end
  end
end
