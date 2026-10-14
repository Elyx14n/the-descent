# frozen_string_literal: true

require 'app/room_data'

module Descent
  # Decode finite orthogonal Tiled exports into keyword data for Room.new.
  # All loading state belongs to one call; no Room, camera, or outputs are used.
  module TiledDeserializer
    LAYERS = { 'Ground' => 'tilelayer', 'FloorDetails' => 'objectgroup', 'Walls' => 'objectgroup',
               'Props' => 'objectgroup', 'Ceiling' => 'tilelayer' }.freeze
    TYPES_BY_CLASS = { 'Ground' => :ground, 'FloorDetail' => :floor_detail, 'Wall' => :wall, 'Prop' => :prop,
                       'Ceiling' => :ceiling, 'Door' => :door, 'Light' => :light, 'Pedestal' => :pedestal,
                       'Spawn' => :spawn }.freeze
    # The first type is the default for unclassified artwork on that layer.
    LAYER_TYPES = { 'Ground' => %i[ground].freeze, 'FloorDetails' => %i[floor_detail].freeze,
                    'Walls' => %i[wall].freeze, 'Props' => %i[prop door light pedestal].freeze,
                    'Ceiling' => %i[ceiling door].freeze }.freeze
    LAYER_OFFSET_KEYS = %w[x y offsetx offsety].freeze
    SUPPORTED_OBJECT_ALIGNMENTS = [nil, 'unspecified', 'bottomleft'].freeze
    UNSUPPORTED_COLLISION_SHAPES = %w[polygon polyline ellipse point].freeze

    # Tiled packs a map-wide tile ID and transformation flags into one 32-bit
    # integer (GID). The highest four bits hold flags; the lower 28 hold the ID.
    # These are hexadecimal numbers (0x); each hex digit represents four bits.
    # https://doc.mapeditor.org/en/stable/reference/global-tile-ids/
    GID_MASK = 0x0fffffff   # Lower 28 bits are 1: `gid & GID_MASK` clears all flags.
    HORIZONTAL = 0x80000000 # Highest bit: mirror the tile left/right.
    VERTICAL = 0x40000000   # Next highest bit: mirror the tile top/bottom.

    class << self
      def load(gtk, path:)
        contents = gtk.read_file(path)
        raise ArgumentError, "#{path}: Cannot read Tiled map" unless contents

        deserialize(gtk.parse_json(contents), path: path, image_loader: ->(image) { gtk.get_pixels(image) })
      end

      def deserialize(data, path:, image_loader:)
        context = {
          data: data,
          path: path,
          collections: RoomData.empty_collections,
          caps: {},
          spawns: [],
          image_loader: image_loader,
          images: {},
          alpha_bounds: {}
        }
        validate_map(context)
        prepare_tilesets(context)
        data.fetch('layers').each do |layer|
          if layer['type'] == 'tilelayer'
            load_tile_layer(context, layer)
          else
            load_object_layer(context, layer)
          end
        end
        link_door_caps(context)
        link_mounted_props(context)
        raise_map_error(context, 'Expected exactly one point object of class Spawn') unless context[:spawns].length == 1
        {
          bounds: { x: 0, y: 0, w: context[:width], h: context[:height] },
          spawn: context[:spawns].first,
          collections: context.fetch(:collections)
        }
      rescue KeyError => e
        raise ArgumentError, "#{path}: #{e.message}"
      end

      private

      def raise_map_error(context, message)
        raise ArgumentError, "#{context[:path]}: #{message}"
      end

      def validate_map(context)
        data = context[:data]
        unless data.is_a?(Hash) && data['type'] == 'map' && data['orientation'] == 'orthogonal' && !data['infinite']
          raise_map_error(context, 'Export a finite orthogonal JSON map')
        end
        context[:tile_w] = data.fetch('tilewidth')
        context[:tile_h] = data.fetch('tileheight')
        context[:width] = data.fetch('width') * context[:tile_w]
        context[:height] = data.fetch('height') * context[:tile_h]
        dimensions = context.values_at(:tile_w, :tile_h, :width, :height)
        raise_map_error(context, 'Map dimensions must be positive') unless dimensions.all?(&:positive?)
        layers = data.fetch('layers')
        unless layers.map { |layer| layer['name'] }.sort == LAYERS.keys.sort
          raise_map_error(context, "Expected layers: #{LAYERS.keys.join(', ')}")
        end
        layers.each do |layer|
          unless layer['type'] == LAYERS.fetch(layer['name'])
            raise_map_error(context,
                            "Wrong layer type for #{layer['name']}")
          end
          if LAYER_OFFSET_KEYS.any? { |key| layer.fetch(key, 0) != 0 }
            raise_map_error(context, "Layer offsets are not supported: #{layer['name']}")
          end
        end
      end

      def prepare_tilesets(context)
        context[:tilesets] = context[:data].fetch('tilesets').map do |tileset|
          raise_map_error(context, 'Embed tilesets in the JSON export') if tileset['source']
          unless SUPPORTED_OBJECT_ALIGNMENTS.include?(tileset['objectalignment'])
            raise_map_error(context, "Use bottom-left object alignment: #{tileset['name']}")
          end
          raise_map_error(context, 'Tileset drawing offsets are not supported') if tileset['tileoffset']
          tileset.merge('resolved_image' => image_path(context, tileset.fetch('image')),
                        'tile_definitions' => tileset.fetch('tiles', []).to_h { |tile| [tile.fetch('id'), tile] })
        end
        context[:tilesets] = context[:tilesets].sort_by { |tileset| tileset.fetch('firstgid') }
      end

      def image_path(context, image)
        if image.start_with?('/', '\\') || image.include?(':')
          raise_map_error(context, "Image path must be relative: #{image}")
        end
        components = context[:path].split('/')[0...-1]
        image.tr('\\', '/').split('/').each do |part|
          next if part == '.' || part.empty?

          if part == '..'
            raise_map_error(context, "Image is outside the game directory: #{image}") if components.empty?
            components.pop
          else
            components << part
          end
        end
        components.join('/')
      end

      def tile_for_gid(context, gid)
        # The other two flag bits are diagonal flip (0x20000000) and hexagonal
        # 120-degree rotation (0x10000000). This importer rejects either flag.
        raise_map_error(context, 'Diagonal tile flips are not supported') unless gid.nobits?(0x30000000)
        # Bitwise AND keeps only the ID. A flipped tile would otherwise appear
        # to have an enormous ID. Subtract firstgid to get its tileset-local ID.
        raw = gid & GID_MASK
        tileset = context[:tilesets].reverse.find { |candidate| raw >= candidate['firstgid'] }
        raise_map_error(context, "Unknown tile GID #{gid}") unless tileset
        local_tile(context, tileset, raw - tileset['firstgid'])
      end

      def local_tile(context, tileset, id)
        unless id.is_a?(Integer) && id >= 0 && id < tileset.fetch('tilecount')
          raise_map_error(context, "Invalid tile ID #{id} in #{tileset['name']}")
        end
        { tileset: tileset, id: id, definition: tileset['tile_definitions'].fetch(id, {}) }
      end

      def properties(value)
        value.fetch('properties', []).to_h { |property| [property.fetch('name'), property.fetch('value')] }
      end

      def tile_class(value)
        authored = value['class']
        authored.nil? || authored == '' ? value['type'] : authored
      end

      # Resolve authoring classes and placement defaults once, at the boundary.
      # Downstream room/rendering code consumes only these canonical symbols.
      def entry_type(context, layer, tile: nil, object: nil)
        authored = tile_class(object) if object
        authored = tile_class(tile[:definition]) if tile && (authored.nil? || authored == '')
        allowed = LAYER_TYPES.fetch(layer['name'])
        type = if authored.nil? || authored == ''
                 allowed.first
               else
                 TYPES_BY_CLASS.fetch(authored) do
                   raise_map_error(context, "Unknown tile class #{authored.inspect} on #{layer['name']}")
                 end
               end
        if type == :spawn
          raise_map_error(context, 'Spawn must be a point object') unless object && object['point']
        elsif !allowed.include?(type)
          raise_map_error(context, "Type #{type} is not supported on #{layer['name']}")
        end
        type
      end

      def sprite_for(context, tile, rect, type:, gid: 0, opacity: 1)
        tileset = tile[:tileset]
        w = tileset.fetch('tilewidth')
        h = tileset.fetch('tileheight')
        margin = tileset.fetch('margin', 0)
        spacing = tileset.fetch('spacing', 0)
        column = tile[:id] % tileset.fetch('columns')
        row = tile[:id].div(tileset.fetch('columns'))
        # Test flags on the original GID, not the tile ID that had them cleared.
        # anybits? returns a boolean for DragonRuby's sprite flip settings.
        sprite = rect.merge(type: type, path: tileset.fetch('resolved_image'),
                            source_x: margin + (column * (w + spacing)),
                            source_y: tileset.fetch('imageheight') - margin - (row * (h + spacing)) - h,
                            source_w: w, source_h: h, a: (opacity * 255).round,
                            flip_horizontally: gid.anybits?(HORIZONTAL), flip_vertically: gid.anybits?(VERTICAL))
        sprite.merge(occlusion_bounds: alpha_bounds(context, sprite))
      end

      # Measure each crop once per load. Store source-local bottom-left bounds,
      # retaining offsets so padding rejection follows placement, scale and flips.
      def alpha_bounds(context, sprite)
        key = sprite.values_at(:path, :source_x, :source_y, :source_w, :source_h)
        cache = context[:alpha_bounds]
        return cache[key] if cache.key?(key)

        image = context[:images][sprite[:path]] ||= context[:image_loader].call(sprite[:path])
        unless image && image[:pixels] && image[:w].positive? && image[:h].positive?
          raise_map_error(context, "Cannot read tile image: #{sprite[:path]}")
        end
        top = image[:h] - sprite[:source_y] - sprite[:source_h]
        if top.negative? || sprite[:source_x].negative? ||
           sprite[:source_x] + sprite[:source_w] > image[:w] || top + sprite[:source_h] > image[:h]
          raise_map_error(context, "Tile crop is outside image: #{sprite[:path]}")
        end

        left = sprite[:source_w]
        upper = sprite[:source_h]
        right = lower = 0
        sprite[:source_h].times do |row|
          offset = ((top + row) * image[:w]) + sprite[:source_x]
          sprite[:source_w].times do |column|
            alpha = (image[:pixels][offset + column] >> 24) & 255
            next if alpha.zero?

            left = [left, column].min
            upper = [upper, row].min
            right = [right, column + 1].max
            lower = [lower, row + 1].max
          end
        end
        cache[key] = ({ x: left, y: sprite[:source_h] - lower, w: right - left, h: lower - upper } if right > left)
      end

      def load_tile_layer(context, layer)
        collections = context.fetch(:collections)
        unless layer.fetch('data').length == layer['width'] * layer['height']
          raise_map_error(context, "Invalid tile data length in #{layer['name']}")
        end
        layer.fetch('data').each_with_index do |gid, index|
          next if gid.zero?

          tile = tile_for_gid(context, gid)
          type = entry_type(context, layer, tile: tile)
          column = index % layer['width']
          row = index.div(layer['width'])
          rect = { x: column * context[:tile_w], y: context[:height] - ((row + 1) * context[:tile_h]),
                   w: tile[:tileset]['tilewidth'], h: tile[:tileset]['tileheight'] }
          sprite = sprite_for(context, tile, rect, type: type, gid: gid, opacity: layer.fetch('opacity', 1))
          target = layer['name'] == 'Ground' ? collections[:ground] : collections[:ceiling]
          target << sprite if layer.fetch('visible', true)
          if type == :door
            context[:caps][[column, row]] = door_part(context, tile, sprite, properties(tile[:definition]))
          elsif layer['name'] == 'Ground'
            collections[:colliders].concat(collision_shapes(context, tile, sprite))
          end
        end
      end

      def load_object_layer(context, layer)
        collections = context.fetch(:collections)
        layer.fetch('objects').each do |object|
          unless object.fetch('rotation', 0).zero?
            raise_map_error(context, "Rotated objects are not supported: #{object['id']}")
          end
          if object['point'] && entry_type(context, layer, object: object) == :spawn
            context[:spawns] << { x: object.fetch('x'), y: context[:height] - object.fetch('y'), facing: :south }
            next
          end
          raise_map_error(context, "Expected a tile object or Spawn point: #{object['id']}") unless object['gid']
          tile = tile_for_gid(context, object['gid'])
          type = entry_type(context, layer, tile: tile, object: object)
          rect = { x: object.fetch('x'), y: context[:height] - object.fetch('y'),
                   w: object.fetch('width'), h: object.fetch('height') }
          sprite = sprite_for(context, tile, rect, type: type, gid: object['gid'],
                                                   opacity: layer.fetch('opacity', 1) * object.fetch('opacity', 1))
          props = properties(tile[:definition]).merge(properties(object))
          shapes = collision_shapes(context, tile, sprite)
          entry = { id: object.fetch('id'), type: type, sprite: sprite, properties: props,
                    colliders: shapes }
          target = layer['name'] == 'FloorDetails' ?
          collections[:floor_details] : collections[:objects]
          target << entry if layer.fetch('visible', true) && object.fetch('visible', true)
          if type == :door
            part = door_part(context, tile, sprite, props)
            closed = local_tile(context, tile[:tileset], props.fetch('close_tile'))
            opened = local_tile(context, tile[:tileset], props.fetch('open_tile'))
            entry.merge!(open: tile[:id] == props.fetch('open_tile'), parts: [part],
                         closed_colliders: collision_shapes(context, closed, part[:closed_sprite]),
                         open_colliders: collision_shapes(context, opened, part[:open_sprite]))
            collections[:doors] << entry
          else
            collections[:colliders].concat(shapes)
            collections[:lights] << light_source(entry, sprite, props) if type == :light
            if type == :pedestal
              # Item anchor uses the same source-pixel convention as light offsets.
              entry[:item_position] = local_point(sprite, props.fetch('offset_x', 0), props.fetch('offset_y', 0))
              collections[:pedestals] << entry
            end
          end
        end
      end

      # Resolve and validate the authored wall reference; Room builds draw groups.
      def link_mounted_props(context)
        collections = context.fetch(:collections)
        by_id = collections[:objects].to_h { |entry| [entry[:id], entry] }
        collections[:objects].each do |entry|
          target_id = entry[:properties].fetch('mounted_on', 0)
          next if target_id.is_a?(Integer) && target_id.zero?

          unless target_id.is_a?(Integer) && target_id.positive? && LAYER_TYPES['Props'].include?(entry[:type])
            raise_map_error(context, "Set mounted_on on a Props object to a Walls object reference: #{entry[:id]}")
          end
          wall = by_id[target_id]
          unless wall && wall[:type] == :wall
            raise_map_error(context,
                            "mounted_on target #{target_id} for object #{entry[:id]} is not a visible Walls object")
          end
          entry[:mounted_on] = target_id
        end
      end

      # Transform local top-left coordinates into world bottom-left coordinates.
      def local_point(sprite, x, y)
        x = sprite[:source_w] - x if sprite[:flip_horizontally]
        y = sprite[:source_h] - y if sprite[:flip_vertically]
        { x: sprite[:x] + (x * sprite[:w].fdiv(sprite[:source_w])),
          y: sprite[:y] + ((sprite[:source_h] - y) * sprite[:h].fdiv(sprite[:source_h])) }
      end

      def collision_shapes(context, tile, sprite)
        tile[:definition].fetch('objectgroup', {}).fetch('objects', []).map do |shape|
          if UNSUPPORTED_COLLISION_SHAPES.any? { |key| shape[key] } || shape.fetch('rotation', 0) != 0
            raise_map_error(context, "Use rectangle collision shapes on tile #{tile[:id]}")
          end
          unless shape['width'].positive? && shape['height'].positive?
            raise_map_error(context, 'Collision rectangles must have positive dimensions')
          end
          first = local_point(sprite, shape.fetch('x'), shape.fetch('y'))
          last = local_point(sprite, shape['x'] + shape['width'], shape['y'] + shape['height'])
          { x: [first[:x], last[:x]].min, y: [first[:y], last[:y]].min,
            w: (last[:x] - first[:x]).abs, h: (last[:y] - first[:y]).abs }
        end
      end

      def light_source(entry, sprite, props)
        local_point(sprite, props.fetch('offset_x', 0), props.fetch('offset_y', 0)).merge(
          id: entry[:id], enabled: props.fetch('enabled', true), radius: props.fetch('radius', 0),
          intensity: props.fetch('intensity', 0), color: props.fetch('color', '')
        )
      end

      def door_part(context, tile, sprite, props)
        closed = props['close_tile']
        opened = props['open_tile']
        if closed.nil? || opened.nil? || closed == opened
          raise_map_error(context, "Set distinct close_tile and open_tile on Door tile #{tile[:id]}")
        end
        unless [closed, opened].include?(tile[:id])
          raise_map_error(context, "Door tile #{tile[:id]} does not belong to its pair")
        end
        [closed, opened].each do |id|
          variant = local_tile(context, tile[:tileset], id)
          pair = properties(variant[:definition])
          unless tile_class(variant[:definition]) == 'Door' &&
                 pair['close_tile'] == closed && pair['open_tile'] == opened
            raise_map_error(context, "Inconsistent Door pair #{closed}/#{opened}")
          end
        end
        { sprite: sprite, closed_sprite: door_sprite(context, tile[:tileset], closed, sprite),
          open_sprite: door_sprite(context, tile[:tileset], opened, sprite) }
      end

      def door_sprite(context, tileset, id, sprite)
        # Retain placement, scaling and flips while changing only the atlas crop.
        sprite_for(context, local_tile(context, tileset, id), sprite, type: sprite.fetch(:type)).merge(
          flip_horizontally: sprite[:flip_horizontally], flip_vertically: sprite[:flip_vertically], a: sprite[:a]
        )
      end

      def link_door_caps(context)
        collections = context.fetch(:collections)
        collections[:doors].each do |door|
          sprite = door[:sprite]
          column = sprite[:x].fdiv(context[:tile_w])
          row = (context[:height] - sprite[:y] - sprite[:h]).fdiv(context[:tile_h]) - 1
          unless column == column.to_i && row == row.to_i
            raise_map_error(context,
                            "Place door #{door[:id]} on the tile grid")
          end
          cap = context[:caps].delete([column.to_i, row.to_i])
          door[:parts] << cap if cap
        end
        raise_map_error(context, 'Ceiling Door piece has no base immediately below it') unless context[:caps].empty?
      end
    end
  end
end
