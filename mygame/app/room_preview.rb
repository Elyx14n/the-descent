# frozen_string_literal: true

require 'app/tiled_deserializer'
require 'app/room'
require 'app/camera'
require 'app/player'
require 'app/keybinds'
require 'app/render'

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
          args.gtk.parse_json(contents), path: state[:path], image_loader: ->(image) { args.gtk.get_pixels(image) }
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
        end
        frame[:world_borders] = []
        frame[:world_markers] = []
        add_diagnostics(frame, state) if state[:room] && state[:show_bounds]
        frame[:hud] = [UI.label({ x: Grid.w.fdiv(2), y: Grid.h - 8 }, text: Keybinds.help_text)]
        if state[:reload_error]
          message = "Reload: #{state[:reload_error].lines.first.to_s.strip}"
          message = "#{message[0, 72]}..." if message.length > 75
          frame[:hud] << UI.label({ x: Grid.w.fdiv(2), y: Grid.h - 20 }, text: message, color: UI::COLORS[:accent])
        end
        Render.draw(args, frame: frame, camera: state[:camera], fade_state: state[:fade_state] ||= {},
                          tick: args.state.tick_count)
      end

      private

      def add_diagnostics(frame, state)
        frame[:world_borders] = state[:room].collision_rects.map { |rect| rect.merge(r: 235, g: 185, b: 94) }
        frame[:world_borders] << state[:player].collision_rect.merge(r: 90, g: 255, b: 160)
        frame[:world_borders].concat(state[:room].fade_units.map do |unit|
          unit[:footprint].merge(r: 100, g: 160, b: 255)
        end)
        state[:room].fade_units.flat_map { |unit| unit[:sprites] }.uniq.each do |sprite|
          rect = ForegroundFade.alpha_bounds(sprite)
          frame[:world_borders] << rect.merge(r: 220, g: 100, b: 220) if rect
        end
        frame[:world_markers] = state[:room].lights.map do |light|
          { x: light[:x] - 1, y: light[:y] - 1, w: 2, h: 2, path: :solid, r: 0, g: 255, b: 0 }
        end
        frame[:world_borders] << {
          x: state[:room].spawn[:x] - 8,
          y: state[:room].spawn[:y] - 8,
          w: 16,
          h: 16,
          r: 255,
          g: 255,
          b: 255
        }
      end
    end
  end
end
