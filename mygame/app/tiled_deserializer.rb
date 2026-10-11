# frozen_string_literal: true

module Descent
  # Decode finite orthogonal Tiled exports into keyword data for Room.new.
  # All loading state belongs to one call; no Room, camera, or outputs are used.
  module TiledDeserializer
    LAYERS = { 'Ground' => 'tilelayer', 'FloorDetails' => 'objectgroup', 'Walls' => 'objectgroup',
               'Props' => 'objectgroup', 'Ceiling' => 'tilelayer' }.freeze

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

        deserialize(gtk.parse_json(contents), path: path)
      end

      def deserialize(data, path:)
        context = { data: data, path: path, ground: [], floor_details: [], objects: [], ceiling: [],
                    colliders: [], doors: [], lights: [], pedestals: [], caps: {}, spawns: [] }
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
        fail_map(context, 'Expected exactly one point object of class Spawn') unless context[:spawns].length == 1
        { bounds: { x: 0, y: 0, w: context[:width], h: context[:height] }, spawn: context[:spawns].first,
          ground: context[:ground], floor_details: context[:floor_details], objects: context[:objects],
          ceiling: context[:ceiling], colliders: context[:colliders], doors: context[:doors],
          lights: context[:lights], pedestals: context[:pedestals] }
      rescue KeyError => e
        raise ArgumentError, "#{path}: #{e.message}"
      end

      private

      def fail_map(context, message)
        raise ArgumentError, "#{context[:path]}: #{message}"
      end

      def validate_map(context)
        data = context[:data]
        unless data.is_a?(Hash) && data['type'] == 'map' && data['orientation'] == 'orthogonal' && !data['infinite']
          fail_map(context, 'Export a finite orthogonal JSON map')
        end
        context[:tile_w] = data.fetch('tilewidth')
        context[:tile_h] = data.fetch('tileheight')
        context[:width] = data.fetch('width') * context[:tile_w]
        context[:height] = data.fetch('height') * context[:tile_h]
        dimensions = context.values_at(:tile_w, :tile_h, :width, :height)
        fail_map(context, 'Map dimensions must be positive') unless dimensions.all?(&:positive?)
        layers = data.fetch('layers')
        unless layers.map { |layer| layer['name'] }.sort == LAYERS.keys.sort
          fail_map(context, "Expected layers: #{LAYERS.keys.join(', ')}")
        end
        layers.each do |layer|
          fail_map(context, "Wrong layer type for #{layer['name']}") unless layer['type'] == LAYERS.fetch(layer['name'])
          if %w[x y offsetx offsety].any? { |key| layer.fetch(key, 0) != 0 }
            fail_map(context, "Layer offsets are not supported: #{layer['name']}")
          end
        end
      end

      def prepare_tilesets(context)
        context[:tilesets] = context[:data].fetch('tilesets').map do |tileset|
          fail_map(context, 'Embed tilesets in the JSON export') if tileset['source']
          unless [nil, 'unspecified', 'bottomleft'].include?(tileset['objectalignment'])
            fail_map(context, "Use bottom-left object alignment: #{tileset['name']}")
          end
          fail_map(context, 'Tileset drawing offsets are not supported') if tileset['tileoffset']
          tileset.merge('resolved_image' => image_path(context, tileset.fetch('image')),
                        'tile_definitions' => tileset.fetch('tiles', []).to_h { |tile| [tile.fetch('id'), tile] })
        end
        context[:tilesets] = context[:tilesets].sort_by { |tileset| tileset.fetch('firstgid') }
      end

      def image_path(context, image)
        if image.start_with?('/', '\\') || image.include?(':')
          fail_map(context, "Image path must be relative: #{image}")
        end
        components = context[:path].split('/')[0...-1]
        image.tr('\\', '/').split('/').each do |part|
          next if part == '.' || part.empty?

          if part == '..'
            fail_map(context, "Image is outside the game directory: #{image}") if components.empty?
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
        fail_map(context, 'Diagonal tile flips are not supported') unless gid.nobits?(0x30000000)
        # Bitwise AND keeps only the ID. A flipped tile would otherwise appear
        # to have an enormous ID. Subtract firstgid to get its tileset-local ID.
        raw = gid & GID_MASK
        tileset = context[:tilesets].reverse.find { |candidate| raw >= candidate['firstgid'] }
        fail_map(context, "Unknown tile GID #{gid}") unless tileset
        local_tile(context, tileset, raw - tileset['firstgid'])
      end

      def local_tile(context, tileset, id)
        unless id.is_a?(Integer) && id >= 0 && id < tileset.fetch('tilecount')
          fail_map(context, "Invalid tile ID #{id} in #{tileset['name']}")
        end
        { tileset: tileset, id: id, definition: tileset['tile_definitions'].fetch(id, {}) }
      end

      def properties(value)
        value.fetch('properties', []).to_h { |property| [property.fetch('name'), property.fetch('value')] }
      end

      def tile_class(value)
        value['class'] || value['type']
      end

      def sprite_for(tile, rect, gid: 0, opacity: 1)
        tileset = tile[:tileset]
        w = tileset.fetch('tilewidth')
        h = tileset.fetch('tileheight')
        margin = tileset.fetch('margin', 0)
        spacing = tileset.fetch('spacing', 0)
        column = tile[:id] % tileset.fetch('columns')
        row = tile[:id].div(tileset.fetch('columns'))
        # Test flags on the original GID, not the tile ID that had them cleared.
        # anybits? returns a boolean for DragonRuby's sprite flip settings.
        rect.merge(path: tileset.fetch('resolved_image'),
                   source_x: margin + (column * (w + spacing)),
                   source_y: tileset.fetch('imageheight') - margin - (row * (h + spacing)) - h,
                   source_w: w, source_h: h, a: (opacity * 255).round,
                   flip_horizontally: gid.anybits?(HORIZONTAL), flip_vertically: gid.anybits?(VERTICAL))
      end

      def load_tile_layer(context, layer)
        unless layer.fetch('data').length == layer['width'] * layer['height']
          fail_map(context, "Invalid tile data length in #{layer['name']}")
        end
        layer.fetch('data').each_with_index do |gid, index|
          next if gid.zero?

          tile = tile_for_gid(context, gid)
          column = index % layer['width']
          row = index.div(layer['width'])
          rect = { x: column * context[:tile_w], y: context[:height] - ((row + 1) * context[:tile_h]),
                   w: tile[:tileset]['tilewidth'], h: tile[:tileset]['tileheight'] }
          sprite = sprite_for(tile, rect, gid: gid, opacity: layer.fetch('opacity', 1))
          target = layer['name'] == 'Ground' ? context[:ground] : context[:ceiling]
          target << sprite if layer.fetch('visible', true)
          if tile_class(tile[:definition]) == 'Door'
            fail_map(context, 'Door bases belong on Props, upper pieces on Ceiling') unless layer['name'] == 'Ceiling'
            context[:caps][[column, row]] = door_part(context, tile, sprite, properties(tile[:definition]))
          elsif layer['name'] == 'Ground'
            context[:colliders].concat(collision_shapes(context, tile, sprite))
          end
        end
      end

      def load_object_layer(context, layer)
        layer.fetch('objects').each do |object|
          unless object.fetch('rotation', 0).zero?
            fail_map(context, "Rotated objects are not supported: #{object['id']}")
          end
          if object['point'] && tile_class(object) == 'Spawn'
            context[:spawns] << { x: object.fetch('x'), y: context[:height] - object.fetch('y'), facing: :south }
            next
          end
          fail_map(context, "Expected a tile object or Spawn point: #{object['id']}") unless object['gid']
          tile = tile_for_gid(context, object['gid'])
          kind = tile_class(object)
          kind = tile_class(tile[:definition]) if kind.nil? || kind.empty?
          fail_map(context, 'Spawn must be a point object') if kind == 'Spawn'
          rect = { x: object.fetch('x'), y: context[:height] - object.fetch('y'),
                   w: object.fetch('width'), h: object.fetch('height') }
          sprite = sprite_for(tile, rect, gid: object['gid'],
                                          opacity: layer.fetch('opacity', 1) * object.fetch('opacity', 1))
          props = properties(tile[:definition]).merge(properties(object))
          shapes = collision_shapes(context, tile, sprite)
          entry = { id: object.fetch('id'), kind: kind, layer: layer['name'], sprite: sprite, properties: props,
                    colliders: shapes }
          target = layer['name'] == 'FloorDetails' ? context[:floor_details] : context[:objects]
          target << entry if layer.fetch('visible', true) && object.fetch('visible', true)
          if kind == 'Door'
            fail_map(context, 'Door bases belong on Props') unless layer['name'] == 'Props'
            part = door_part(context, tile, sprite, props)
            closed = local_tile(context, tile[:tileset], props.fetch('close_tile'))
            opened = local_tile(context, tile[:tileset], props.fetch('open_tile'))
            entry.merge!(open: tile[:id] == props.fetch('open_tile'), parts: [part],
                         closed_colliders: collision_shapes(context, closed, part[:closed_sprite]),
                         open_colliders: collision_shapes(context, opened, part[:open_sprite]))
            context[:doors] << entry
          else
            context[:colliders].concat(shapes)
            context[:lights] << light_source(entry, sprite, props) if kind == 'Light'
            if kind == 'Pedestal'
              # Item anchor uses the same source-pixel convention as light offsets.
              entry[:item_position] = local_point(sprite, props.fetch('offset_x', 0), props.fetch('offset_y', 0))
              context[:pedestals] << entry
            end
          end
        end
      end

      # Resolve and validate the authored wall reference; Room builds draw groups.
      def link_mounted_props(context)
        by_id = context[:objects].to_h { |entry| [entry[:id], entry] }
        context[:objects].each do |entry|
          target_id = entry[:properties].fetch('mounted_on', 0)
          next if target_id.is_a?(Integer) && target_id.zero?

          unless target_id.is_a?(Integer) && target_id.positive? && entry[:layer] == 'Props'
            fail_map(context, "Set mounted_on on a Props object to a Walls object reference: #{entry[:id]}")
          end
          wall = by_id[target_id]
          unless wall && wall[:layer] == 'Walls'
            fail_map(context, "mounted_on target #{target_id} for object #{entry[:id]} is not a visible Walls object")
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
          if %w[polygon polyline ellipse point].any? { |key| shape[key] } || shape.fetch('rotation', 0) != 0
            fail_map(context, "Use rectangle collision shapes on tile #{tile[:id]}")
          end
          unless shape['width'].positive? && shape['height'].positive?
            fail_map(context, 'Collision rectangles must have positive dimensions')
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
          fail_map(context, "Set distinct close_tile and open_tile on Door tile #{tile[:id]}")
        end
        unless [closed, opened].include?(tile[:id])
          fail_map(context, "Door tile #{tile[:id]} does not belong to its pair")
        end
        [closed, opened].each do |id|
          variant = local_tile(context, tile[:tileset], id)
          pair = properties(variant[:definition])
          unless tile_class(variant[:definition]) == 'Door' &&
                 pair['close_tile'] == closed && pair['open_tile'] == opened
            fail_map(context, "Inconsistent Door pair #{closed}/#{opened}")
          end
        end
        { sprite: sprite, closed_sprite: door_sprite(context, tile[:tileset], closed, sprite),
          open_sprite: door_sprite(context, tile[:tileset], opened, sprite) }
      end

      def door_sprite(context, tileset, id, sprite)
        # Retain placement, scaling and flips while changing only the atlas crop.
        sprite_for(local_tile(context, tileset, id), sprite).merge(
          flip_horizontally: sprite[:flip_horizontally], flip_vertically: sprite[:flip_vertically], a: sprite[:a]
        )
      end

      def link_door_caps(context)
        context[:doors].each do |door|
          sprite = door[:sprite]
          column = sprite[:x].fdiv(context[:tile_w])
          row = (context[:height] - sprite[:y] - sprite[:h]).fdiv(context[:tile_h]) - 1
          fail_map(context, "Place door #{door[:id]} on the tile grid") unless column == column.to_i && row == row.to_i
          cap = context[:caps].delete([column.to_i, row.to_i])
          door[:parts] << cap if cap
        end
        fail_map(context, 'Ceiling Door piece has no base immediately below it') unless context[:caps].empty?
      end
    end
  end
end
