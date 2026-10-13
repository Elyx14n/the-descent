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
          target = scene(args, camera)
          groups = frame.fetch(:groups, []).each_with_index.sort_by { |group, index| [-group[:depth], index] }
          # World Y increases upward: lower feet appear in front. Preserve authored
          # order on ties and keep mounted artwork together inside each group.
          world = frame.fetch(:floor, []) + groups.flat_map { |group, _index| group[:sprites] } +
                  frame.fetch(:ceiling, [])
          world = ForegroundFade.apply(world,
                                       units: frame.fetch(:fade_units, []), actors: frame.fetch(:fade_actors, []),
                                       viewport: camera.viewport_world, state: fade_state, tick: tick)
          sprites = camera.to_draw_space(camera.find_all_intersect_viewport(world))
          target.primitives << sprites
          target.borders << camera.to_screen_space(camera.find_all_intersect_viewport(frame.fetch(:world_borders, [])))
          target.primitives << camera.to_draw_space(camera.find_all_intersect_viewport(frame.fetch(:world_markers, [])))
          args.outputs.primitives << camera.viewport.merge(path: TARGET)
        end
        args.outputs.primitives << frame.fetch(:hud, [])
      end

      private

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
