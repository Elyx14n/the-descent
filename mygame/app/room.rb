# frozen_string_literal: true

require 'app/descent'

module Descent
  class Room
    FACING_TO_ROTATION = {
      north: 0,
      east: 90,
      south: 180,
      west: 270
    }.freeze

    attr_reader :id, :w, :h, :exits, :walls, :props, :rotation

    def initialize(id:, w:, h:, exits:, walls: nil, props: nil, facing: :south)
      @id = id
      @w = w
      @h = h
      @exits = exits
      @walls = walls
      @props = props
      @rotation = FACING_TO_ROTATION.fetch(facing, 180)
    end
  end
end
