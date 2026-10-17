# frozen_string_literal: true

require 'chunky_png'
require 'fileutils'
require 'json'
require 'pathname'
require 'rgeo'
require_relative '../mygame/app/occluder_data'

# Run by Rake, never by DragonRuby. Polygon contours are the source of truth;
# horizontal samples derived from them keep runtime fade queries inexpensive.
class OccluderAssets
  def initialize(tolerance: 2)
    raise ArgumentError, 'Tolerance must be finite and nonnegative' unless tolerance.finite? && tolerance >= 0
    raise 'GEOS is unavailable. Install GEOS development files, then rebuild the rgeo gem.' unless RGeo::Geos.supported?

    @tolerance = tolerance
    @factory = RGeo::Geos.factory(native_interface: :capi)
  end

  # Keep every connected part, fill its holes, and simplify each exterior.
  # Coordinates are pixel edges, in source-local bottom-left space, without a
  # repeated closing point. Transparent RGB values do not affect occupancy.
  def outline(image)
    cells = []
    image.height.times do |y|
      image.width.times do |x|
        cells << pixel_square(x, y) if ChunkyPNG::Color.a(image[x, y]).positive?
      end
    end
    return { polygons: [], regions: [], bounds: nil } if cells.empty?

    merged = @factory.collection(cells).unary_union
    parts = RGeo::Feature::Polygon.check_type(merged) ? [merged] : merged.to_a
    filled = @factory.collection(parts.map { |part| @factory.polygon(part.exterior_ring) }).unary_union
    parts = RGeo::Feature::Polygon.check_type(filled) ? [filled] : filled.to_a
    # Simplification order affects nearby components. Normalize both their
    # order and ring starting points before GEOS makes those choices.
    rings = parts.map { |part| canonical_ring(part.exterior_ring.points[0...-1].map { |p| [p.x, p.y] }) }.sort
    filled = @factory.multi_polygon(rings.map { |ring| polygon(ring) })
    simplified = filled.simplify_preserve_topology(@tolerance)
    parts = RGeo::Feature::Polygon.check_type(simplified) ? [simplified] : simplified.to_a
    polygons = parts.map do |part|
      points = part.exterior_ring.points[0...-1].map { |point| [point.x, image.height - point.y] }
      canonical_ring(points)
    end.sort
    xs = polygons.flatten(1).map(&:first)
    ys = polygons.flatten(1).map(&:last)
    { polygons: polygons, regions: fade_regions(polygons, image.width, image.height),
      bounds: [xs.min, ys.min, xs.max - xs.min, ys.max - ys.min] }
  end

  def generate(map_path, output:)
    map_path = File.expand_path(map_path)
    map = JSON.parse(File.read(map_path))
    tilesets = map.fetch('tilesets').map do |tileset|
      raise ArgumentError, 'Use a JSON map with embedded tilesets' if tileset['source']

      image_path = File.expand_path(tileset.fetch('image'), File.dirname(map_path))
      image = ChunkyPNG::Image.from_file(image_path)
      tiles = Array.new(tileset.fetch('tilecount')) do |id|
        tile = crop(image, tileset, id)
        outline(tile)
      end
      game_root = Pathname.new(File.expand_path('../mygame', __dir__))
      { image: Pathname.new(image_path).relative_path_from(game_root).to_s,
        fingerprint: Descent::OccluderData.fingerprint(File.binread(image_path)),
        image_width: image.width, image_height: image.height,
        tile_width: tileset.fetch('tilewidth'), tile_height: tileset.fetch('tileheight'),
        columns: tileset.fetch('columns'), margin: tileset.fetch('margin', 0),
        spacing: tileset.fetch('spacing', 0), tiles: tiles }
    end
    data = { format_version: 3, coordinate_origin: 'bottom_left', alpha_threshold: 1,
             tolerance: @tolerance, policy: 'all_components_filled_exteriors', tilesets: tilesets }
    FileUtils.mkdir_p(output)
    File.write(File.join(output, 'occluders.json'), "#{JSON.generate(data)}\n")
    data
  end

  private

  def fade_regions(polygons, width, height)
    shapes = polygons.map { |ring| polygon(ring) }
    area = @factory.collection(shapes).unary_union
    regions = []
    previous = {}
    height.times do |y|
      line = @factory.line(@factory.point(0, y + 0.5), @factory.point(width, y + 0.5))
      intersection = area.intersection(line)
      spans = RGeo::Feature::LineString.check_type(intersection) ? [intersection] : intersection.to_a
      current = {}
      spans.each do |span|
        next unless RGeo::Feature::LineString.check_type(span) && !span.empty?

        xs = span.points.map(&:x)
        key = [xs.min, xs.max - xs.min]
        next unless key.last.positive?

        if previous[key]
          region = previous[key]
          region[3] += 1
        else
          region = [key.first, y, key.last, 1]
          regions << region
        end
        current[key] = region
      end
      previous = current
    end
    regions.sort
  end

  def pixel_square(x, y)
    polygon([[x, y], [x + 1, y], [x + 1, y + 1], [x, y + 1]])
  end

  def polygon(ring)
    points = ring.map { |x, y| @factory.point(x, y) }
    @factory.polygon(@factory.linear_ring(points + [points.first]))
  end

  def canonical_ring(points)
    points = points.each_with_index.reject do |point, index|
      before = points[index - 1]
      after = points[(index + 1) % points.length]
      ((point[0] - before[0]) * (after[1] - point[1])) == ((point[1] - before[1]) * (after[0] - point[0]))
    end.map(&:first)
    area = points.each_with_index.sum do |point, index|
      following = points[(index + 1) % points.length]
      (point[0] * following[1]) - (following[0] * point[1])
    end
    points.reverse! if area.negative?
    points.rotate(points.each_index.min_by { |index| points[index] })
  end

  def crop(image, tileset, id)
    width = tileset.fetch('tilewidth')
    height = tileset.fetch('tileheight')
    margin = tileset.fetch('margin', 0)
    spacing = tileset.fetch('spacing', 0)
    column = id % tileset.fetch('columns')
    row = id.div(tileset.fetch('columns'))
    image.crop(margin + (column * (width + spacing)), margin + (row * (height + spacing)), width, height)
  end
end
