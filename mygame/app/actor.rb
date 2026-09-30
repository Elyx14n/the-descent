# frozen_string_literal: true

module Descent
  class Actor
    attr_accessor :x, :y
    attr_reader :facing

    def initialize(x = 0, y = 0)
      reset(x: x, y: y)
    end

    def reset(x:, y:)
      @x = x
      @y = y
      @facing = :south
      @animation_tick = 0
      @last_animation = nil
      @moving = false
    end

    def config
      raise NotImplementedError
    end

    def animation
      raise NotImplementedError
    end

    def animation_state
      animation
    end

    def animation_loop?
      true
    end

    def moving?
      @moving ||= false
    end

    def sprite
      cfg = config
      scale = cfg.fetch(:display_scale, 1)
      frame = (@animation_tick || 0).div(cfg[:ticks_per_frame])
      row = cfg[:facing_rows][@facing || :south]

      {
        path: cfg[:animations].fetch(animation),
        x: @x,
        y: @y - (cfg.fetch(:foot_padding, 0) * scale),
        w: cfg[:frame_size] * scale,
        h: cfg[:frame_size] * scale,
        anchor_x: 0.5,
        anchor_y: 0,
        scale_quality_enum: 0,
        source_x: frame * cfg[:frame_size],
        source_y: (3 - row) * cfg[:frame_size],
        source_w: cfg[:frame_size],
        source_h: cfg[:frame_size]
      }
    end

    def collider
      cfg = config
      scale = cfg.fetch(:display_scale, 1)
      width = cfg[:collider_width] * scale
      {
        x: @x - (width / 2.0),
        y: @y,
        w: width,
        h: cfg[:collider_height] * scale
      }
    end

    def move_axis(amount, axis, walls)
      return 0 if amount.zero?

      before = axis == :x ? @x : @y
      proposed = collider
      offset = proposed[axis] - before
      proposed[axis] += amount
      position = collision_position(proposed, axis, amount, walls) - offset

      if axis == :x
        @x = position
      else
        @y = position
      end
      position - before
    end

    def collision_position(rect, axis, amount, walls)
      size = axis == :x ? :w : :h
      overlaps = Geometry.find_all_intersect_rect(rect, walls)
      edges = overlaps.map do |wall|
        amount.positive? ? (wall[axis] - rect[size]) : (wall[axis] + wall[size])
      end
      (amount.positive? ? edges.min : edges.max) || rect[axis]
    end

    def update_animation(dx, dy)
      @moving = !dx.zero? || !dy.zero?
      @facing = movement_facing(dx, dy) if @moving
      current_animation = animation_state
      @animation_tick = if @last_animation == current_animation
                          advance_animation_tick
                        else
                          0
                        end
      @last_animation = current_animation
    end

    def advance_animation_tick
      duration = config[:frame_count] * config[:ticks_per_frame]
      next_tick = @animation_tick + 1
      animation_loop? ? next_tick % duration : [next_tick, duration - 1].min
    end

    def movement_facing(dx, dy)
      return dx.positive? ? :east : :west unless dx.zero?

      dy.positive? ? :north : :south
    end

    def normalize_movement(dx, dy)
      length = Math.hypot(dx, dy)

      return [dx, dy] if length <= 1

      [dx / length, dy / length]
    end

    def move(dx, dy, speed:, walls:)
      dx, dy = normalize_movement(dx, dy)

      moved_x = move_axis(dx * speed, :x, walls)
      moved_y = move_axis(dy * speed, :y, walls)

      update_animation(moved_x, moved_y)
    end

    class << self
      def spawn(x:, y:)
        new(x, y)
      end
    end
  end
end
