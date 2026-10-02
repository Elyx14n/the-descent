# frozen_string_literal: true

require 'app/descent'

module Descent
  class Entity
    attr_accessor :x, :y, :facing
    attr_reader :sprite, :collider, :scale

    def initialize(sprite:, collider:, x: 0, y: 0, scale: 1, facing: :south)
      @x = x
      @y = y
      @facing = facing
      @sprite = sprite
      @collider = collider
      @scale = scale
    end

    def reset(x:, y:, facing: :south)
      @x = x
      @y = y
      @facing = facing
      @sprite.reset
    end

    def collision_rect
      @collider&.rect(x: @x, y: @y, scale: @scale)
    end

    def update_animation(animation, variant = nil)
      @sprite.update(animation, variant)
    end

    def sprite_to_primitive(animation: nil, variant: nil)
      @sprite.to_primitive(x: @x, y: @y, facing: @facing, scale: @scale,
                           animation: animation, variant: variant)
    end
  end
end
