# frozen_string_literal: true

require 'app/ui'
require 'app/foreground_fade'
require 'app/lighting'

module Descent
  # Consume world-space frame hashes; never read Room, Player, input, or state.
  # Frames contain floor/ceiling sprites, depth-sorted groups, world diagnostic
  # primitives, and screen-space HUD primitives. Camera prepares raster placement.
  module Render
    TARGET = :scene

    class << self
      def draw(args, frame:, camera:, fade_state: nil, tick: 0)
        args.outputs.background_color = UI::COLORS.fetch(:bg)
        if camera
          camera = camera.for_drawing
          lightmap = Lighting.draw_lightmap(args, light_polygons: frame[:light_polygons], camera: camera) if
            frame[:light_polygons]
          target = scene(args, camera)
          viewport = camera.viewport_world
          # Preserve full logical order for fade bases/members omitted by culling.
          order = drawing_order(frame) unless frame.fetch(:fade_units, []).empty?
          groups = frame.fetch(:groups, []).each_with_index.select do |group, _index|
            group[:sprites].any? { |sprite| Geometry.intersect_rect?(sprite, viewport) }
          end
          groups = groups.sort_by { |group, index| [-group[:depth], index] }
          # World Y increases upward: lower feet appear in front. Preserve authored
          # order on ties and keep mounted artwork together inside each group.
          world = frame.fetch(:floor, []) + groups.flat_map { |group, _index| group[:sprites] } +
                  frame.fetch(:ceiling, [])
          world = camera.find_all_intersect_viewport(world)
          faded = ForegroundFade.apply(world,
                                       units: frame.fetch(:fade_units, []), actors: frame.fetch(:fade_actors, []),
                                       viewport: viewport, state: fade_state, tick: tick, draw_order: order)
          if frame[:light_polygons]
            floor_count = camera.find_all_intersect_viewport(frame.fetch(:floor, [])).length
            target.primitives << camera.to_draw_space(faded.take(floor_count))
            target.primitives << lightmap
            colors = Lighting.receiver_colors(light_receivers: frame.fetch(:light_receivers, []),
                                              light_polygons: frame[:light_polygons])
            ambient = [Lighting::AMBIENT] * 3
            foreground = faded.drop(floor_count).each_with_index.map do |sprite, index|
              color = colors.fetch(world[floor_count + index].object_id, ambient)
              Lighting.tint(sprite, color: color)
            end
            target.primitives << camera.to_draw_space(foreground)
          else
            target.primitives << camera.to_draw_space(faded)
          end
          target.lines << frame.fetch(:world_lines, []).map do |line|
            endpoint = camera.to_screen(x: line[:x2], y: line[:y2])
            camera.to_screen_space(line).merge(x2: endpoint[:x], y2: endpoint[:y])
          end
          target.borders << camera.to_screen_space(camera.find_all_intersect_viewport(frame.fetch(:world_borders, [])))
          target.primitives << camera.to_draw_space(camera.find_all_intersect_viewport(frame.fetch(:world_markers, [])))
          args.outputs.primitives << camera.viewport.merge(path: TARGET)
        end
        args.outputs.primitives << frame.fetch(:hud, [])
      end

      private

      # Keys compare in the same order as floor, stable depth groups, ceiling.
      # A repeated sprite reference uses its final occurrence, as the old flat
      # world's object-ID index did. Equal-looking sprites remain independent.
      def drawing_order(frame)
        order = {}
        frame.fetch(:floor, []).each_with_index { |sprite, index| order[sprite.object_id] = [0, index] }
        frame.fetch(:groups, []).each_with_index do |group, index|
          group[:sprites].each_with_index do |sprite, member|
            id = sprite.object_id
            key = [1, -group[:depth], index, member]
            order[id] = key if !order.key?(id) || (key <=> order[id]).positive?
          end
        end
        frame.fetch(:ceiling, []).each_with_index { |sprite, index| order[sprite.object_id] = [2, index] }
        order
      end

      def scene(args, camera)
        target = args.outputs[TARGET]
        target.w = camera.viewport_w
        target.h = camera.viewport_h
        target.background_color = [0, 0, 0, 0]
        target
      end
    end
  end
end
