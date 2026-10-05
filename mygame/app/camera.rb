# frozen_string_literal: true

module Descent
  # The world is authored and simulated in world pixels, where one tile is
  # Tilesheet::TILE_SIZE. Magnification lives here and nowhere else: entities
  # keep scale 1, the scene is drawn once at world resolution, and ZOOM is
  # applied to the whole render target in a single blit. That keeps every
  # sprite on the same pixel grid, which per-entity scaling cannot guarantee.
  class Camera
    SCREEN_W = 1280
    SCREEN_H = 720
    ZOOM = 3
    TARGET = :scene

    # World pixels the screen covers. The height divides evenly; the width
    # leaves a partial column that the blit samples but never shows.
    VIEWPORT_W = SCREEN_W / ZOOM.to_f
    VIEWPORT_H = SCREEN_H / ZOOM.to_f

    # Half a viewport, in whole world pixels. Both this and the followed
    # position must be integers, else they round out of step and anything moving
    # by a fraction of a world pixel -- any diagonal -- jitters against the
    # scrolling world instead of staying put on screen.
    HALF_W = (VIEWPORT_W / 2).round
    HALF_H = (VIEWPORT_H / 2).round

    attr_reader :x, :y, :bounds

    # Bounds is the world rect the camera may show, in world pixels.
    def initialize(bounds:)
      @bounds = bounds
      @x = bounds[:x] + (bounds[:w] / 2.0)
      @y = bounds[:y] + (bounds[:h] / 2.0)
    end

    # Centers the view on a point without showing anything outside bounds.
    def follow(x:, y:)
      @x = x
      @y = y
      self
    end

    # Configures the world render target and returns it to draw into. Sized to
    # the far edge of the world so world coordinates are also target
    # coordinates, with no translation step before drawing.
    def scene(args)
      target = args.outputs[TARGET]
      target.w = @bounds[:x] + @bounds[:w]
      target.h = @bounds[:y] + @bounds[:h]
      target.background_color = [0, 0, 0, 0]
      target
    end

    # The single primitive that puts the world on screen. Pans and zooms in one
    # step; an axis whose world extent fits the viewport is centered instead.
    def viewport_sprite
      horizontal = axis_window(@x, @bounds[:x], @bounds[:w], VIEWPORT_W, HALF_W, SCREEN_W)
      vertical = axis_window(@y, @bounds[:y], @bounds[:h], VIEWPORT_H, HALF_H, SCREEN_H)

      { x: horizontal[:screen], y: vertical[:screen],
        w: horizontal[:screen_size], h: vertical[:screen_size],
        path: TARGET,
        source_x: horizontal[:world], source_y: vertical[:world],
        source_w: horizontal[:world_size], source_h: vertical[:world_size] }
    end

    # Places a screen-space primitive, such as a label, over a world position.
    # Needed because the world scrolls underneath the screen once it is larger
    # than the viewport; text stays sharp by never entering the scene.
    def to_screen(x:, y:)
      horizontal = axis_window(@x, @bounds[:x], @bounds[:w], VIEWPORT_W, HALF_W, SCREEN_W)
      vertical = axis_window(@y, @bounds[:y], @bounds[:h], VIEWPORT_H, HALF_H, SCREEN_H)

      { x: horizontal[:screen] + ((x - horizontal[:world]) * ZOOM),
        y: vertical[:screen] + ((y - vertical[:world]) * ZOOM) }
    end

    private

    # Worlds narrower than the viewport cannot fill the screen, so they are
    # centered whole. Larger ones scroll, clamped to the world edges. The
    # origin is derived from the rounded centre rather than rounded afterwards,
    # so it steps in lockstep with the whole-pixel positions Sprite draws at.
    def axis_window(center, min, size, viewport, half, screen)
      return centered_window(min, size, screen) if size <= viewport

      origin = center.round - half
      limit = (min + size - viewport).round
      origin = origin.clamp(min, limit)

      { world: origin, world_size: viewport, screen: 0, screen_size: screen }
    end

    def centered_window(min, size, screen)
      magnified = size * ZOOM
      { world: min, world_size: size,
        screen: ((screen - magnified) / 2.0).round, screen_size: magnified }
    end
  end
end
