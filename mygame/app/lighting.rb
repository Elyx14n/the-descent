# frozen_string_literal: true

require 'app/raycasting'

module Descent
  # Stateless consumer of lighting inputs. Prepared polygons remain in world space.
  module Lighting
    CIRCLE_SEGMENTS = 32
    DEFAULT_RADIUS = 48
    AMBIENT = 31
    LIGHT_MASK_PATH = 'sprites/light_mask.png'
    LIGHT_MASK_TARGET = :radial_light
    LIGHT_MASK_SIZE = 128
    LIGHTMAP_TARGET = :lightmap
    # The supplied black mask stores falloff in alpha. White * destination
    # alpha turns it into RGB illumination, with opaque alpha for additive use.
    MASK_ALPHA_TO_RGB = Numeric.compose_blendmode(
      BLENDFACTOR_DST_ALPHA, BLENDFACTOR_ZERO, BLENDOPERATION_ADD,
      BLENDFACTOR_ONE, BLENDFACTOR_ZERO, BLENDOPERATION_ADD
    )

    class << self
      def prepare(light_sources:, light_blockers:)
        light_sources.map do |source|
          radius = source.fetch(:radius, 0)
          source = source.merge(radius: radius.positive? ? radius : DEFAULT_RADIUS)
          segments = segments_for(source, light_blockers)
          { source: source,
            sight_polygon: Raycasting.get_sight_polygon(source[:x], source[:y], segments: segments) }
        end
      end

      # Fill a source-visible polygon as a fan, preserving fractional vertices
      # through the drawing camera's world-to-screen conversion.
      # SDK 7.21's triangle path uses explicit UVs and blendmode_enum.
      def triangles(light_polygons:, camera:)
        light_polygons.flat_map do |light|
          polygon = light[:sight_polygon]
          next [] if polygon.length < 3

          source = camera.to_screen(x: light[:source][:x], y: light[:source][:y])
          radius = light[:source].fetch(:radius, DEFAULT_RADIUS)
          texture_scale = LIGHT_MASK_SIZE.fdiv(radius * 2)
          center = LIGHT_MASK_SIZE.fdiv(2)
          color = contribution_color(light[:source])
          points = polygon.map { |point| camera.to_screen(x: point[:x], y: point[:y]) }
          points.each_with_index.map do |point, index|
            following = points[(index + 1) % points.length]
            { x: source[:x], y: source[:y], x2: point[:x], y2: point[:y],
              x3: following[:x], y3: following[:y], path: LIGHT_MASK_TARGET,
              source_x: center, source_y: center,
              source_x2: center + ((point[:x] - source[:x]) * texture_scale),
              source_y2: center + ((point[:y] - source[:y]) * texture_scale),
              source_x3: center + ((following[:x] - source[:x]) * texture_scale),
              source_y3: center + ((following[:y] - source[:y]) * texture_scale),
              **color, blendmode_enum: 2 }
          end
        end
      end

      def polygon_lines(light_polygons:)
        light_polygons.flat_map do |light|
          polygon = light[:sight_polygon]
          polygon.each_with_index.map do |point, index|
            following = polygon[(index + 1) % polygon.length]
            { x: point[:x], y: point[:y], x2: following[:x], y2: following[:y], r: 255, g: 0, b: 0 }
          end
        end
      end

      # Prepare this pass before Render creates :scene: DragonRuby executes
      # targets in first-access order, so consumers must come after producers.
      def draw_lightmap(args, light_polygons:, camera:)
        draw_light_mask(args) unless light_polygons.empty?
        lightmap = args.outputs[LIGHTMAP_TARGET]
        lightmap.w = camera.viewport_w
        lightmap.h = camera.viewport_h
        lightmap.background_color = [AMBIENT, AMBIENT, AMBIENT, 255]
        lightmap.primitives << triangles(light_polygons: light_polygons, camera: camera)
        camera.viewport.merge(path: LIGHTMAP_TARGET, blendmode: 8)
      end

      # Sample each upright object's collider base, rather than the floor pixels
      # covered by its tall artwork. Identity keys live only for this frame.
      def receiver_colors(light_receivers:, light_polygons:)
        colors = {}
        channel_names = %i[r g b]
        light_receivers.each { |receiver| colors[receiver[:sprite].object_id] = [AMBIENT, AMBIENT, AMBIENT] }
        light_polygons.each do |light|
          color = contribution_color(light[:source])
          light_receivers.each do |receiver|
            # Upright faces point south. An exposed side/corner must not light
            # the entire front face from a source on the floor behind it.
            next if receiver.key?(:front_y) && light[:source][:y] > receiver[:front_y]

            strength = receiver[:bases].map do |receiver_base|
              received_light_strength(light: light, receiver_base: receiver_base)
            end.max || 0
            channels = colors.fetch(receiver[:sprite].object_id)
            channel_names.each_with_index do |channel, index|
              channels[index] += color[channel] * color[:a].fdiv(255) * strength
            end
          end
        end
        colors
      end

      def tint(sprite, color: [AMBIENT, AMBIENT, AMBIENT])
        sprite.merge(r: (sprite.fetch(:r, 255) * color[0].clamp(0, 255).fdiv(255)).round,
                     g: (sprite.fetch(:g, 255) * color[1].clamp(0, 255).fdiv(255)).round,
                     b: (sprite.fetch(:b, 255) * color[2].clamp(0, 255).fdiv(255)).round)
      end

      private

      def draw_light_mask(args)
        mask = args.outputs[LIGHT_MASK_TARGET]
        mask.w = LIGHT_MASK_SIZE
        mask.h = LIGHT_MASK_SIZE
        mask.background_color = [0, 0, 0, 0]
        rect = { x: 0, y: 0, w: LIGHT_MASK_SIZE, h: LIGHT_MASK_SIZE }
        mask.primitives << rect.merge(path: LIGHT_MASK_PATH, blendmode: 0)
        mask.primitives << rect.merge(path: :solid, r: 255, g: 255, b: 255, a: 255, blendmode: MASK_ALPHA_TO_RGB)
      end

      def contribution_color(source)
        hex = source.fetch(:color, '').delete('#')
        alpha = hex.length == 8 ? hex[0, 2].to_i(16) : 255
        hex = hex[-6, 6] if hex.length == 8
        channels = hex.length == 6 ? [0, 2, 4].map { |offset| hex[offset, 2].to_i(16) } : [255, 255, 255]
        intensity = source.fetch(:intensity, 1)
        { r: (channels[0] * intensity).round.clamp(0, 255),
          g: (channels[1] * intensity).round.clamp(0, 255),
          b: (channels[2] * intensity).round.clamp(0, 255), a: alpha }
      end

      # Strength (0..1) of this light at the receiving object's base.
      # Used to tint the whole receiving sprite.
      def received_light_strength(light:, receiver_base:)
        source = light[:source]
        dx = source[:x].clamp(receiver_base[:x], receiver_base[:x] + receiver_base[:w]) - source[:x]
        dy = source[:y].clamp(receiver_base[:y], receiver_base[:y] + receiver_base[:h]) - source[:y]
        distance = Math.hypot(dx, dy)
        return 0 if distance >= source[:radius] || light[:sight_polygon].length < 3
        return 1 if distance.zero?

        # Move just toward the light so a wall's near surface can receive light
        # while the same base still blocks light reaching the floor behind it.
        scale = [1 - 0.01.fdiv(distance), 0].max
        return 0 unless visible?(light, dx * scale, dy * scale)

        1 - distance.fdiv(source[:radius])
      end

      def visible?(light, dx, dy)
        polygon = light[:sight_polygon]
        angle = Math.atan2(dy, dx)
        low = 0
        high = polygon.length
        # The raycaster already orders boundary points by angle. Find the one
        # boundary edge facing this sample instead of casting against the room again.
        while low < high
          middle = (low + high).div(2)
          if polygon[middle][:angle] <= angle
            low = middle + 1
          else
            high = middle
          end
        end
        # The angular search already selects the finite boundary edge. Test its
        # inward side directly: recasting at a vertex can round t2 just below 0
        # and reject an otherwise visible sample as the source moves.
        a = polygon[(low - 1) % polygon.length]
        b = polygon[low % polygon.length]
        sample_x = light[:source][:x] + dx
        sample_y = light[:source][:y] + dy
        cross = ((b[:x] - a[:x]) * (sample_y - a[:y])) - ((b[:y] - a[:y]) * (sample_x - a[:x]))
        cross >= -0.000001
      end

      def segments_for(source, blockers)
        x = source[:x]
        y = source[:y]
        radius = source.fetch(:radius)
        bounds = { x: x - radius, y: y - radius, w: radius * 2, h: radius * 2 }
        ignored = source.fetch(:ignore_owner_ids, [])
        selected = blockers.select do |blocker|
          blocker[:owner_ids].none? { |id| ignored.include?(id) } &&
            Geometry.intersect_rect?(blocker.fetch(:bounds, blocker[:sprite]), bounds)
        end
        segments = selected.flat_map do |blocker|
          blocker[:edges].map do |edge|
            { a: { x: edge[:x], y: edge[:y] }, b: { x: edge[:x2], y: edge[:y2] } }
          end
        end
        # The square above only selects nearby blockers. This inscribed ring
        # terminates rays at the light's circular range (within ~0.5px at r=96).
        points = Array.new(CIRCLE_SEGMENTS) do |index|
          angle = index * (Math::PI * 2).fdiv(CIRCLE_SEGMENTS)
          { x: x + (Math.cos(angle) * radius), y: y + (Math.sin(angle) * radius) }
        end
        border = points.each_with_index.map do |point, index|
          { a: point, b: points[(index + 1) % points.length] }
        end
        segments + border
      end
    end
  end
end
