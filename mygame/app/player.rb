# frozen_string_literal: true

require 'app/descent'
require 'app/actor'

module Descent
  class Player < Actor
    CONFIG = {
      walk_speed: 3.0,
      sneak_speed: 1.5,
      frame_size: 64,
      source_frame_height: 63,
      display_scale: 2,
      frame_count: 4,
      ticks_per_frame: 12,
      facing_rows: { south: 0, west: 1, east: 2, north: 3 }.freeze,
      sprite_base: {
        path: 'sprites/descent/enemy_spritesheet.png',
        w: 64 * 2, h: 63 * 2,
        scale_quality_enum: 0
      }.freeze
    }.freeze

    attr_accessor :sanity, :lamp_on

    def initialize(pos_x = 0, pos_y = 0, sanity = 100)
      super(pos_x, pos_y)
      @sanity = sanity
      @lamp_on = false
    end

    def config
      CONFIG
    end

    def collider_width
      24
    end

    def collider_height
      16
    end

    def toggle_lamp
      @lamp_on = !@lamp_on
    end

    def update(input, walls: [])
      toggle_lamp if input[:toggle_lamp]

      speed = input[:sneak] ? CONFIG[:sneak_speed] : CONFIG[:walk_speed]

      move(
        input[:move_x],
        input[:move_y],
        speed: speed,
        walls: walls
      )
    end

    class << self
      def spawn(pos_x:, pos_y:)
        new(pos_x, pos_y, 100)
      end
    end
  end
end
