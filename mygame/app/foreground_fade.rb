# frozen_string_literal: true

module Descent
  # Actor-relative opacity, independent of camera placement and gameplay state.
  # Units reference the original sprites so identical artwork keeps its own order.
  module ForegroundFade
    RADIUS = 32
    MIN_OPACITIES = { wall: 0.25, door: 0.75, ceiling: 0.25 }.freeze
    FADE_OUT_TICKS = 16
    FADE_IN_TICKS = 32

    class << self
      def apply(world, units:, actors:, viewport:, state: nil, tick: 0, draw_order: nil)
        if units.empty?
          state&.clear
          return world
        end

        indices = draw_order || {}
        world.each_with_index { |sprite, index| indices[sprite.object_id] = index } unless draw_order || actors.empty?
        visible = actors.select do |actor|
          indices.key?(actor[:sprite].object_id) && Geometry.intersect_rect?(actor[:sprite], viewport)
        end
        multipliers = {}
        active = {}
        units.each do |unit|
          min_opacity = MIN_OPACITIES.fetch(unit.fetch(:type))
          opacity = 1.0
          visible.each do |actor|
            next unless occludes?(unit, actor, indices)

            unit[:colliders].each do |collider|
              next unless collider_occludes?(collider, actor)

              contribution = multiplier(collider, actor, type: unit[:type])
              opacity = contribution if contribution < opacity
            end
            break if opacity <= min_opacity
          end
          if state
            id = unit.object_id
            active[id] = true
            opacity = approach_opacity(opacity, state: state, id: id, tick: tick, min_opacity: min_opacity)
          end
          next if opacity >= 1.0

          unit[:sprites].each do |sprite|
            id = sprite.object_id
            multipliers[id] = opacity if opacity < multipliers.fetch(id, 1.0)
          end
        end
        state&.delete_if { |id, _value| !active[id] }
        return world if multipliers.empty?

        world.map do |sprite|
          opacity = multipliers[sprite.object_id]
          opacity ? sprite.merge(a: (sprite.fetch(:a, 255) * opacity).round) : sprite
        end
      end

      def multiplier(collider, actor, type:)
        # Measure the actor's ground gap north of the collider; inside it, the gap is zero.
        d = [actor[:y] - (collider[:y] + collider[:h]), 0].max
        # Normalize the gap to 0–1 across the fade radius.
        t = d.fdiv(RADIUS).clamp(0, 1)
        min_opacity = MIN_OPACITIES.fetch(type)
        # Smoothstep formula = 3t^2 - 2t^3 for S-shaped transformation
        smooth_step = (3 * (t**2)) - (2 * (t**3))
        # Interpolate opacity values using smoothstep to full opacity
        min_opacity.lerp(1.0, smooth_step)
      end

      private

      def approach_opacity(target, state:, id:, tick:, min_opacity:)
        previous = state[id] ||= { opacity: 1.0, tick: tick - 1 }
        opacity = previous[:opacity]
        elapsed = tick - previous[:tick]
        if target != opacity && elapsed.positive?
          duration = target < opacity ? FADE_OUT_TICKS : FADE_IN_TICKS
          step = (1 - min_opacity) * elapsed.fdiv(duration)
          opacity = opacity.towards(target, step)
          previous[:opacity] = opacity
        end
        previous[:tick] = tick
        opacity
      end

      def occludes?(unit, actor, indices)
        actor_index = indices.fetch(actor[:sprite].object_id)
        base = unit.fetch(:base)
        base_index = indices[base.object_id]
        return false unless base_index && (base_index <=> actor_index).positive?

        # Full artwork bounds must cross the actor's feet-to-head center line.
        unit[:sprites].any? do |sprite|
          index = indices[sprite.object_id]
          next false unless index && (index <=> actor_index).positive?

          crosses_center?(sprite, actor)
        end
      end

      def collider_occludes?(collider, actor)
        collider[:y] < actor[:y] && actor[:y] < collider[:y] + collider[:h] + RADIUS &&
          collider[:x] <= actor[:x] && actor[:x] < collider[:x] + collider[:w] &&
          collider[:w] > actor.fetch(:occlusion_width)
      end

      def crosses_center?(sprite, actor)
        rect = bounds(sprite)
        rect[:x] <= actor[:x] && actor[:x] < rect[:x] + rect[:w] &&
          rect[:y] < actor[:y] + actor.fetch(:occlusion_height) && rect[:y] + rect[:h] > actor[:y]
      end

      def bounds(sprite)
        { x: sprite[:x] - (sprite[:w] * sprite.fetch(:anchor_x, 0)),
          y: sprite[:y] - (sprite[:h] * sprite.fetch(:anchor_y, 0)),
          w: sprite[:w], h: sprite[:h] }
      end
    end
  end
end
