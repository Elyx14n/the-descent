# frozen_string_literal: true

require 'app/player'
require 'app/prop'
require 'app/ui'

module Descent
  # Temporary, hand-placed room for tuning movement and the player's ground footprint.
  module CollisionPlayground
    PLAYER_SPAWN = { x: 400, y: 180, facing: :south }.freeze
    DANGER_DELAY_TICKS = 120
    RESPAWN_DELAY_TICKS = 120 # Two seconds at DragonRuby's 60 ticks per second.

    # Change these types/positions and save to try any name in Tilesheet::TILES.
    PROP_PLACEMENTS = [
      { type: :closed_stone_coffin, x: 650, y: 290 },
      { type: :red_banner, x: 1080, y: 475 }
    ].map(&:freeze).freeze

    WALLS = [
      { x: 64, y: 80, w: 1152, h: 24 },
      { x: 64, y: 600, w: 1152, h: 24 },
      { x: 64, y: 104, w: 24, h: 496 },
      { x: 1192, y: 104, w: 24, h: 496 },
      { x: 480, y: 200, w: 24, h: 240 },
      { x: 504, y: 200, w: 160, h: 24 },
      { x: 760, y: 340, w: 160, h: 24 },
      { x: 952, y: 340, w: 240, h: 24 }
    ].map(&:freeze).freeze

    RED_TILE = {
      x: 88,
      y: 104,
      w: 256,
      h: 256,
      r: 220, g: 50, b: 50,
      path: :solid
    }.freeze

    def self.tick(args, tick_count: Kernel.tick_count)
      args.state.playground ||= { show_bounds: true, walls: WALLS.map(&:dup) }
      playground = args.state.playground
      refresh_props(playground)
      prop_colliders = playground[:props].map(&:collision_rect).compact
      keyboard = args.inputs.keyboard
      args.state.player ||= Player.new(x: PLAYER_SPAWN[:x], y: PLAYER_SPAWN[:y])
      playground[:show_bounds] = !playground[:show_bounds] if keyboard.key_down.b
      args.state.player.update_controls(input(keyboard), walls: playground[:walls] + prop_colliders)
      check_danger_zones(args, tick_count: tick_count)
      args.state.player.update_animation
      render(args, prop_colliders: prop_colliders, tick_count: tick_count)
    end

    def self.refresh_props(playground)
      # Hot reload replaces these frozen constants. Existing component instances
      # retain old values, so rebuild props before both collision and rendering.
      sources = [PROP_PLACEMENTS, PROP_OVERRIDES, Tilesheet::TILES]
      previous = playground[:prop_sources]
      return if previous && sources.each_with_index.all? { |source, i| source.equal?(previous[i]) }

      playground[:props] = PROP_PLACEMENTS.map { |placement| Prop.spawn(**placement) }
      playground[:prop_sources] = sources
    end

    def self.check_danger_zones(args, tick_count: Kernel.tick_count)
      player = args.state.player
      playground = args.state.playground
      update_danger_countdown(args, tick_count: tick_count) if player.sanity.positive?
      return unless player.sanity <= 0

      playground[:danger_death_at] = nil
      playground[:respawn_at] ||= tick_count + RESPAWN_DELAY_TICKS
      return if tick_count < playground[:respawn_at]

      player.reset(**PLAYER_SPAWN)
      playground[:respawn_at] = nil
    end

    def self.update_danger_countdown(args, tick_count:)
      player = args.state.player
      playground = args.state.playground
      unless args.geometry.intersect_rect?(player.collision_rect, RED_TILE)
        playground[:danger_death_at] = nil
        return
      end

      playground[:danger_death_at] ||= tick_count + DANGER_DELAY_TICKS
      player.sanity = 0 if tick_count >= playground[:danger_death_at]
    end

    def self.input(keyboard)
      { dx: keyboard.left_right, dy: keyboard.up_down,
        sneak: keyboard.shift, toggle_lamp: keyboard.key_down.f }
    end

    def self.render(args, prop_colliders:, tick_count: Kernel.tick_count)
      walls = args.state.playground[:walls]
      args.outputs.primitives << RED_TILE
      args.outputs.primitives << walls.map { |wall| UI.box(wall, color: UI::COLORS[:stone]) }
      entities = args.state.playground[:props] + [args.state.player]
      args.outputs.primitives << entities.sort_by { |entity| -entity.y }.map(&:sprite_to_primitive)
      args.outputs.primitives << labels
      render_countdown(args, tick_count)
      return unless args.state.playground[:show_bounds]

      args.outputs.borders << walls.map { |wall| wall.merge(r: 235, g: 185, b: 94) }
      args.outputs.borders << prop_colliders.map { |rect| rect.merge(r: 100, g: 180, b: 255) }
      args.outputs.borders << args.state.player.collision_rect.merge(r: 90, g: 255, b: 160)
    end

    def self.render_countdown(args, tick_count)
      playground = args.state.playground
      countdown_at = playground[:respawn_at] || playground[:danger_death_at]
      return unless countdown_at

      seconds = ((countdown_at - tick_count) / 60.0).ceil
      text = playground[:respawn_at] ? "Respawning in #{seconds}..." : "Leave the red tile! #{seconds}s"
      args.outputs.primitives << UI.label({ x: 640, y: 580 }, text: text)
    end

    def self.labels
      [UI.label({ x: 640, y: 688 }, text: 'Collision playground', size_px: 30),
       UI.label({ x: 640, y: 650 }, text: 'WASD / arrows: move    Shift: sneak    F: lamp    B: boxes'),
       UI.label({ x: 560, y: 472 }, text: 'Slide along the corner', size_px: 18),
       UI.label({ x: 936, y: 400 }, text: '32 px doorway', size_px: 18),
       UI.label({ x: 88 + 128, y: 256 }, text: '2 seconds here = death', size_px: 20)]
    end
  end
end
