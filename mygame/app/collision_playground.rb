# frozen_string_literal: true

require 'app/player'
require 'app/ui'

module Descent
  # Temporary, hand-placed room for tuning movement and the player's ground footprint.
  module CollisionPlayground
    PLAYER_SPAWN = { x: 400, y: 180 }.freeze
    DANGER_DELAY_TICKS = 120
    RESPAWN_DELAY_TICKS = 120 # Two seconds at DragonRuby's 60 ticks per second.

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

    def self.tick(args)
      args.state.playground ||= { show_bounds: true, walls: WALLS.map(&:dup) }
      keyboard = args.inputs.keyboard
      args.state.player ||= Player.spawn(x: PLAYER_SPAWN[:x], y: PLAYER_SPAWN[:y])
      args.state.playground[:show_bounds] = !args.state.playground[:show_bounds] if keyboard.key_down.b
      args.state.player.update(input(keyboard), walls: args.state.playground[:walls])
      check_danger_zones(args)
      args.state.player.update_animation
      render(args)
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
      unless args.geometry.intersect_rect?(player.collider, RED_TILE)
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

    def self.render(args)
      walls = args.state.playground[:walls]
      args.outputs.primitives << RED_TILE
      args.outputs.primitives << walls.map { |wall| UI.box(wall, color: UI::COLORS[:stone]) }
      args.outputs.primitives << args.state.player.sprite
      args.outputs.primitives << labels
      playground = args.state.playground
      countdown_at = playground[:respawn_at] || playground[:danger_death_at]
      if countdown_at
        seconds = ((countdown_at - Kernel.tick_count) / 60.0).ceil
        text = playground[:respawn_at] ? "Respawning in #{seconds}..." : "Leave the red tile! #{seconds}s"
        args.outputs.primitives << UI.label({ x: 640, y: 580 }, text: text)
      end
      return unless args.state.playground[:show_bounds]

      args.outputs.borders << walls.map { |wall| wall.merge(r: 235, g: 185, b: 94) }
      args.outputs.borders << args.state.player.collider.merge(r: 90, g: 255, b: 160)
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
