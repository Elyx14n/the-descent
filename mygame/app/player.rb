# frozen_string_literal: true

require 'app/descent'
require 'app/actor'
require 'app/sprite'
require 'app/collider'

module Descent
  class Player < Actor
    SPRITE_CONFIG = {
      frame_size: 64,
      foot_padding: 24,
      facing_rows: { north: 2, south: 0, east: 3, west: 1 },
      animations: {
        death: { loop: false, path: 'sprites/player_death.png', frame_count: 8, ticks_per_frame: 8 },
        idle: {
          loop: true,
          frame_count: 8,
          ticks_per_frame: 8,
          variants: {
            lamp_on: 'sprites/player_idle_lamp_on.png',
            lamp_off: 'sprites/player_idle_lamp_off.png'
          }
        },
        walk: {
          loop: true,
          frame_count: 8,
          ticks_per_frame: 8,
          variants: {
            lamp_on: 'sprites/player_walk_lamp_on.png',
            lamp_off: 'sprites/player_walk_lamp_off.png'
          }
        }
      }
    }.freeze
    COLLIDER_CONFIG = { w: 8, h: 2 }.freeze

    SNEAK_SPEED = 1.5
    WALK_SPEED = 3.0

    attr_accessor :sanity, :lamp_on

    def initialize(x: 0, y: 0, scale: 3, sanity: 100)
      super(x: x, y: y, scale: scale, sprite: Sprite.new(**SPRITE_CONFIG),
            collider: Collider.new(**COLLIDER_CONFIG))
      @sanity = sanity
      @lamp_on = true
    end

    def animation
      if @sanity <= 0
        :death
      elsif moving?
        :walk
      else
        :idle
      end
    end

    def animation_variant
      case animation
      when :idle, :walk
        @lamp_on ? :lamp_on : :lamp_off
      end
    end

    def toggle_lamp
      @lamp_on = !@lamp_on
    end

    def update_controls(input, walls: [])
      if @sanity <= 0
        @moving = false
        return
      end

      toggle_lamp if input[:toggle_lamp]

      speed = input[:sneak] ? SNEAK_SPEED : WALK_SPEED

      move(
        input[:dx],
        input[:dy],
        speed: speed,
        walls: walls
      )
    end

    def reset(x:, y:, facing: :south)
      # Explicit keyword forwarding is required by DragonRuby's Ruby runtime.
      super(x: x, y: y, facing: facing)
      @sanity = 100
      @lamp_on = true
    end
  end
end
