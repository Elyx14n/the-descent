# frozen_string_literal: true

module Descent
  # Based on DragonRuby's 16_camera_space_world_space_simple sample. World
  # positions stay fractional until conversion into a viewport-sized target.
  # One world pixel is one logical pixel. DragonRuby scales the 320x180 canvas
  # for display; the camera only translates, without changing sprite dimensions.
  class Camera
    TARGET = :scene

    attr_reader :x, :y, :bounds

    def initialize(bounds:)
      @bounds = bounds
      follow(x: bounds[:x] + bounds[:w].fdiv(2), y: bounds[:y] + bounds[:h].fdiv(2))
    end

    def follow(x:, y:)
      @x = bounded_center(x, @bounds[:x], @bounds[:w], viewport_w)
      @y = bounded_center(y, @bounds[:y], @bounds[:h], viewport_h)
      self
    end

    def scene(args)
      target = args.outputs[TARGET]
      target.w = viewport_w
      target.h = viewport_h
      target.background_color = [0, 0, 0, 0]
      target
    end

    def viewport_sprite
      viewport.merge(path: TARGET)
    end

    def to_screen(x:, y:)
      to_screen_space({ x: x, y: y })
    end

    # The game uses the logical, bottom-left 320x180 canvas and letterboxing.
    # Allscreen gives edge to edge screen rendering (requires pro license).
    def viewport_w
      Grid.w
    end

    def viewport_h
      Grid.h
    end

    def viewport_w_half
      viewport_w.fdiv(2)
    end

    def viewport_h_half
      viewport_h.fdiv(2)
    end

    def viewport
      { x: 0, y: 0, w: viewport_w, h: viewport_h }
    end

    def viewport_world
      to_world_space(viewport)
    end

    def to_world_space(rect)
      return rect.map { |r| to_world_space(r) } if rect.is_a? Array
      return nil unless rect

      rect.merge(x: rect[:x] - viewport_w_half + @x,
                 y: rect[:y] - viewport_h_half + @y)
    end

    def to_screen_space(rect)
      return rect.map { |r| to_screen_space(r) } if rect.is_a? Array
      return nil unless rect

      rect.merge(x: rect[:x] - @x + viewport_w_half,
                 y: rect[:y] - @y + viewport_h_half)
    end

    def find_all_intersect_viewport(objects)
      Geometry.find_all_intersect_rect(viewport_world, objects)
    end

    private

    def bounded_center(center, min, size, extent)
      return min + size.fdiv(2) if size <= extent

      half = extent.fdiv(2)
      center.clamp(min + half, min + size - half)
    end
  end
end
