# frozen_string_literal: true

require 'app/descent'
require 'app/entity'
require 'app/sprite'
require 'app/collider'
require 'app/tilesheet'

module Descent
  class Prop < Entity
    # Only tuned types need entries. Missing colliders use the full source cell;
    # explicit nil makes a prop decorative.
    PROP_OVERRIDES = {
      closed_stone_coffin: { collider: { w: 24, h: 10 }.freeze }.freeze,
      red_banner: { collider: nil }.freeze
    }.freeze

    attr_reader :id

    def initialize(id:, **kwargs)
      @id = id
      super(**kwargs)
    end

    class << self
      def spawn(id:, x:, y:, facing: :south)
        source_rect = Tilesheet.source_rect(id)
        cfg = PROP_OVERRIDES.fetch(id, {})
        collider = cfg.fetch(:collider) { { w: source_rect[:w], h: source_rect[:h] } }

        new(
          id: id,
          x: x,
          y: y,
          facing: facing,
          scale: cfg.fetch(:scale, 1),
          sprite: Sprite.new(path: Tilesheet::PATH, source_rect: source_rect),
          collider: collider && Collider.new(**collider)
        )
      end
    end
  end
end
