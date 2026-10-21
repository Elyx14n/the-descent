# frozen_string_literal: true

require 'app/tiled_deserializer'
require 'app/room'
require 'app/camera'
require 'app/player'
require 'app/keybinds'
require 'app/render'
require 'app/lighting'
require 'app/simulation_clock'

module Descent
  # One-room authoring consumer. Owns preview lifetime, not game rules or drawing.
  # Preview another export with: bin/rake run tiled/other_room.json
  module RoomPreview
    MAP_PATH = 'tiled/ritual_gate.json'
    RELOAD_INTERVAL_US = 500_000

    class << self
      def tick(args, path: MAP_PATH, now_us: nil)
        sampled_us = now_us || SimulationClock.read_us
        args.state.room_preview ||= { show_bounds: false }
        state = args.state.room_preview
        state[:clock] ||= SimulationClock.new(now_us: sampled_us)
        state[:pending_actions] ||= []
        actions = Keybinds.read(args.inputs.keyboard)
        force = actions[:preview][:reload] || state[:path] != path
        state[:path] = path
        rebuilt = false
        if force || state[:next_check].nil? || (!args.gtk.production? && sampled_us >= state[:next_check])
          rebuilt = reload(args, force: force, now_us: now_us)
        end
        state[:show_bounds] = !state[:show_bounds] if actions[:preview][:toggle_bounds]
        # Loading time is excluded, including the remainder of this callback.
        steps = rebuilt ? 0 : state[:clock].advance(now_us: sampled_us)
        if state[:clock].discontinuity
          state[:pending_actions].clear
          state[:next_check] = state[:clock].now_us + RELOAD_INTERVAL_US
          collapse_positions(state) if state[:player]
        end
        player_actions = actions[:player]
        if !rebuilt && (player_actions[:interact] || player_actions[:toggle_lamp])
          state[:pending_actions] << player_actions.slice(:interact, :toggle_lamp)
        end
        synchronize_positions(state) if state[:player]
        steps.times { simulate(state, player_actions) } if state[:room]
        render(args)
      end

      def reload(args, force: true, now_us: nil)
        state = args.state.room_preview
        state[:path] ||= MAP_PATH
        state[:next_check] = (now_us || SimulationClock.read_us) + RELOAD_INTERVAL_US
        contents = args.gtk.read_file(state[:path])
        return if !force && state.key?(:source) && contents == state[:source]

        # Remember failed exports too, avoiding repeated parsing of the same error.
        # R forces another attempt; any new contents trigger automatic recovery.
        state[:source] = contents
        raise ArgumentError, "#{state[:path]}: Cannot read Tiled map" unless contents

        decoded = TiledDeserializer.deserialize(
          args.gtk.parse_json(contents), path: state[:path]
        )
        room = Room.new(**decoded)
        player = Player.new
        player.reset(**room.spawn)
        camera = Camera.new(x: player.x, y: player.y)
        state.merge!(room: room, player: player, camera: camera, fade_state: {}, room_lighting: nil, reload_error: nil)
        # Retain the session simulation tick, but discard time spent loading.
        reset_us = now_us || SimulationClock.read_us
        state[:clock] ||= SimulationClock.new(now_us: reset_us)
        state[:clock].reset(now_us: reset_us)
        state[:pending_actions] = []
        collapse_positions(state)
        room.update_animations(tick: state[:clock].tick)
        true
      rescue StandardError => e
        # Only rebuilding is guarded. Gameplay/rendering errors still surface normally.
        state[:reload_error] = e.message
        false
      end

      def render(args)
        state = args.state.room_preview
        frame = state[:room] ? state[:room].render_data : { floor: [], groups: [], ceiling: [] }
        camera = state[:camera]
        if state[:room]
          synchronize_positions(state)
          position = presentation_position(state)
          actor = state[:player].render_data(**position)
          frame[:groups] << actor
          frame[:fade_actors] = [actor[:fade_actor]]
          frame[:light_receivers] << { sprite: actor[:sprites].first,
                                       bases: [state[:player].collision_rect(**position)] }
          lamp = state[:player].light_source(**position)
          frame[:light_sources] << lamp if lamp
          if position[:x] != state[:player].x || position[:y] != state[:player].y
            # The published rounding method accepts simulation velocity. Use
            # this step's displacement rather than noisy interpolated deltas.
            previous = state[:previous_position]
            current = state[:current_position]
            velocity = { x: current[:x] - previous[:x], y: current[:y] - previous[:y] }
            camera = camera.for_presentation(**position, velocity: velocity)
          end
        end
        frame[:light_polygons] = prepare_lighting(frame, state)
        frame[:world_borders] = []
        frame[:world_markers] = []
        frame[:hud] = [UI.label({ x: Grid.w.fdiv(2), y: Grid.h - 8 }, text: Keybinds.help_text)]
        # Keep changing text widths on whole pixels; centered odd widths land between pixels.
        frame[:hud] << UI.label({ x: Grid.w - 4, y: Grid.h - 4 },
                                text: "FPS: #{args.gtk.current_framerate.to_sf}", anchor_x: 1, anchor_y: 1)
        add_diagnostics(frame, state, position: position) if state[:room] && state[:show_bounds]
        if state[:reload_error]
          message = "Reload: #{state[:reload_error].lines.first.to_s.strip}"
          message = "#{message[0, 72]}..." if message.length > 75
          frame[:hud] << UI.label({ x: Grid.w.fdiv(2), y: Grid.h - 20 }, text: message, color: UI::COLORS[:accent])
        end
        Render.draw(args, frame: frame, camera: camera, fade_state: state[:fade_state] ||= {},
                          tick: state[:clock]&.presentation_tick || 0, compose_scroll: true)
        frame
      end

      private

      def simulate(state, actions)
        player = state[:player]
        state[:previous_position] = state[:current_position]
        state[:clock].step
        state[:room].update_animations(tick: state[:clock].tick)
        events = state[:pending_actions].shift || {}
        player.update(actions.merge(interact: false, toggle_lamp: false).merge(events), room: state[:room])
        state[:current_position] = { x: player.x, y: player.y }
        state[:camera].follow(x: player.x, y: player.y)
      end

      def collapse_positions(state)
        player = state[:player]
        state[:camera]&.reset_scroll
        state[:current_position] = { x: player.x, y: player.y }
        state[:previous_position] = state[:current_position]
        state[:position_generation] = [player.object_id, player.reset_generation]
      end

      # Direct editor/test position changes and reset/respawn are teleports.
      def synchronize_positions(state)
        player = state[:player]
        current = state[:current_position]
        if !current || current[:x] != player.x || current[:y] != player.y ||
           state[:position_generation] != [player.object_id, player.reset_generation]
          collapse_positions(state)
        end
      end

      def presentation_position(state)
        previous = state[:previous_position]
        current = state[:current_position]
        alpha = state[:clock]&.alpha || 0
        { x: previous[:x] + ((current[:x] - previous[:x]) * alpha),
          y: previous[:y] + ((current[:y] - previous[:y]) * alpha) }
      end

      def prepare_lighting(frame, state)
        room_sources, moving_sources = frame.fetch(:light_sources, []).partition { |source| source[:id] != :player }
        blockers = frame.fetch(:light_blockers, [])
        # Compare physical inputs only: animation, fading, and the camera do not
        # change fixed lights. Door geometry and source changes invalidate together.
        geometry = blockers.map { |blocker| [blocker[:owner_ids], blocker[:bounds]] }
        settings = [Lighting::DEFAULT_RADIUS, Lighting::CIRCLE_SEGMENTS]
        cached = state[:room_lighting]
        unless cached && cached[:sources] == room_sources && cached[:geometry] == geometry &&
               cached[:settings] == settings
          cached = { sources: room_sources, geometry: geometry, settings: settings,
                     polygons: Lighting.prepare(light_sources: room_sources, light_blockers: blockers) }
          state[:room_lighting] = cached
        end
        cached[:polygons] + Lighting.prepare(light_sources: moving_sources, light_blockers: blockers)
      end

      def add_diagnostics(frame, state, position:)
        frame[:world_borders] = state[:room].collision_rects.map { |rect| rect.merge(r: 235, g: 185, b: 94) }
        frame[:world_borders] << state[:player].collision_rect(**position).merge(r: 90, g: 255, b: 160)
        frame[:world_borders] << {
          x: state[:room].spawn[:x] - 8,
          y: state[:room].spawn[:y] - 8,
          w: 16,
          h: 16,
          r: 255,
          g: 255,
          b: 255
        }
        frame[:world_markers] = frame[:light_sources].map do |light|
          { x: light[:x] - 2, y: light[:y] - 2, w: 4, h: 4, path: :solid, r: 0, g: 255, b: 0 }
        end
        player_polygon = frame[:light_polygons].select { |light| light[:source][:id] == :player }
        frame[:world_lines] = Lighting.polygon_lines(light_polygons: player_polygon)
      end
    end
  end
end
