# frozen_string_literal: true

require 'app/descent'
require 'app/actor'
require 'app/sprite'
require 'app/collider'

module Descent
  class Enemy < Actor
    SPRITE_CONFIG = {
      frame_size: 64,
      foot_padding: 6,
      facing_rows: { north: 3, south: 0, east: 2, west: 1 }.freeze,
      animations: {
        walk: { loop: true, path: 'sprites/enemy.png', frame_count: 4, ticks_per_frame: 12 }.freeze
      }.freeze
    }.freeze
    COLLIDER_CONFIG = { w: 24, h: 8 }.freeze
    WALK_SPEED = 3.0

    def initialize(x: 0, y: 0, scale: 3)
      super(x: x, y: y, scale: scale, sprite: Sprite.new(**SPRITE_CONFIG),
            collider: Collider.new(**COLLIDER_CONFIG))
    end

    def animation
      :walk
    end

    def update(dx: 0, dy: 0, walls: [])
      move(
        dx,
        dy,
        speed: WALK_SPEED,
        walls: walls
      )
    end
  end
end
