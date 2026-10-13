# frozen_string_literal: true

require 'app/room_data'

module Descent
  # Loaded world data. Static artwork uses ordinary DragonRuby primitives.
  class Room
    FADE_BASE_TYPES = %i[wall door].freeze

    attr_reader :bounds, :spawn, :fade_units, *RoomData::COLLECTION_KEYS

    def initialize(bounds:, spawn:, collections:)
      @bounds = bounds
      @spawn = spawn

      RoomData::COLLECTION_KEYS.each do |key|
        instance_variable_set("@#{key}", collections.fetch(key))
      end

      prepare_draw_groups
      prepare_fade_units
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
            sprites: scenery_sprites(entry) }
        end,
        ceiling: @ceiling.dup, fade_units: fade_units.dup }
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

    def scenery_sprites(entry)
      [entry[:sprite]] + entry.fetch(:mounted_objects, []).map { |mounted| mounted[:sprite] }
    end

    # Associate caps locally, without joining a connected wall into one large
    # fade. Same-cell walls handle corners where face and ceiling art overlap.
    def prepare_fade_units
      bases = @objects.select do |entry|
        !entry[:mounted_on] && FADE_BASE_TYPES.include?(entry[:type])
      end
      associated = {}
      @fade_units = @ceiling.map do |cap|
        owners = bases.select { |entry| cap_above_base?(cap, entry) }
        owners.each { |entry| associated[entry[:id]] = true }
        footprint = owners.min_by { |entry| entry[:sprite][:y] }&.fetch(:sprite) || cap
        { type: footprint.fetch(:type), base: footprint, footprint: footprint.slice(:x, :y, :w, :h),
          sprites: owners.flat_map { |entry| scenery_sprites(entry) } + [cap] }
      end
      bases.reject { |entry| associated[entry[:id]] }.each do |entry|
        @fade_units << { type: entry.fetch(:type), base: entry[:sprite],
                         footprint: entry[:sprite].slice(:x, :y, :w, :h),
                         sprites: scenery_sprites(entry) }
      end
    end

    def cap_above_base?(cap, entry)
      return true if entry[:type] == :door && entry[:parts].any? { |part| part[:sprite].equal?(cap) }

      base = entry[:sprite]
      base[:x] == cap[:x] && base[:w] == cap[:w] &&
        (base[:y] == cap[:y] || base[:y] + base[:h] == cap[:y])
    end

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
