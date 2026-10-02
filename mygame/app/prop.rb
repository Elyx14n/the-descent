# frozen_string_literal: true

require 'app/descent'
require 'app/entity'
require 'app/sprite'
require 'app/collider'

module Descent
  PROPS = {
    box: {
      scale: 3,
      sprite: {
        path: 'sprites/enemy.png'
      },
      collider: {
        w: 32, h: 32
      }
    }
  }.freeze

  class Prop < Entity
    attr_reader :type

    def initialize(type:, **kwargs)
      @type = type
      super(**kwargs)
    end

    class << self
      def spawn(type:, x:, y:, facing: :south)
        cfg = PROPS.fetch(type)

        new(
          type: type,
          x: x,
          y: y,
          facing: facing,
          scale: cfg.fetch(:scale, 1),
          sprite: Sprite.new(**cfg.fetch(:sprite)),
          collider: Collider.new(**cfg.fetch(:collider))
        )
      end
    end
  end
end
