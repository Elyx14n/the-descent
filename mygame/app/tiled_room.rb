# frozen_string_literal: true

require 'app/room'

module Descent
  # Import our finite, orthogonal Tiled JSON exports. Keep string keys inside
  # this boundary; loaded world data uses symbol keys and bottom-up Y.
  class TiledRoom
    LAYERS = { 'Ground' => 'tilelayer', 'FloorDetails' => 'objectgroup', 'Walls' => 'objectgroup',
               'Props' => 'objectgroup', 'Ceiling' => 'tilelayer' }.freeze
    GID_MASK = 0x0fffffff
    HORIZONTAL = 0x80000000
    VERTICAL = 0x40000000

    def self.load(gtk, path: 'tiled/ritual_gate.json')
      data = gtk.parse_json_file(path)
      raise ArgumentError, "Cannot read Tiled map #{path}" unless data

      new(data, path: path).load
    end

    def initialize(data, path:)
      @data = data
      @path = path
      @ground = []
      @floor_details = []
      @objects = []
      @ceiling = []
      @colliders = []
      @doors = []
      @lights = []
      @interactables = []
      @caps = {}
      @spawns = []
    end

    def load
      validate_map
      prepare_tilesets
      @data.fetch('layers').each do |layer|
        if layer['type'] == 'tilelayer'
          load_tile_layer(layer)
        else
          load_object_layer(layer)
        end
      end
      link_door_caps
      link_mounted_props
      fail_map('Expected exactly one point object of class Spawn') unless @spawns.length == 1
      Room.new(bounds: { x: 0, y: 0, w: @width, h: @height }, spawn: @spawns.first,
               ground: @ground, floor_details: @floor_details, objects: @objects, ceiling: @ceiling,
               colliders: @colliders,
               doors: @doors, lights: @lights, interactables: @interactables)
    end

    private

    def fail_map(message)
      raise ArgumentError, "#{@path}: #{message}"
    end

    def validate_map
      unless @data['type'] == 'map' && @data['orientation'] == 'orthogonal' && !@data['infinite']
        fail_map('Export a finite orthogonal JSON map')
      end
      @tile_w = @data.fetch('tilewidth')
      @tile_h = @data.fetch('tileheight')
      @width = @data.fetch('width') * @tile_w
      @height = @data.fetch('height') * @tile_h
      fail_map('Map dimensions must be positive') unless [@tile_w, @tile_h, @width, @height].all?(&:positive?)
      layers = @data.fetch('layers')
      unless layers.map { |layer| layer['name'] }.sort == LAYERS.keys.sort
        fail_map("Expected layers: #{LAYERS.keys.join(', ')}")
      end
      layers.each do |layer|
        fail_map("Wrong layer type for #{layer['name']}") unless layer['type'] == LAYERS.fetch(layer['name'])
        if %w[x y offsetx offsety].any? { |key| layer.fetch(key, 0) != 0 }
          fail_map("Layer offsets are not supported: #{layer['name']}")
        end
      end
    end

    def prepare_tilesets
      @tilesets = @data.fetch('tilesets').map do |tileset|
        fail_map('Embed tilesets in the JSON export') if tileset['source']
        unless [nil, 'unspecified', 'bottomleft'].include?(tileset['objectalignment'])
          fail_map("Use bottom-left object alignment: #{tileset['name']}")
        end
        fail_map('Tileset drawing offsets are not supported') if tileset['tileoffset']
        tileset.merge('resolved_image' => image_path(tileset.fetch('image')),
                      'tile_definitions' => tileset.fetch('tiles', []).to_h { |tile| [tile.fetch('id'), tile] })
      end
      @tilesets = @tilesets.sort_by { |tileset| tileset.fetch('firstgid') }
    end

    def image_path(image)
      fail_map("Image path must be relative: #{image}") if image.start_with?('/', '\\') || image.include?(':')
      components = @path.split('/')[0...-1]
      image.tr('\\', '/').split('/').each do |part|
        next if part == '.' || part.empty?

        if part == '..'
          fail_map("Image is outside the game directory: #{image}") if components.empty?
          components.pop
        else
          components << part
        end
      end
      components.join('/')
    end

    def tile_for_gid(gid)
      fail_map('Diagonal tile flips are not supported') unless gid.nobits?(0x30000000)
      raw = gid & GID_MASK
      tileset = @tilesets.reverse.find { |candidate| raw >= candidate['firstgid'] }
      fail_map("Unknown tile GID #{gid}") unless tileset
      local_tile(tileset, raw - tileset['firstgid'])
    end

    def local_tile(tileset, id)
      unless id.is_a?(Integer) && id >= 0 && id < tileset.fetch('tilecount')
        fail_map("Invalid tile ID #{id} in #{tileset['name']}")
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
      rect.merge(path: tileset.fetch('resolved_image'),
                 source_x: margin + (column * (w + spacing)),
                 source_y: tileset.fetch('imageheight') - margin - (row * (h + spacing)) - h,
                 source_w: w, source_h: h, a: (opacity * 255).round,
                 flip_horizontally: gid.anybits?(HORIZONTAL), flip_vertically: gid.anybits?(VERTICAL))
    end

    def load_tile_layer(layer)
      unless layer.fetch('data').length == layer['width'] * layer['height']
        fail_map("Invalid tile data length in #{layer['name']}")
      end
      layer.fetch('data').each_with_index do |gid, index|
        next if gid.zero?

        tile = tile_for_gid(gid)
        column = index % layer['width']
        row = index.div(layer['width'])
        sprite = sprite_for(tile, { x: column * @tile_w, y: @height - ((row + 1) * @tile_h),
                                    w: tile[:tileset]['tilewidth'], h: tile[:tileset]['tileheight'] },
                            gid: gid, opacity: layer.fetch('opacity', 1))
        target = layer['name'] == 'Ground' ? @ground : @ceiling
        target << sprite if layer.fetch('visible', true)
        if tile_class(tile[:definition]) == 'Door'
          fail_map('Door bases belong on Props, upper pieces on Ceiling') unless layer['name'] == 'Ceiling'
          @caps[[column, row]] = door_part(tile, sprite, properties(tile[:definition]))
        elsif layer['name'] == 'Ground'
          @colliders.concat(collision_shapes(tile, sprite))
        end
      end
    end

    def load_object_layer(layer)
      layer.fetch('objects').each do |object|
        fail_map("Rotated objects are not supported: #{object['id']}") unless object.fetch('rotation', 0).zero?
        if object['point'] && tile_class(object) == 'Spawn'
          @spawns << { x: object.fetch('x'), y: @height - object.fetch('y'), facing: :south }
          next
        end
        fail_map("Expected a tile object or Spawn point: #{object['id']}") unless object['gid']
        tile = tile_for_gid(object['gid'])
        kind = tile_class(object)
        kind = tile_class(tile[:definition]) if kind.nil? || kind.empty?
        fail_map('Spawn must be a point object') if kind == 'Spawn'
        rect = { x: object.fetch('x'), y: @height - object.fetch('y'),
                 w: object.fetch('width'), h: object.fetch('height') }
        sprite = sprite_for(tile, rect, gid: object['gid'],
                                        opacity: layer.fetch('opacity', 1) * object.fetch('opacity', 1))
        props = properties(tile[:definition]).merge(properties(object))
        shapes = collision_shapes(tile, sprite)
        entry = { id: object.fetch('id'), kind: kind, layer: layer['name'], sprite: sprite, properties: props,
                  depth: shapes.map { |shape| shape[:y] }.min || sprite[:y] }
        target = layer['name'] == 'FloorDetails' ? @floor_details : @objects
        target << entry if layer.fetch('visible', true) && object.fetch('visible', true)
        if kind == 'Door'
          fail_map('Door bases belong on Props') unless layer['name'] == 'Props'
          part = door_part(tile, sprite, props)
          closed = local_tile(tile[:tileset], props.fetch('close_tile'))
          opened = local_tile(tile[:tileset], props.fetch('open_tile'))
          @doors << entry.merge(open: tile[:id] == props.fetch('open_tile'), parts: [part],
                                closed_colliders: collision_shapes(closed, part[:closed_sprite]),
                                open_colliders: collision_shapes(opened, part[:open_sprite]))
        else
          @colliders.concat(shapes)
          @lights << light_source(entry, sprite, props) if kind == 'Light'
          @interactables << entry if kind == 'Interactable'
        end
      end
    end

    # A mounted Prop shares its wall's draw group, not its physical position.
    def link_mounted_props
      by_id = @objects.to_h { |entry| [entry[:id], entry] }
      @objects.each do |entry|
        target_id = entry[:properties].fetch('mounted_on', 0)
        next if target_id.is_a?(Integer) && target_id.zero?

        unless target_id.is_a?(Integer) && target_id.positive? && entry[:layer] == 'Props'
          fail_map("Set mounted_on on a Props object to a Walls object reference: #{entry[:id]}")
        end
        wall = by_id[target_id]
        unless wall && wall[:layer] == 'Walls'
          fail_map("mounted_on target #{target_id} for object #{entry[:id]} is not a visible Walls object")
        end
        entry[:mounted_on] = target_id
        entry[:depth] = wall[:depth]
        wall[:mounted_objects] ||= []
        wall[:mounted_objects] << entry
      end
    end

    # Transform local top-left coordinates into world bottom-left coordinates.
    def local_point(sprite, x, y)
      x = sprite[:source_w] - x if sprite[:flip_horizontally]
      y = sprite[:source_h] - y if sprite[:flip_vertically]
      { x: sprite[:x] + (x * sprite[:w].fdiv(sprite[:source_w])),
        y: sprite[:y] + ((sprite[:source_h] - y) * sprite[:h].fdiv(sprite[:source_h])) }
    end

    def collision_shapes(tile, sprite)
      tile[:definition].fetch('objectgroup', {}).fetch('objects', []).map do |shape|
        if %w[polygon polyline ellipse point].any? { |key| shape[key] } || shape.fetch('rotation', 0) != 0
          fail_map("Use rectangle collision shapes on tile #{tile[:id]}")
        end
        unless shape['width'].positive? && shape['height'].positive?
          fail_map('Collision rectangles must have positive dimensions')
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

    def door_part(tile, sprite, props)
      closed = props['close_tile']
      opened = props['open_tile']
      if closed.nil? || opened.nil? || closed == opened
        fail_map("Set distinct close_tile and open_tile on Door tile #{tile[:id]}")
      end
      fail_map("Door tile #{tile[:id]} does not belong to its pair") unless [closed, opened].include?(tile[:id])
      [closed, opened].each do |id|
        variant = local_tile(tile[:tileset], id)
        pair = properties(variant[:definition])
        unless tile_class(variant[:definition]) == 'Door' && pair['close_tile'] == closed && pair['open_tile'] == opened
          fail_map("Inconsistent Door pair #{closed}/#{opened}")
        end
      end
      { sprite: sprite, closed_sprite: door_sprite(tile[:tileset], closed, sprite),
        open_sprite: door_sprite(tile[:tileset], opened, sprite) }
    end

    def door_sprite(tileset, id, sprite)
      # Retain placement, scaling and flips while changing only the atlas crop.
      sprite_for(local_tile(tileset, id), sprite).merge(
        flip_horizontally: sprite[:flip_horizontally], flip_vertically: sprite[:flip_vertically], a: sprite[:a]
      )
    end

    def link_door_caps
      @doors.each do |door|
        sprite = door[:sprite]
        column = sprite[:x].fdiv(@tile_w)
        row = (@height - sprite[:y] - sprite[:h]).fdiv(@tile_h) - 1
        fail_map("Place door #{door[:id]} on the tile grid") unless column == column.to_i && row == row.to_i
        cap = @caps.delete([column.to_i, row.to_i])
        door[:parts] << cap if cap
        door[:parts].each { |part| part[:sprite].replace(part.fetch(door[:open] ? :open_sprite : :closed_sprite)) }
      end
      fail_map('Ceiling Door piece has no base immediately below it') unless @caps.empty?
    end
  end
end
