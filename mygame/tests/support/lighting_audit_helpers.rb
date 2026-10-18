# frozen_string_literal: true

# Opt-in audit fixtures: preserve the original square-boundary control workload.
# Production Lighting now uses a circular boundary instead.
require 'tests/support/room_helpers'

module LightingAuditHelpers
  include RoomTestHelpers

  def audit_frame(room, player)
    frame = room.render_data
    actor = player.render_data
    frame[:groups] << actor
    frame[:fade_actors] = [actor[:fade_actor]]
    lamp = player.light_source
    frame[:light_sources] << lamp if lamp
    frame[:world_lines] = []
    frame[:hud] = []
    frame
  end

  def audit_sources(frame)
    frame[:light_sources].map do |source|
      source.merge(radius: source[:radius].positive? ? source[:radius] : Descent::Lighting::DEFAULT_RADIUS)
    end
  end

  def audit_light_bounds(source)
    radius = source[:radius]
    { x: source[:x] - radius, y: source[:y] - radius, w: radius * 2, h: radius * 2 }
  end

  def audit_blocker_selected?(blocker, source, bounds)
    blocker[:owner_ids].none? { |id| source[:ignore_owner_ids].include?(id) } &&
      Geometry.intersect_rect?(blocker.fetch(:bounds, blocker[:sprite]), bounds)
  end

  def audit_edge_segments(blocker)
    blocker[:edges].map do |edge|
      { a: { x: edge[:x], y: edge[:y] }, b: { x: edge[:x2], y: edge[:y2] } }
    end
  end

  def audit_border(source)
    x = source[:x]
    y = source[:y]
    radius = source[:radius]
    corners = [[x - radius, y - radius], [x + radius, y - radius],
               [x + radius, y + radius], [x - radius, y + radius]]
    corners.each_with_index.map do |point, index|
      following = corners[(index + 1) % corners.length]
      { a: { x: point[0], y: point[1] }, b: { x: following[0], y: following[1] } }
    end
  end

  def audit_inputs(frame, sources = audit_sources(frame), shared_segments: false)
    prepared = frame[:light_blockers].map { |blocker| audit_edge_segments(blocker) } if shared_segments
    sources.map do |source|
      bounds = audit_light_bounds(source)
      segments = []
      frame[:light_blockers].each_with_index do |blocker, index|
        next unless audit_blocker_selected?(blocker, source, bounds)

        segments.concat(prepared ? prepared[index] : audit_edge_segments(blocker))
      end
      { source: source, segments: segments + audit_border(source) }
    end
  end

  def audit_cast(inputs)
    inputs.map do |input|
      source = input[:source]
      Descent::Raycasting.get_sight_polygon(source[:x], source[:y], segments: input[:segments])
    end
  end

  def audit_lines(polygons)
    polygons.flat_map do |polygon|
      polygon.each_with_index.map do |point, index|
        following = polygon[(index + 1) % polygon.length]
        { x: point[:x], y: point[:y], x2: following[:x], y2: following[:y], r: 255, g: 0, b: 0 }
      end
    end
  end
end
