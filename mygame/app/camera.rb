# frozen_string_literal: true

require 'app/camera_scroll'

module Descent
  # Based on DragonRuby's 16_camera_space_world_space_simple sample. World
  # positions stay fractional; drawing snaps to physical display pixels.
  # One world pixel is one logical pixel. DragonRuby scales the 320x180 canvas
  # for display; the camera only translates, without changing sprite dimensions.
  class Camera
    attr_reader :x, :y

    def initialize(x:, y:)
      @scroll = CameraScroll.new
      follow(x: x, y: y)
    end

    def follow(x:, y:)
      @x = x
      @y = y
      self
    end

    def to_screen(x:, y:)
      to_screen_space({ x: x, y: y })
    end

    # The game uses the logical, bottom-left 320x180 canvas and letterboxing.
    # Allscreen gives edge to edge screen rendering (requires pro license).
    def viewport_w
      @draw_values ? @draw_values[:w] : Grid.w
    end

    def viewport_h
      @draw_values ? @draw_values[:h] : Grid.h
    end

    def viewport_w_half
      viewport_w.fdiv(2)
    end

    def viewport_h_half
      viewport_h.fdiv(2)
    end

    def viewport
      return @draw_values[:viewport] if @draw_values

      { x: 0, y: 0, w: viewport_w, h: viewport_h }
    end

    def viewport_world
      return @draw_values[:world] if @draw_values

      to_world_space(viewport)
    end

    # Capture once per draw, including display changes without camera movement.
    # The source camera and its ordinary conversions remain live and uncached.
    # snap: false tests fractional camera and artwork translation together.
    def for_drawing(snap: true)
      camera = dup
      camera.send(:prepare_draw_values, snap: snap)
      camera
    end

    # Interpolation changes the drawing position, not the simulation camera.
    # Initialize here too so cameras surviving a hot reload share the history.
    def for_presentation(x:, y:)
      @scroll ||= CameraScroll.new
      dup.follow(x: x, y: y)
    end

    # Drawing copies deliberately share presentation history with their source.
    # Simulation follows do not advance it; only presented positions do.
    def for_compositing
      @scroll ||= CameraScroll.new
      position = @scroll.position(x: @x, y: @y, scale: pixel_scale)
      camera = for_drawing
      camera.send(:prepare_compositing_values, position)
      camera
    end

    def reset_scroll
      @scroll&.reset
    end

    def to_world_space(rect)
      return for_drawing.to_world_space(rect) if rect.is_a?(Array) && !@draw_values
      return rect.map { |r| to_world_space(r) } if rect.is_a? Array
      return nil unless rect

      rect.merge(x: rect[:x] - screen_offset_x,
                 y: rect[:y] - screen_offset_y)
    end

    def to_screen_space(rect)
      return for_drawing.to_screen_space(rect) if rect.is_a?(Array) && !@draw_values
      return rect.map { |r| to_screen_space(r) } if rect.is_a? Array
      return nil unless rect

      rect.merge(x: rect[:x] + screen_offset_x,
                 y: rect[:y] + screen_offset_y)
    end

    # Raster placement is separate from reversible coordinate conversion.
    # Use one display pixel grid for tiles and actors; gameplay stays precise.
    def to_draw_space(rect)
      return for_drawing.to_draw_space(rect) if rect.is_a?(Array) && !@draw_values
      return rect.map { |r| to_draw_space(r) } if rect.is_a? Array
      return nil unless rect
      return to_screen_space(rect) if @draw_values && !@draw_values[:snap]

      rect.merge(x: pixel_position(rect[:x]) + screen_offset_x,
                 y: pixel_position(rect[:y]) + screen_offset_y)
    end

    def find_all_intersect_viewport(objects)
      Geometry.find_all_intersect_rect(viewport_world, objects)
    end

    private

    def prepare_draw_values(snap:)
      @draw_values = nil
      @draw_values = { scale: pixel_scale, w: viewport_w, h: viewport_h, snap: snap }
      @draw_values[:offset_x] = snap ? pixel_position(viewport_w_half) - pixel_position(@x) : viewport_w_half - @x
      @draw_values[:offset_y] = snap ? pixel_position(viewport_h_half) - pixel_position(@y) : viewport_h_half - @y
      @draw_values[:viewport] = { x: 0, y: 0, w: viewport_w, h: viewport_h }
      @draw_values[:world] = to_world_space(@draw_values[:viewport])
    end

    def prepare_compositing_values(position)
      @draw_values[:offset_x] = pixel_position(viewport_w_half) - position[:x]
      @draw_values[:offset_y] = pixel_position(viewport_h_half) - position[:y]
      @draw_values[:world] = to_world_space(@draw_values[:viewport])
    end

    # HD renders at display resolution. Whole logical pixels can land between
    # display pixels (e.g. at 5.5x); snap camera and artwork on the actual raster.
    # The inverse conversion and culling use this same displayed viewport.
    def screen_offset_x
      return @draw_values[:offset_x] if @draw_values

      pixel_position(viewport_w_half) - pixel_position(@x)
    end

    def screen_offset_y
      return @draw_values[:offset_y] if @draw_values

      pixel_position(viewport_h_half) - pixel_position(@y)
    end

    def pixel_position(value)
      scale = @draw_values ? @draw_values[:scale] : pixel_scale
      ((value * scale) + 0.5).floor.fdiv(scale)
    end

    def pixel_scale
      Grid.render_scale
    end
  end
end
