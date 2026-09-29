# frozen_string_literal: true

module Descent
  class Actor
    attr_accessor :x, :y
    attr_reader :facing

    def initialize(x = 0, y = 0)
      @x = x
      @y = y
      @facing = :south
      @animation_tick = 0
    end

    def config
      raise NotImplementedError
    end

    def collider_width
      raise NotImplementedError
    end

    def collider_height
      raise NotImplementedError
    end

    def sprite
      cfg = config
      frame = (@animation_tick || 0).div(cfg[:ticks_per_frame])
      row = cfg[:facing_rows][@facing || :south]

      cfg[:sprite_base].merge(
        x: @x,
        y: @y,
        source_x: frame * cfg[:frame_size],
        source_y: (3 - row) * cfg[:source_frame_height],
        source_w: cfg[:frame_size],
        source_h: cfg[:source_frame_height]
      )
    end

    def collider
      w = collider_width
      { x: @x + ((config[:sprite_base][:w] - w) / 2.0), y: @y,
        w: w, h: collider_height }
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

    def update_animation(move_x, move_y)
      if move_x.zero? && move_y.zero?
        @animation_tick = 0
      else
        @facing = movement_facing(move_x, move_y)
        @animation_tick = ((@animation_tick || 0) + 1) % (config[:frame_count] * config[:ticks_per_frame])
      end
    end

    def movement_facing(move_x, move_y)
      return move_x.positive? ? :east : :west unless move_x.zero?

      move_y.positive? ? :north : :south
    end

    def normalize_movement(x, y)
      length = Math.hypot(x, y)

      return [x, y] if length <= 1

      [x / length, y / length]
    end

    def move(move_x, move_y, speed:, walls:)
      move_x, move_y = normalize_movement(move_x, move_y)

      actual_x = move_axis(move_x * speed, :x, walls)
      actual_y = move_axis(move_y * speed, :y, walls)

      update_animation(actual_x, actual_y)
    end

    class << self
      def spawn(x:, y:)
        new(x, y)
      end
    end
  end
end
