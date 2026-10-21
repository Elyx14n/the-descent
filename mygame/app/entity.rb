# frozen_string_literal: true

module Descent
  class Entity
    attr_accessor :x, :y, :facing
    attr_reader :sprite, :collider, :scale, :reset_generation

    def initialize(sprite:, collider:, x: 0, y: 0, scale: 1, facing: :south)
      @x = x
      @y = y
      @facing = facing
      @sprite = sprite
      @collider = collider
      @scale = scale
      @reset_generation = 0
    end

    def reset(x:, y:, facing: :south)
      @reset_generation = @reset_generation.to_i + 1
      @x = x
      @y = y
      @facing = facing
      @sprite.reset
    end

    def collision_rect(x: @x, y: @y)
      @collider&.rect(x: x, y: y, scale: @scale)
    end

    def update_animation(animation, variant = nil)
      @sprite.update(animation, variant)
    end

    def sprite_to_primitive(animation: nil, variant: nil, x: @x, y: @y)
      @sprite.to_primitive(x: x, y: y, facing: @facing, scale: @scale,
                           animation: animation, variant: variant)
    end
  end
end
