# frozen_string_literal: true

require 'app/descent'
require 'app/actor'

module Descent
  class Enemy < Actor
    CONFIG = {
      frame_size: 64,
      display_scale: 3,
      foot_padding: 6,
      walk_speed: 3.0,
      facing_rows: { north: 3, south: 0, east: 2, west: 1 }.freeze,
      frame_count: 4,
      ticks_per_frame: 12,
      collider_width: 24,
      collider_height: 8,
      animations: {
        walk: { loop: true, path: 'sprites/enemy' }.freeze
      }.freeze
    }.freeze

    def initialize(x = 0, y = 0)
      super(x, y)
    end

    def config
      CONFIG
    end

    def animation
      nil
    end

    def update(walls: [])
      move(
        :dx,
        :dy,
        speed: CONFIG[:walk_speed],
        walls: walls
      )
    end

    def reset(x:, y:)
      # Explicit keyword forwarding is required by DragonRuby's Ruby runtime.
      super(x: x, y: y)
    end

    class << self
      def spawn(x:, y:)
        new(x, y, 100)
      end
    end
  end
end
