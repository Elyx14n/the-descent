# frozen_string_literal: true

require 'app/room_data'

module Descent
  # Loaded world data. Static artwork uses ordinary DragonRuby primitives.
  class Room
    FADE_BASE_TYPES = %i[wall door].freeze
    INTERACTABLE_TYPES = %i[door light].freeze
    INTERACTABLE_RADIUS = 24
    SQUARE_RADIUS = INTERACTABLE_RADIUS**2

    attr_reader :bounds, :spawn, :fade_units, *RoomData::COLLECTION_KEYS

    def initialize(bounds:, spawn:, collections:)
      @bounds = bounds
      @spawn = spawn

      RoomData::COLLECTION_KEYS.each do |key|
        instance_variable_set("@#{key}", collections.fetch(key))
      end

      prepare_draw_groups
      @floor_sprites = @ground + @floor_details.map { |entry| entry[:sprite] }
      @scenery_groups = @objects.reject { |entry| entry[:mounted_on] }.map do |entry|
        { depth: entry[:depth], sprites: scenery_sprites(entry) }
      end
      prepare_fade_units
      @interactables = @objects.select { |entry| INTERACTABLE_TYPES.include?(entry[:type]) }
      @doors.each { |door| apply_door_state(door) }
      update_animations(tick: 0)
    end

    def collision_rects
      @colliders + @doors.flat_map { |door| door.fetch(door[:open] ? :open_colliders : :closed_colliders) }
    end

    # World-space render data, independent of a camera or DragonRuby outputs.
    # Fresh outer collections let consumers append without changing membership.
    # Groups and their sprite lists are room-owned; sprite contents stay live.
    def render_data
      { floor: @floor_sprites.dup, groups: @scenery_groups.dup,
        ceiling: @ceiling.dup, fade_units: fade_units.dup }
    end

    # The preview or map supplies time; Room owns no animation clock.
    def update_animations(tick:)
      @lights.each do |light|
        frames = light[:animation]
        frame = if light[:frame_ticks]
                  frames[tick.div(light[:frame_ticks]) % frames.length]
                else
                  elapsed_ms = (tick * 1000) % (light[:animation_duration] * 60)
                  frames.find { |candidate| elapsed_ms < candidate[:end_ms] * 60 }
                end
        next if light[:lit_sprite].equal?(frame[:sprite])

        light[:lit_sprite] = frame[:sprite]
        apply_light_state(light)
      end
    end

    def toggle_nearest_interactable(point:, collision_rect:)
      entry = nearest_interactable(point)
      return unless entry

      case entry[:type]
      when :door
        return if entry[:properties].fetch('locked', false)

        next_colliders = entry.fetch(entry[:open] ? :closed_colliders : :open_colliders)
        return if Geometry.find_all_intersect_rect(collision_rect, next_colliders).any?

        set_door_open(entry[:id], open: !entry[:open])
      when :light
        set_light_enabled(entry[:id], enabled: !entry[:enabled])
      end
    end

    def set_door_open(id, open:)
      door = @doors.find { |candidate| candidate[:id] == id }
      raise ArgumentError, "Unknown door object #{id}" unless door

      door[:open] = open
      apply_door_state(door)
      door
    end

    def set_light_enabled(id, enabled:)
      light = @lights.find { |candidate| candidate[:id] == id }
      raise ArgumentError, "Unknown light object #{id}" unless light
      raise ArgumentError, 'Light enabled must be boolean' unless [true, false].include?(enabled)

      light[:enabled] = enabled
      apply_light_state(light)
      light
    end

    private

    def nearest_interactable(point)
      nearest = nil
      nearest_distance = SQUARE_RADIUS
      @interactables.each do |entry|
        rects = entry[:type] == :door ? entry[:closed_colliders] : [entry[:sprite]]
        distance = rects.map do |rect|
          x = point[:x].clamp(rect[:x], rect[:x] + rect[:w])
          y = point[:y].clamp(rect[:y], rect[:y] + rect[:h])
          ((point[:x] - x)**2) + ((point[:y] - y)**2)
        end.min
        next unless distance && distance <= nearest_distance
        next if nearest && distance == nearest_distance

        nearest = entry
        nearest_distance = distance
      end
      nearest
    end

    def apply_light_state(light)
      variant = light.fetch(light[:enabled] ? :lit_sprite : :unlit_sprite)
      return if light[:active_variant].equal?(variant)

      light[:sprite].replace(variant)
      light[:active_variant] = variant
    end

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
        base = owners.min_by { |entry| entry[:sprite][:y] }&.fetch(:sprite) || cap
        sprites = owners.flat_map { |entry| scenery_sprites(entry) } + [cap]
        fade_unit(base, sprites: sprites)
      end
      bases.reject { |entry| associated[entry[:id]] }.each do |entry|
        @fade_units << fade_unit(entry[:sprite], sprites: scenery_sprites(entry))
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

    def fade_unit(base, sprites:)
      {
        type: base.fetch(:type),
        base: base,
        footprint: base.slice(:x, :y, :w, :h),
        sprites: sprites
      }
    end
  end
end
