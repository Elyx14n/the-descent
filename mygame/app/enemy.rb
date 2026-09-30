# frozen_string_literal: true

require 'app/descent'
require 'app/actor'

module Descent
  class Enemy < Actor
    CONFIG = {
      walk_speed: 3.0,
      frame_size: 64,
      frame_count: 4,
      ticks_per_frame: 12,
      collider_width: 24,
      collider_height: 8,
      facing_rows: { north: 3, south: 0, east: 2, west: 1 }.freeze,
      sprite_paths: {
        walk: 'sprites/enemy.png'
      }.freeze
    }.freeze

    def initialize(x = 0, y = 0)
      super
    end

    def config
      CONFIG
    end

    def update(walls: [])
      move(
        :dx,
        :dy,
        speed: CONFIG[:walk_speed],
        walls: walls
      )
    end

    class << self
      def spawn(x:, y:)
        new(x, y, 100)
      end
    end
  end
end
