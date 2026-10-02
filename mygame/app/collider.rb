# frozen_string_literal: true

require 'app/descent'

module Descent
  class Collider
    def initialize(w:, h:)
      @w = w
      @h = h
    end

    def rect(x:, y:, scale:)
      width = @w * scale
      height = @h * scale
      {
        x: x - (width / 2.0),
        y: y,
        w: width,
        h: height
      }
    end
  end
end
