# frozen_string_literal: true

require 'app/tiled_deserializer'
require 'app/room'
require 'app/camera'
require 'app/player'
require 'app/keybinds'
require 'app/render'
require 'app/sprite_geometry'
require 'app/raycasting'

module Descent
  # One-room authoring consumer. Owns preview lifetime, not game rules or drawing.
  # Preview another export with: bin/rake run tiled/other_room.json
  module RoomPreview
    MAP_PATH = 'tiled/ritual_gate.json'
    RELOAD_INTERVAL = 30

    class << self
      def tick(args, path: MAP_PATH)
        args.state.room_preview ||= { show_bounds: false }
        state = args.state.room_preview
        actions = Keybinds.read(args.inputs.keyboard)
        force = actions[:preview][:reload] || state[:path] != path
        state[:path] = path
        if force || state[:next_check].nil? || (!args.gtk.production? && args.state.tick_count >= state[:next_check])
          reload(args, force: force)
        end
        state[:show_bounds] = !state[:show_bounds] if actions[:preview][:toggle_bounds]
        if state[:room]
          state[:room].update_animations(tick: args.state.tick_count)
          player = state[:player]
          player.update(actions[:player], room: state[:room])
          state[:camera].follow(x: player.x, y: player.y)
        end
        render(args)
      end

      def reload(args, force: true)
        state = args.state.room_preview
        state[:path] ||= MAP_PATH
        state[:next_check] = args.state.tick_count + RELOAD_INTERVAL
        contents = args.gtk.read_file(state[:path])
        return if !force && state.key?(:source) && contents == state[:source]

        # Remember failed exports too, avoiding repeated parsing of the same error.
        # R forces another attempt; any new contents trigger automatic recovery.
        state[:source] = contents
        raise ArgumentError, "#{state[:path]}: Cannot read Tiled map" unless contents

        decoded = TiledDeserializer.deserialize(
          args.gtk.parse_json(contents), path: state[:path], occluders: Descent::OccluderData.load(args.gtk)
        )
        room = Room.new(**decoded)
        player = Player.new
        player.reset(**room.spawn)
        camera = Camera.new(bounds: room.bounds)
        state.merge!(room: room, player: player, camera: camera, fade_state: {}, reload_error: nil)
      rescue StandardError => e
        # Only rebuilding is guarded. Gameplay/rendering errors still surface normally.
        state[:reload_error] = e.message
      end

      def render(args)
        state = args.state.room_preview
        frame = state[:room] ? state[:room].render_data : { floor: [], groups: [], ceiling: [] }
        if state[:room]
          actor = state[:player].render_data
          frame[:groups] << actor
          frame[:fade_actors] = [actor[:fade_actor]]
          lamp = state[:player].light_source
          frame[:light_sources] << lamp if lamp
        end
        frame[:world_borders] = []
        frame[:world_markers] = []
        frame[:hud] = [UI.label({ x: Grid.w.fdiv(2), y: Grid.h - 8 }, text: Keybinds.help_text)]
        add_diagnostics(frame, state, args) if state[:room] && state[:show_bounds]
        if state[:reload_error]
          message = "Reload: #{state[:reload_error].lines.first.to_s.strip}"
          message = "#{message[0, 72]}..." if message.length > 75
          frame[:hud] << UI.label({ x: Grid.w.fdiv(2), y: Grid.h - 20 }, text: message, color: UI::COLORS[:accent])
        end
        Render.draw(args, frame: frame, camera: state[:camera], fade_state: state[:fade_state] ||= {},
                          tick: args.state.tick_count)
      end

      private

      def add_diagnostics(frame, state, args)
        viewport = state[:camera].for_drawing.viewport_world
        frame[:hud] << UI.label({ x: Grid.w - 16, y: Grid.h - 8 }, text: "FPS: #{args.gtk.current_framerate.to_sf}")
        frame[:world_borders] = state[:room].collision_rects.map { |rect| rect.merge(r: 235, g: 185, b: 94) }
        frame[:world_borders] << state[:player].collision_rect.merge(r: 90, g: 255, b: 160)
        frame[:world_borders] << {
          x: state[:room].spawn[:x] - 8,
          y: state[:room].spawn[:y] - 8,
          w: 16,
          h: 16,
          r: 255,
          g: 255,
          b: 255
        }
        visible = frame[:light_blockers].select { |blocker| Geometry.intersect_rect?(blocker[:sprite], viewport) }
        frame[:world_markers] = frame[:light_sources].map do |light|
          { x: light[:x] - 2, y: light[:y] - 2, w: 4, h: 4, path: :solid, r: 0, g: 255, b: 0 }
        end
        frame[:world_lines] = visible.flat_map do |blocker|
          blocker[:edges].map { |edge| edge.merge(r: 220, g: 100, b: 220) }
        end
        lamp = frame[:light_sources].find { |light| light[:id] == :player }
        add_lamp_sight_polygon(frame, lamp) if lamp
      end

      def add_lamp_sight_polygon(frame, lamp)
        x = lamp[:x]
        y = lamp[:y]
        radius = lamp[:radius]

        corners = [
          { x: x - radius, y: y - radius }, # bottom left
          { x: x + radius, y: y - radius }, # bottom right
          { x: x + radius, y: y + radius }, # top right
          { x: x - radius, y: y + radius }  # top left
        ]
        lamp_radius_segments = corners.each_with_index.map do |point, index|
          {
            a: point,
            b: corners[(index + 1) % corners.length]
          }
        end
        # Keep offscreen blockers when they overlap the lamp's range.
        light_bounds = { x: x - radius, y: y - radius, w: radius * 2, h: radius * 2 }
        blockers = frame[:light_blockers].select do |blocker|
          Geometry.intersect_rect?(blocker[:sprite], light_bounds)
        end
        segments = blockers.flat_map do |blocker|
          blocker[:edges].map do |edge|
            {
              a: { x: edge[:x], y: edge[:y] },
              b: { x: edge[:x2], y: edge[:y2] }
            }
          end
        end
        segments.concat(lamp_radius_segments)
        sight_polygon = Raycasting.get_sight_polygon(x, y, segments: segments)
        sight_polygon_lines = sight_polygon.each_with_index.map do |point, index|
          following = sight_polygon[(index + 1) % sight_polygon.length]
          { x: point[:x], y: point[:y], x2: following[:x], y2: following[:y], r: 255, g: 0, b: 0 }
        end
        frame[:world_lines].concat(sight_polygon_lines)
      end
    end
  end
end
