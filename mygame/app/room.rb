# frozen_string_literal: true

module Descent
  # Loaded world data. Static artwork uses ordinary DragonRuby primitives.
  class Room
    attr_reader :bounds, :spawn, :ground, :floor_details, :objects, :ceiling, :doors, :lights, :pedestals

    def initialize(bounds:, spawn:, ground:, floor_details:, objects:, ceiling:, colliders:, doors:,
                   lights:, pedestals:)
      @bounds = bounds
      @spawn = spawn
      @ground = ground
      @floor_details = floor_details
      @objects = objects
      @ceiling = ceiling
      @colliders = colliders
      @doors = doors
      @lights = lights
      @pedestals = pedestals
      prepare_draw_groups
      @doors.each { |door| apply_door_state(door) }
    end

    def collision_rects
      @colliders + @doors.flat_map { |door| door.fetch(door[:open] ? :open_colliders : :closed_colliders) }
    end

    # World-space render data, independent of a camera or DragonRuby outputs.
    # Fresh collections let a consumer append actors without changing the room.
    def render_data
      { floor: @ground + @floor_details.map { |entry| entry[:sprite] },
        groups: @objects.reject { |entry| entry[:mounted_on] }.map do |entry|
          { depth: entry[:depth],
            sprites: [entry[:sprite]] + entry.fetch(:mounted_objects, []).map { |mounted| mounted[:sprite] } }
        end,
        ceiling: @ceiling.dup }
    end

    def toggle_nearest_door(point:, collision_rect:, radius: 24)
      distances = @doors.map do |door|
        distance = door[:closed_colliders].map do |rect|
          x = point[:x].clamp(rect[:x], rect[:x] + rect[:w])
          y = point[:y].clamp(rect[:y], rect[:y] + rect[:h])
          ((point[:x] - x)**2) + ((point[:y] - y)**2)
        end.min
        [door, distance]
      end
      distances.select! { |_door, distance| distance && distance <= radius**2 }
      door = distances.min_by { |_candidate, distance| distance }&.first
      return unless door
      # Check after targeting: a locked door must not redirect E to another door.
      return if door[:properties].fetch('locked', false)

      next_colliders = door.fetch(door[:open] ? :closed_colliders : :open_colliders)
      return if Geometry.find_all_intersect_rect(collision_rect, next_colliders).any?

      set_door_open(door[:id], open: !door[:open])
    end

    def set_door_open(id, open:)
      door = @doors.find { |candidate| candidate[:id] == id }
      raise ArgumentError, "Unknown door object #{id}" unless door

      door[:open] = open
      apply_door_state(door)
      door
    end

    private

    def apply_door_state(door)
      door[:parts].each do |part|
        part[:sprite].replace(part.fetch(door[:open] ? :open_sprite : :closed_sprite))
      end
    end

    def prepare_draw_groups
      @objects.each do |entry|
        entry[:depth] = entry[:colliders].map { |shape| shape[:y] }.min || entry[:sprite][:y]
      end
      by_id = @objects.to_h { |entry| [entry[:id], entry] }
      @objects.each do |entry|
        next unless entry[:mounted_on]

        wall = by_id.fetch(entry[:mounted_on])
        entry[:depth] = wall[:depth]
        wall[:mounted_objects] ||= []
        wall[:mounted_objects] << entry
      end
    end
  end
end
