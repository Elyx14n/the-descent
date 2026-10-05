# frozen_string_literal: true

require 'app/camera'
require 'app/player'
require 'app/prop'
require 'app/ui'

module Descent
  # Temporary, hand-placed room for tuning movement and the player's ground footprint.
  module CollisionPlayground
    PLAYER_SPAWN = { x: 133, y: 60, facing: :south }.freeze
    DANGER_DELAY_TICKS = 120
    RESPAWN_DELAY_TICKS = 120 # Two seconds at DragonRuby's 60 ticks per second.

    # Change these types/positions and save to try any name in Tilesheet::TILES.
    PROP_PLACEMENTS = [
      { id: :closed_stone_coffin, x: 217, y: 97 },
      { id: :red_banner, x: 360, y: 158 }
    ].map(&:freeze).freeze

    # Walls are 8 world pixels thick. The gap in the upper run is an 11-pixel
    # doorway, against the player's 8-pixel foot collider. The room is
    # deliberately wider and taller than one viewport so the camera scrolls.
    WALLS = [
      { x: 21, y: 27, w: 700, h: 8 },
      { x: 21, y: 419, w: 700, h: 8 },
      { x: 21, y: 35, w: 8, h: 384 },
      { x: 713, y: 35, w: 8, h: 384 },
      { x: 160, y: 67, w: 8, h: 80 },
      { x: 168, y: 67, w: 53, h: 8 },
      { x: 253, y: 113, w: 53, h: 8 },
      { x: 317, y: 113, w: 396, h: 8 }
    ].map(&:freeze).freeze

    WORLD_BOUNDS = { x: 21, y: 27, w: 700, h: 400 }.freeze

    RED_TILE = {
      x: 29,
      y: 35,
      w: 85,
      h: 85,
      r: 220, g: 50, b: 50,
      path: :solid
    }.freeze

    def self.tick(args, tick_count: Kernel.tick_count)
      args.state.playground ||= { show_bounds: true, walls: WALLS.map(&:dup) }
      playground = args.state.playground
      refresh_camera(playground)
      refresh_props(playground)
      prop_colliders = playground[:props].map(&:collision_rect).compact
      keyboard = args.inputs.keyboard
      args.state.player ||= Player.new(x: PLAYER_SPAWN[:x], y: PLAYER_SPAWN[:y])
      playground[:show_bounds] = !playground[:show_bounds] if keyboard.key_down.b
      args.state.player.update_controls(input(keyboard), walls: playground[:walls] + prop_colliders)
      check_danger_zones(args, tick_count: tick_count)
      args.state.player.update_animation
      playground[:camera].follow(x: args.state.player.x, y: args.state.player.y)
      render(args, prop_colliders: prop_colliders, tick_count: tick_count)
    end

    def self.refresh_camera(playground)
      # Refresh edited map bounds on hot reload without resetting player state.
      return if playground[:camera]&.bounds.equal?(WORLD_BOUNDS)

      playground[:camera] = Camera.new(bounds: WORLD_BOUNDS)
    end

    def self.refresh_props(playground)
      # Hot reload replaces these frozen constants. Existing component instances
      # retain old values, so rebuild props before both collision and rendering.
      sources = [PROP_PLACEMENTS, Prop::PROP_OVERRIDES, Tilesheet::TILES]
      previous = playground[:prop_sources]
      return if previous && sources.each_with_index.all? { |source, i| source.equal?(previous[i]) }

      playground[:props] = PROP_PLACEMENTS.map { |placement| Prop.spawn(**placement) }
      playground[:prop_sources] = sources
    end

    def self.check_danger_zones(args, tick_count: Kernel.tick_count)
      player = args.state.player
      playground = args.state.playground
      update_danger_countdown(args, tick_count: tick_count) if player.sanity.positive?
      return unless player.sanity <= 0

      playground[:danger_death_at] = nil
      playground[:respawn_at] ||= tick_count + RESPAWN_DELAY_TICKS
      return if tick_count < playground[:respawn_at]

      player.reset(**PLAYER_SPAWN)
      playground[:respawn_at] = nil
    end

    def self.update_danger_countdown(args, tick_count:)
      player = args.state.player
      playground = args.state.playground
      unless args.geometry.intersect_rect?(player.collision_rect, RED_TILE)
        playground[:danger_death_at] = nil
        return
      end

      playground[:danger_death_at] ||= tick_count + DANGER_DELAY_TICKS
      player.sanity = 0 if tick_count >= playground[:danger_death_at]
    end

    def self.input(keyboard)
      { dx: keyboard.left_right, dy: keyboard.up_down,
        sneak: keyboard.shift, toggle_lamp: keyboard.key_down.f }
    end

    # Cull in world space, then convert visible primitives into screen pixels
    # inside the viewport-sized target. HUD and annotations are drawn above it.
    def self.render(args, prop_colliders:, tick_count: Kernel.tick_count)
      playground = args.state.playground
      camera = playground[:camera]
      walls = playground[:walls]
      scene = camera.scene(args)

      entities = playground[:props] + [args.state.player]
      world = [RED_TILE] + walls.map { |wall| UI.box(wall, color: UI::COLORS[:stone]) }
      world += entities.sort_by { |entity| -entity.y }.map(&:sprite_to_primitive)
      scene.primitives << camera.to_screen_space(camera.find_all_intersect_viewport(world))
      if playground[:show_bounds]
        render_bounds(scene, args, camera: camera, walls: walls, prop_colliders: prop_colliders)
      end

      args.outputs.primitives << camera.viewport_sprite
      args.outputs.primitives << labels(camera)
      render_countdown(args, tick_count)
    end

    def self.render_bounds(scene, args, camera:, walls:, prop_colliders:)
      borders = walls.map { |wall| wall.merge(r: 235, g: 185, b: 94) }
      borders += prop_colliders.map { |rect| rect.merge(r: 100, g: 180, b: 255) }
      borders << args.state.player.collision_rect.merge(r: 90, g: 255, b: 160)
      scene.borders << camera.to_screen_space(camera.find_all_intersect_viewport(borders))
    end

    def self.render_countdown(args, tick_count)
      playground = args.state.playground
      countdown_at = playground[:respawn_at] || playground[:danger_death_at]
      return unless countdown_at

      seconds = ((countdown_at - tick_count) / 60.0).ceil
      text = playground[:respawn_at] ? "Respawning in #{seconds}..." : "Leave the red tile! #{seconds}s"
      args.outputs.primitives << UI.label({ x: Grid.w.fdiv(2), y: Grid.h - 37 }, text: text)
    end

    # The first two are HUD and stay put; the rest annotate world features, so
    # they are placed through the camera and scroll with what they point at.
    def self.labels(camera)
      [UI.label({ x: Grid.w.fdiv(2), y: Grid.h - 10 }, text: 'Collision playground', size_px: UI::TEXT[:h1]),
       UI.label({ x: Grid.w.fdiv(2), y: Grid.h - 23 },
                text: 'WASD / arrows: move    Shift: sneak    F: lamp    B: boxes'),
       UI.label(camera.to_screen(x: 186, y: 155), text: 'Slide along the corner'),
       UI.label(camera.to_screen(x: 312, y: 131), text: '11 px doorway'),
       UI.label(camera.to_screen(x: 72, y: 83), text: '2 seconds here = death')]
    end
  end
end
