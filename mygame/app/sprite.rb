# frozen_string_literal: true

module Descent
  class Sprite
    attr_reader :current_animation, :animation_tick

    def initialize(frame_size: 32, animations: nil, path: nil,
                   foot_padding: 0, facing_rows: nil, source_rect: nil)
      validate_image_source(path, animations)
      if source_rect && (animations || facing_rows)
        raise ArgumentError, 'source_rect cannot be combined with animations or facing_rows'
      end

      @frame_size = frame_size
      @animations = animations
      @path = path
      @foot_padding = foot_padding
      @facing_rows = facing_rows
      # Pixel coordinates measured from the image's bottom-left corner.
      @source_rect = source_rect
      reset
    end

    def reset
      @current_animation = nil
      @current_variant = nil
      @animation_tick = 0
    end

    def update(animation, variant = nil)
      return unless @animations

      @current_variant = variant

      if @current_animation != animation
        @current_animation = animation
        @animation_tick = 0
        return
      end

      clip = @animations.fetch(@current_animation)
      duration = clip[:frame_count] * clip[:ticks_per_frame]
      next_tick = @animation_tick + 1
      @animation_tick = clip[:loop] ? next_tick % duration : [next_tick, duration - 1].min
    end

    def to_primitive(x:, y:, facing: :south, scale: 1, animation: nil, variant: nil)
      # Before playback begins, render the actor's selection without starting its clock.
      clip = @animations&.fetch(@current_animation || animation)
      selected_variant = @current_animation ? @current_variant : variant
      frame = clip ? @animation_tick.div(clip[:ticks_per_frame]) : 0
      source = source_rect(frame, facing)

      {
        path: clip ? (clip[:path] || clip[:variants].fetch(selected_variant)) : @path,
        # Drawn on whole world pixels. Positions advance by fractions of one
        # when moving diagonally, and a sprite left on a fraction rounds out of
        # step with the camera origin, which reads as jitter rather than motion.
        x: x.round,
        y: (y - (@foot_padding * scale)).round,
        w: source.fetch(:w) * scale,
        h: source.fetch(:h) * scale,
        anchor_x: 0.5,
        anchor_y: 0,
        source_x: source.fetch(:x),
        source_y: source.fetch(:y),
        source_w: source.fetch(:w),
        source_h: source.fetch(:h)
      }
    end

    private

    def validate_image_source(path, animations)
      raise ArgumentError, 'path cannot be combined with animations' if path && animations
      raise ArgumentError, 'path or animations must be provided' unless path || animations
    end

    def source_rect(frame, facing)
      @source_rect || { x: frame * @frame_size, y: source_y(facing), w: @frame_size, h: @frame_size }
    end

    # Gets current sprite cell position from bottom-up (DR order)
    def source_y(facing)
      return 0 unless @facing_rows

      row = @facing_rows.fetch(facing)
      (@facing_rows.length - 1 - row) * @frame_size
    end
  end
end
