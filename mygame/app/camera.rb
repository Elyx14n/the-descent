# frozen_string_literal: true

module Descent
  # Based on DragonRuby's 16_camera_space_world_space_simple sample. World
  # positions stay fractional; drawing snaps to physical display pixels.
  # One world pixel is one logical pixel. DragonRuby scales the 320x180 canvas
  # for display; the camera only translates, without changing sprite dimensions.
  class Camera
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

      rect.merge(x: rect[:x] - screen_offset_x,
                 y: rect[:y] - screen_offset_y)
    end

    def to_screen_space(rect)
      return rect.map { |r| to_screen_space(r) } if rect.is_a? Array
      return nil unless rect

      rect.merge(x: rect[:x] + screen_offset_x,
                 y: rect[:y] + screen_offset_y)
    end

    # Raster placement is separate from reversible coordinate conversion.
    # Use one display pixel grid for tiles and actors; gameplay stays precise.
    def to_draw_space(rect)
      return rect.map { |r| to_draw_space(r) } if rect.is_a? Array
      return nil unless rect

      rect.merge(x: pixel_position(rect[:x]) + screen_offset_x,
                 y: pixel_position(rect[:y]) + screen_offset_y)
    end

    def find_all_intersect_viewport(objects)
      Geometry.find_all_intersect_rect(viewport_world, objects)
    end

    private

    # HD renders at display resolution. Whole logical pixels can land between
    # display pixels (e.g. at 5.5x); snap camera and artwork on the actual raster.
    # The inverse conversion and culling use this same displayed viewport.
    def screen_offset_x
      pixel_position(viewport_w_half) - pixel_position(@x)
    end

    def screen_offset_y
      pixel_position(viewport_h_half) - pixel_position(@y)
    end

    def pixel_position(value)
      ((value * pixel_scale) + 0.5).floor.fdiv(pixel_scale)
    end

    def pixel_scale
      Grid.render_scale
    end

    def bounded_center(center, min, size, extent)
      return min + size.fdiv(2) if size <= extent

      half = extent.fdiv(2)
      center.clamp(min + half, min + size - half)
    end
  end
end
