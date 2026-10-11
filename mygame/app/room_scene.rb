# frozen_string_literal: true

require 'app/tiled_room'
require 'app/camera'
require 'app/player'
require 'app/ui'

module Descent
  module RoomScene
    MAP_PATH = 'tiled/ritual_gate.json'

    def self.tick(args)
      args.state.room_scene ||= { show_bounds: false }
      scene = args.state.room_scene
      keyboard = args.inputs.keyboard
      # Rebuild rooms loaded before FloorDetails was added during hot reload.
      reload(args) unless scene[:room]&.floor_details
      reload(args) if keyboard.key_down.r
      scene[:show_bounds] = !scene[:show_bounds] if keyboard.key_down.b
      scene[:direct_render] = !scene[:direct_render] if keyboard.key_down.f3
      scene[:nearest_filter] = !scene[:nearest_filter] if keyboard.key_down.f4
      player = args.state.player
      toggle_nearest_door(scene[:room], player) if keyboard.key_down.e
      player.update_controls({ dx: keyboard.left_right, dy: keyboard.up_down,
                               sneak: keyboard.shift, toggle_lamp: keyboard.key_down.f },
                             walls: scene[:room].collision_rects)
      player.update_animation
      scene[:camera].follow(x: player.x, y: player.y)
      render(args)
    end

    def self.reload(args)
      room = TiledRoom.load(args.gtk, path: MAP_PATH)
      args.state.room_scene[:room] = room
      args.state.room_scene[:camera] = Camera.new(bounds: room.bounds)
      # Recreate components so R also picks up changes to sprite/collider config.
      args.state.player = Player.new
      args.state.player.reset(**room.spawn)
    end

    def self.toggle_nearest_door(room, player)
      distances = room.doors.map do |door|
        distance = door[:closed_colliders].map do |rect|
          x = player.x.clamp(rect[:x], rect[:x] + rect[:w])
          y = player.y.clamp(rect[:y], rect[:y] + rect[:h])
          ((player.x - x)**2) + ((player.y - y)**2)
        end.min
        [door, distance]
      end
      distances.select! { |_door, distance| distance && distance <= 24**2 }
      door = distances.min_by { |_candidate, distance| distance }&.first
      return unless door

      next_colliders = door.fetch(door[:open] ? :closed_colliders : :open_colliders)
      return if Geometry.find_all_intersect_rect(player.collision_rect, next_colliders).any?

      room.set_door_open(door[:id], open: !door[:open])
    end

    def self.render(args)
      state = args.state.room_scene
      room = state[:room]
      camera = state[:camera]
      # F3 isolates the intermediate texture from atlas drawing during diagnosis.
      target = state[:direct_render] ? args.outputs : camera.scene(args)
      objects = room.objects.reject { |entry| entry[:mounted_on] }.each_with_index.map do |entry, index|
        sprites = [entry[:sprite]] + entry.fetch(:mounted_objects, []).map { |mounted| mounted[:sprite] }
        [entry[:depth], index, sprites]
      end
      objects << [args.state.player.y, objects.length, [args.state.player.sprite_to_primitive]]
      # World Y increases upward. Draw higher ground positions first, so lower
      # feet appear in front; overhead artwork stays above the sorted objects.
      floor = room.ground + room.floor_details.map { |entry| entry[:sprite] }
      # Preserve authored order at equal depth; keep wall-mounted artwork together.
      world = floor + objects.sort_by { |depth, index, _sprites| [-depth, index] }.flat_map(&:last) + room.ceiling
      sprites = camera.to_draw_space(camera.find_all_intersect_viewport(world))
      # Pixel-art sampling is the metadata default; F4 compares nearest sampling.
      sprites = sprites.map { |sprite| sprite.merge(scale_quality_enum: 0) } if state[:nearest_filter]
      target.primitives << sprites
      if state[:show_bounds]
        borders = room.collision_rects.map { |rect| rect.merge(r: 235, g: 185, b: 94) }
        borders << args.state.player.collision_rect.merge(r: 90, g: 255, b: 160)
        target.borders << camera.to_screen_space(camera.find_all_intersect_viewport(borders))
        room.lights.each do |light|
          point = { x: light[:x] - 1, y: light[:y] - 1, w: 2, h: 2, path: :solid, r: 255, g: 170, b: 60 }
          target.primitives << camera.to_draw_space(point)
        end
      end
      unless state[:direct_render]
        viewport = camera.viewport_sprite
        viewport = viewport.merge(scale_quality_enum: 0) if state[:nearest_filter]
        args.outputs.primitives << viewport
      end
      args.outputs.primitives << UI.label({ x: Grid.w.fdiv(2), y: Grid.h - 8 },
                                          text: 'WASD/arrows: move  Shift: sneak  F: lamp  E: door  B: boxes  R: load')
      return unless state[:show_bounds] || state[:direct_render] || state[:nearest_filter]

      mode = state[:direct_render] ? 'direct' : 'target'
      filter = state[:nearest_filter] ? 'nearest' : 'pixel art'
      args.outputs.primitives << UI.label({ x: Grid.w.fdiv(2), y: 8 },
                                          text: "F3: #{mode}  F4: #{filter}  #{Grid.render_scale}x")
    end
  end
end
