# frozen_string_literal: true

module Descent
  # Loaded world data. Static artwork uses ordinary DragonRuby primitives.
  class Room
    attr_reader :bounds, :spawn, :ground, :floor_details, :objects, :ceiling, :doors, :lights, :interactables

    def initialize(bounds:, spawn:, ground:, floor_details:, objects:, ceiling:, colliders:, doors:,
                   lights:, interactables:)
      @bounds = bounds
      @spawn = spawn
      @ground = ground
      @floor_details = floor_details
      @objects = objects
      @ceiling = ceiling
      @colliders = colliders
      @doors = doors
      @lights = lights
      @interactables = interactables
    end

    def collision_rects
      @colliders + @doors.flat_map { |door| door.fetch(door[:open] ? :open_colliders : :closed_colliders) }
    end

    def set_door_open(id, open:)
      door = @doors.find { |candidate| candidate[:id] == id }
      raise ArgumentError, "Unknown door object #{id}" unless door

      door[:open] = open
      door[:parts].each do |part|
        part[:sprite].replace(part.fetch(open ? :open_sprite : :closed_sprite))
      end
      door
    end
  end
end
