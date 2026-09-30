# frozen_string_literal: true

require 'app/descent'
require 'app/actor'

module Descent
  class Player < Actor
    CONFIG = {
      frame_size: 32,
      display_scale: 3,
      foot_padding: 3,
      walk_speed: 3.0,
      sneak_speed: 1.5,
      facing_rows: { north: 2, south: 0, east: 3, west: 1 }.freeze,
      frame_count: 8,
      ticks_per_frame: 8,
      collider_width: 8,
      collider_height: 2,
      animations: {
        death: { loop: false, path: 'sprites/player_death.png' }.freeze,
        idle: {
          loop: true,
          variants: {
            lamp_on: 'sprites/player_idle_lamp_on.png',
            lamp_off: 'sprites/player_idle_lamp_off.png'
          }.freeze
        }.freeze,
        walk: {
          loop: true,
          variants: {
            lamp_on: 'sprites/player_walk_lamp_on.png',
            lamp_off: 'sprites/player_walk_lamp_off.png'
          }.freeze
        }.freeze
      }.freeze
    }.freeze

    attr_accessor :sanity, :lamp_on

    def initialize(x = 0, y = 0, sanity = 100)
      super(x, y)
      @sanity = sanity
      @lamp_on = true
    end

    def config
      CONFIG
    end

    def animation
      return :death if @sanity <= 0

      @moving ? :walk : :idle
    end

    def animation_variant
      @lamp_on ? :lamp_on : :lamp_off
    end

    def toggle_lamp
      @lamp_on = !@lamp_on
    end

    def update(input, walls: [])
      if @sanity <= 0
        @moving = false
        return
      end

      toggle_lamp if input[:toggle_lamp]

      speed = input[:sneak] ? CONFIG[:sneak_speed] : CONFIG[:walk_speed]

      move(
        input[:dx],
        input[:dy],
        speed: speed,
        walls: walls
      )
    end

    def reset(x:, y:)
      # Explicit keyword forwarding is required by DragonRuby's Ruby runtime.
      super(x: x, y: y)
      @sanity = 100
      @lamp_on = true
    end

    class << self
      def spawn(x:, y:)
        new(x, y, 100)
      end
    end
  end
end
