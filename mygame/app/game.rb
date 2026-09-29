# frozen_string_literal: true

require 'app/descent'

module Descent
  module Game
    BG_COLOR = { r: 12, g: 10, b: 16 }.freeze

    LAYOUT = {
      screen_padding: 24,
      element_gap: 12
    }.freeze

    TEXT = {
      body: 22,
      h1: 32,
      color: { r: 220, g: 215, b: 190 }.freeze
    }.freeze

    STATE_DEFAULTS = {
      paused: false,
      debug_visible: false
    }.freeze
  end
end
