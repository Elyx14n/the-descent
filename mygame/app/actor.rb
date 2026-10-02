# frozen_string_literal: true

require 'app/entity'

module Descent
  class Actor < Entity
    def animation
      raise NotImplementedError
    end

    def animation_variant
      nil
    end

    # Advance once after movement and gameplay changes, before rendering.
    def update_animation
      super(animation, animation_variant)
    end

    def sprite_to_primitive
      super(animation: animation, variant: animation_variant)
    end

    def reset(x:, y:, facing: :south)
      super(x: x, y: y, facing: facing)
      @moving = false
    end

    def moving?
      @moving ||= false
    end

    def move(dx, dy, speed:, walls:)
      dx, dy = normalize_movement(dx, dy)

      moved_x = move_axis(dx * speed, :x, walls)
      moved_y = move_axis(dy * speed, :y, walls)

      @moving = !moved_x.zero? || !moved_y.zero?
      @facing = movement_facing(moved_x, moved_y) if @moving
    end

    private

    def move_axis(amount, axis, walls)
      return 0 if amount.zero?

      before = axis == :x ? @x : @y
      proposed = collision_rect
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

    def movement_facing(dx, dy)
      return dx.positive? ? :east : :west unless dx.zero?

      dy.positive? ? :north : :south
    end

    def normalize_movement(dx, dy)
      length = Math.hypot(dx, dy)

      return [dx, dy] if length <= 1

      [dx / length, dy / length]
    end
  end
end
