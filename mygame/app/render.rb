# frozen_string_literal: true

require 'app/ui'
require 'app/foreground_fade'

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
          target = scene(args, camera)
          viewport = camera.viewport_world
          # Preserve full logical order for fade bases/members omitted by culling.
          order = drawing_order(frame) unless frame.fetch(:fade_units, []).empty?
          groups = frame.fetch(:groups, []).each_with_index.select do |group, _index|
            group[:sprites].any? { |sprite| Geometry.intersect_rect?(sprite, viewport) }
          end
          groups = sort_groups(groups, frame[:ordered_group_count])
          # World Y increases upward: lower feet appear in front. Preserve authored
          # order on ties and keep mounted artwork together inside each group.
          world = frame.fetch(:floor, []) + groups.flat_map { |group, _index| group[:sprites] } +
                  frame.fetch(:ceiling, [])
          world = camera.find_all_intersect_viewport(world)
          world = ForegroundFade.apply(world,
                                       units: frame.fetch(:fade_units, []), actors: frame.fetch(:fade_actors, []),
                                       viewport: viewport, state: fade_state, tick: tick, draw_order: order)
          sprites = camera.to_draw_space(world)
          target.primitives << sprites
          target.borders << camera.to_screen_space(camera.find_all_intersect_viewport(frame.fetch(:world_borders, [])))
          target.primitives << camera.to_draw_space(camera.find_all_intersect_viewport(frame.fetch(:world_markers, [])))
          args.outputs.primitives << camera.viewport.merge(path: TARGET)
        end
        args.outputs.primitives << frame.fetch(:hud, [])
      end

      private

      # Room supplies an ordered scenery prefix; appended actors form the tail.
      # Source indices survive culling and keep ties stable in either path.
      def sort_groups(groups, ordered_count)
        return groups.sort_by { |group, index| [-group[:depth], index] } unless ordered_count

        scenery, dynamic = groups.partition { |_group, index| index < ordered_count }
        previous_depth = nil
        scenery.each do |entry|
          depth = entry[0][:depth]
          return groups.sort_by { |group, index| [-group[:depth], index] } if previous_depth && depth > previous_depth

          previous_depth = depth
        end
        return scenery if dynamic.empty?

        dynamic = dynamic.sort_by { |group, index| [-group[:depth], index] }
        return dynamic if scenery.empty?

        result = []
        fixed = 0
        moving = 0
        while fixed < scenery.length && moving < dynamic.length
          if scenery[fixed][0][:depth] >= dynamic[moving][0][:depth]
            result << scenery[fixed]
            fixed += 1
          else
            result << dynamic[moving]
            moving += 1
          end
        end
        result.concat(scenery.drop(fixed)).concat(dynamic.drop(moving))
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
