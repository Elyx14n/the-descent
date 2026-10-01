# frozen_string_literal: true

require 'app/descent'
require ''

module Descent
  class Prop
    attr_reader :type, :x, :y, :w, :h, :rotation

    def initialize(type:, x:, y:, w:, h:, rotation: 0)
      @type = type
      @x = x
      @y = y
      @w = w
      @h = h
      @rotation = rotation
    end

    def bounds
      { x: @x, y: @y, w: @w, h: @h }
    end
  end
end
