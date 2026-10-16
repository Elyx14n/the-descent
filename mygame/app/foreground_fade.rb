# frozen_string_literal: true

require 'app/sprite_geometry'

module Descent
  # Actor-relative opacity, independent of camera placement and gameplay state.
  # Units reference the original sprites so identical artwork keeps its own order.
  module ForegroundFade
    RADIUS = 32
    MIN_OPACITIES = { wall: 0.25, door: 0.75, ceiling: 0.25 }.freeze
    FADE_OUT_TICKS = 16
    FADE_IN_TICKS = 32

    class << self
      def apply(world, units:, actors:, viewport:, state: nil, tick: 0)
        if units.empty?
          state&.clear
          return world
        end

        indices = {}
        world.each_with_index { |sprite, index| indices[sprite.object_id] = index }
        visible = actors.select do |actor|
          indices.key?(actor[:sprite].object_id) && Geometry.intersect_rect?(actor[:sprite], viewport)
        end
        multipliers = {}
        active = {}
        units.each do |unit|
          min_opacity = MIN_OPACITIES.fetch(unit.fetch(:type))
          opacity = visible.map do |actor|
            next 1.0 unless occludes?(unit, actor, indices)

            multiplier(unit[:footprint], actor, type: unit[:type])
          end.min || 1.0
          if state
            id = unit.object_id
            active[id] = true
            opacity = approach_opacity(opacity, state: state, id: id, tick: tick, min_opacity: min_opacity)
          end
          next if opacity >= 1.0

          unit[:sprites].each do |sprite|
            id = sprite.object_id
            multipliers[id] = [multipliers.fetch(id, 1.0), opacity].min
          end
        end
        state&.delete_if { |id, _value| !active[id] }
        world.map do |sprite|
          opacity = multipliers[sprite.object_id]
          opacity ? sprite.merge(a: (sprite.fetch(:a, 255) * opacity).round) : sprite
        end
      end

      def multiplier(footprint, actor, type:)
        # Measure vertical gap between the player's y above the footprint's top edge; inside it, the gap is zero.
        d = [actor[:y] - (footprint[:y] + footprint[:h]), 0].max
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
        previous = state[id] || { opacity: 1.0, tick: tick - 1 }
        elapsed = [tick - previous[:tick], 0].max
        opacity = previous[:opacity]
        duration = target < opacity ? FADE_OUT_TICKS : FADE_IN_TICKS
        step = (1 - min_opacity) * elapsed.fdiv(duration)
        # Move opacity toward the target by at most step, stopping exactly at the target
        opacity = opacity.towards(target, step)
        state[id] = { opacity: opacity, tick: tick }
        opacity
      end

      def occludes?(unit, actor, indices)
        # A cap may extend north of the feet, but its base must be south of them.
        # Use continuous ground Y: a same-cell base can still genuinely hide an
        # actor. Overhead rendering alone does not establish this direction.
        return false if unit[:footprint][:y] >= actor[:y]

        actor_index = indices.fetch(actor[:sprite].object_id)
        base = unit.fetch(:base)
        base_index = indices[base.object_id]
        return false unless base_index && base_index > actor_index

        # The actor's center must cross the supporting base, not just graze it.
        base_bounds = SpriteGeometry.bounds(base)
        return false unless base_bounds[:x] <= actor[:x] && actor[:x] < base_bounds[:x] + base_bounds[:w]

        # A member must cross the center line and be wider than the actor's body.
        unit[:sprites].any? do |sprite|
          index = indices[sprite.object_id]
          next false unless index && index > actor_index

          if sprite.key?(:occlusion_regions)
            sprite[:occlusion_regions].any? do |local|
              rect = SpriteGeometry.transform_alpha_rect(sprite, local)
              rect[:w] > actor.fetch(:occlusion_width) && crosses_center?(rect, actor)
            end
          else
            rect = SpriteGeometry.alpha_bounds(sprite)
            rect && rect[:w] > actor.fetch(:occlusion_width) && crosses_center?(rect, actor)
          end
        end
      end

      def crosses_center?(rect, actor)
        rect[:x] <= actor[:x] && actor[:x] < rect[:x] + rect[:w] &&
          rect[:y] < actor[:y] + actor[:occlusion_height] && rect[:y] + rect[:h] > actor[:y]
      end
    end
  end
end
