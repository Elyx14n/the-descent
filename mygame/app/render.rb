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
      def draw(args, frame:, camera:, fade_state: nil, tick: 0, compose_scroll: false)
        args.outputs.background_color = UI::COLORS.fetch(:bg)
        if camera
          presentation_camera = camera.for_drawing(snap: false)
          camera = compose_scroll ? camera.for_compositing : presentation_camera
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
          actors = frame.fetch(:fade_actors, [])
          actor_indices = world.each_index.select do |index|
            actors.any? { |actor| actor[:sprite].equal?(world[index]) }
          end
          placed = place_artwork(faded, actor_indices: actor_indices, camera: camera)
          if frame[:light_polygons]
            floor_count = camera.find_all_intersect_viewport(frame.fetch(:floor, [])).length
            colors = Lighting.receiver_colors(light_receivers: frame.fetch(:light_receivers, []),
                                              light_polygons: frame[:light_polygons])
            ambient = [Lighting::AMBIENT] * 3
            foreground = placed.drop(floor_count).each_with_index.map do |sprite, index|
              color = colors.fetch(world[floor_count + index].object_id, ambient)
              Lighting.tint(sprite, color: color)
            end
            placed = placed.take(floor_count) + [lightmap] + foreground
            actor_indices = actor_indices.map { |index| index < floor_count ? index : index + 1 }
          end
          if compose_scroll
            target = composite_artwork(args, placed, actor_indices: actor_indices, camera: camera,
                                                     presentation_camera: presentation_camera, target: target)
          else
            target.primitives << placed
            args.outputs.primitives << camera.viewport.merge(path: TARGET)
          end
          target.lines << frame.fetch(:world_lines, []).map do |line|
            endpoint = camera.to_screen(x: line[:x2], y: line[:y2])
            camera.to_screen_space(line).merge(x2: endpoint[:x], y2: endpoint[:y])
          end
          target.borders << camera.to_screen_space(camera.find_all_intersect_viewport(frame.fetch(:world_borders, [])))
          target.primitives << camera.to_draw_space(camera.find_all_intersect_viewport(frame.fetch(:world_markers, [])))
        end
        args.outputs.primitives << frame.fetch(:hud, [])
      end

      private

      def place_artwork(artwork, actor_indices:, camera:)
        return camera.to_draw_space(artwork) if actor_indices.empty?

        artwork.each_with_index.map do |sprite, index|
          actor_indices.include?(index) ? camera.to_screen_space(sprite) : camera.to_draw_space(sprite)
        end
      end

      def composite_artwork(args, artwork, actor_indices:, camera:, presentation_camera:, target:)
        destination = presentation_camera.to_screen_space(camera.viewport_world)
        name = TARGET
        start = 0
        actor_indices.each_with_index do |index, sequence|
          target.primitives << artwork[start...index]
          args.outputs.primitives << destination.merge(path: name)
          # Draw each actor once between its surrounding scenery, preserving
          # depth without filtering it through a fractionally shifted texture.
          actor = artwork[index]
          args.outputs.primitives << actor.merge(x: actor[:x] + destination[:x], y: actor[:y] + destination[:y])
          name = :"scene_after_actor#{sequence + 1}"
          target = scene(args, camera, name: name)
          start = index + 1
        end
        target.primitives << artwork.drop(start)
        args.outputs.primitives << destination.merge(path: name)
        target
      end

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

      def scene(args, camera, name: TARGET)
        target = args.outputs[name]
        target.w = camera.viewport_w
        target.h = camera.viewport_h
        target.background_color = [0, 0, 0, 0]
        target
      end
    end
  end
end
