# frozen_string_literal: true

module Descent
  class Room
    attr_reader :id, :w, :h, :exits, :walls, :props

    def initialize(id:, w:, h:, exits:, walls: [], props: [])
      @id = id
      @w = w
      @h = h
      @exits = exits
      @walls = walls
      @props = props
    end
  end
end
