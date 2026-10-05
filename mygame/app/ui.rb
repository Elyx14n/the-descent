# frozen_string_literal: true

module Descent
  # Small drawing helpers, composed as ordinary DragonRuby primitives.
  module UI
    COLORS = {
      bg: {  r: 12, g: 10, b: 16 }.freeze,
      ink: { r: 18, g: 17, b: 22 }.freeze,
      stone: { r: 91, g: 87, b: 86 }.freeze,
      light: { r: 143, g: 135, b: 122 }.freeze,
      well: { r: 40, g: 38, b: 43 }.freeze,
      muted: { r: 155, g: 149, b: 140 }.freeze,
      accent: { r: 235, g: 185, b: 94 }.freeze
    }.freeze

    TEXT = {
      font: 'fonts/m5x7.ttf', # Sizes tuned at 320x180 with HD rendering enabled.
      body: 8,
      h1: 16,
      color: { r: 220, g: 215, b: 190 }.freeze
    }.freeze

    class << self
      # Rects use bottom-left coordinates, with no anchors. Padding must fit the rect.
      # Returns geometry only; does not mutate the source or carry its styling.
      def inset(rect, padding)
        { x: rect[:x] + padding, y: rect[:y] + padding,
          w: rect[:w] - (padding * 2), h: rect[:h] - (padding * 2) }
      end

      def box(rect, color: COLORS[:well])
        rect.merge(path: :solid, **color)
      end

      # The point is the label's center by default. Use DragonRuby's own properties
      # to override anchors, font, etc. Size is in logical pixels, not size_enum.
      def label(point, text:, size_px: TEXT[:body], color: TEXT[:color], **properties)
        point.merge(text: text, font: TEXT[:font], size_px: size_px,
                    anchor_x: 0.5, anchor_y: 0.5, **color, **properties)
      end

      # Three nested boxes, in drawing order. Thickness is the width of each edge.
      def bevel(rect, thickness: 2, color: COLORS[:stone], edge: COLORS[:ink], highlight: COLORS[:light])
        [box(rect, color: edge),
         box(inset(rect, thickness), color: highlight),
         box(inset(rect, thickness * 2), color: color)]
      end
    end
  end
end
