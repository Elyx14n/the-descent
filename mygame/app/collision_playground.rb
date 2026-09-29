# frozen_string_literal: true

require 'app/player'
require 'app/ui'

module Descent
  # Temporary, hand-placed room for tuning movement and the player's ground footprint.
  module CollisionPlayground
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

    def self.tick(args)
      args.state.playground ||= { show_bounds: true, walls: WALLS.map(&:dup) }
      keyboard = args.inputs.keyboard
      args.state.player = Player.spawn(pos_x: 180, pos_y: 180) if keyboard.key_down.r
      args.state.player ||= Player.spawn(pos_x: 180, pos_y: 180)
      args.state.playground[:show_bounds] = !args.state.playground[:show_bounds] if keyboard.key_down.b
      args.state.player.update(input(keyboard), walls: args.state.playground[:walls])
      render(args)
    end

    def self.input(keyboard)
      { move_x: keyboard.left_right, move_y: keyboard.up_down,
        sneak: keyboard.shift, toggle_lamp: keyboard.key_down.f }
    end

    def self.render(args)
      walls = args.state.playground[:walls]
      args.outputs.primitives << walls.map { |wall| UI.box(wall, color: UI::COLORS[:stone]) }
      args.outputs.primitives << args.state.player.sprite
      args.outputs.primitives << labels
      return unless args.state.playground[:show_bounds]

      args.outputs.borders << walls.map { |wall| wall.merge(r: 235, g: 185, b: 94) }
      args.outputs.borders << args.state.player.collider.merge(r: 90, g: 255, b: 160)
    end

    def self.labels
      [UI.label({ x: 640, y: 688 }, text: 'Collision playground', size_px: 30),
       UI.label({ x: 640, y: 650 }, text: 'WASD / arrows: move    Shift: sneak    B: boxes    R: respawn'),
       UI.label({ x: 560, y: 472 }, text: 'Slide along the corner', size_px: 18),
       UI.label({ x: 936, y: 400 }, text: '32 px doorway', size_px: 18),
       UI.label({ x: 640, y: 38 }, text: 'Green box = feet (24 x 16). The robe can overlap walls.', size_px: 18)]
    end
  end
end
