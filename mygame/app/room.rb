# frozen_string_literal: true

require 'app/descent'

module Descent
  class Room
    attr_reader :id, :x, :y, :w, :h, :exits

    def initialize(id:, x:, y:, w:, h:, exits: [])
      @id = id
      @x = x
      @y = y
      @w = w
      @h = h
      @exits = exits
    end
  end
end
