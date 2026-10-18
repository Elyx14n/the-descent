# frozen_string_literal: true

require 'tests/support/room_helpers'
require 'tests/support/keybind_helpers'

class RoomPreviewTests
  include RoomTestHelpers
  include KeybindTestHelpers

  def test_lamp_keeps_its_range_when_walking_into_southern_walls_and_door(args, assert)
    room = tiled_test_room(args)
    [[48, 110], [80, 110], [128, 80], [176, 80], [272, 110]].each do |x, y|
      player = Descent::Player.new(x: x, y: y)
      80.times { player.update_controls({ dx: 0, dy: -1 }, walls: room.collision_rects) }
      source = player.light_source
      feet = player.collision_rect
      assert.true! source[:y] > feet[:y] && source[:y] < feet[:y] + feet[:h]
      assert.true! Geometry.find_all_intersect_rect(feet, room.collision_rects).empty?
      light = Descent::Lighting.prepare(light_sources: [source],
                                        light_blockers: room.render_data[:light_blockers]).first
      distances = light[:sight_polygon].map { |point| Math.hypot(point[:x] - source[:x], point[:y] - source[:y]) }
      assert.true! distances.max > source[:radius] - 0.5
      assert.true!(distances.none? { |distance| distance < 0.5 })
    end
  end

  def test_fixed_lights_reuse_polygons_until_sources_or_colliders_change(args, assert)
    preview = preview_test_args(args)
    state = preview_test_tick(preview, 0)
    initial = Descent::RoomPreview.render(preview)[:light_polygons]
    room_ids = initial.reject { |light| light[:source][:id] == :player }.map(&:object_id)
    player_light = initial.find { |light| light[:source][:id] == :player }
    state[:player].x += 8
    preview_test_tick(preview, 9) # Flame animation, camera, and player movement.
    clear_room_test_outputs(preview)
    moved = Descent::RoomPreview.render(preview)[:light_polygons]
    assert.equal! moved.reject { |light| light[:source][:id] == :player }.map(&:object_id), room_ids
    moved_player = moved.find { |light| light[:source][:id] == :player }
    assert.false! moved_player.equal?(player_light)
    assert.false! moved_player[:sight_polygon] == player_light[:sight_polygon]

    state[:room].set_door_open(267, open: true)
    clear_room_test_outputs(preview)
    opened = Descent::RoomPreview.render(preview)[:light_polygons]
    assert.false! opened.reject { |light| light[:source][:id] == :player }.map(&:object_id) == room_ids
    state[:room].set_light_enabled(6, enabled: false)
    clear_room_test_outputs(preview)
    disabled = Descent::RoomPreview.render(preview)[:light_polygons]
    assert.equal! disabled.length, opened.length - 1
    assert.false!(disabled.any? { |light| light[:source][:id] == 6 })
    state[:room].lights.find { |light| light[:id] == 7 }[:radius] = 24
    clear_room_test_outputs(preview)
    changed = Descent::RoomPreview.render(preview)[:light_polygons]
    assert.equal! changed.find { |light| light[:source][:id] == 7 }[:source][:radius], 24
  end

  def test_fixed_light_cache_survives_invalid_export_and_resets_on_reload(args, assert)
    preview = preview_test_args(args)
    state = preview_test_tick(preview, 0)
    cache = state[:room_lighting]
    preview[:gtk].contents = '{'
    preview_test_tick(preview, 30)
    assert.true! state[:room_lighting].equal?(cache)
    preview[:gtk].contents = args.gtk.read_file('tiled/ritual_gate.json')
    preview_test_tick(preview, 60)
    assert.false! state[:room_lighting].equal?(cache)
    assert.false! state[:room_lighting][:polygons].first.equal?(cache[:polygons].first)
  end

  def test_player_polygon_is_prepared_without_debug_and_diagnostics_reuse_it(args, assert)
    preview = preview_test_args(args)
    state = preview_test_tick(preview, 0)
    clear_room_test_outputs(preview)
    frame = Descent::RoomPreview.render(preview)
    assert.equal! frame[:light_polygons].length, state[:room].lights.length + 1
    player_light = frame[:light_polygons].find { |light| light[:source][:id] == :player }
    assert.equal! player_light[:source][:radius], 64
    assert.equal! player_light[:source].values_at(:x, :y), state[:player].light_source.values_at(:x, :y)
    room_lights = frame[:light_polygons].reject { |light| light[:source][:id] == :player }
    assert.true!(room_lights.all? { |light| light[:source][:radius] == 48 })
    assert.true! player_light[:sight_polygon].length >= 3
    assert.true! preview[:outputs][Descent::Render::TARGET].lines.flatten.empty?

    state[:show_bounds] = true
    clear_room_test_outputs(preview)
    debug = Descent::RoomPreview.render(preview)
    assert.equal! debug[:light_polygons], frame[:light_polygons]
    red_lines = debug[:world_lines].select { |line| line.values_at(:r, :g, :b) == [255, 0, 0] }
    assert.equal! red_lines.length, player_light[:sight_polygon].length

    state[:show_bounds] = false
    state[:player].lamp_on = false
    clear_room_test_outputs(preview)
    remaining = Descent::RoomPreview.render(preview)[:light_polygons]
    assert.equal! remaining.length, state[:room].lights.length
    assert.false!(remaining.any? { |light| light[:source][:id] == :player })
  end

  def test_debug_geometry_uses_physics_borders_and_only_red_lamp_lines(args, assert)
    preview = preview_test_args(args)
    preview[:inputs][:keyboard] = keybind_test_keyboard(args, pressed: [:b])
    state = preview_test_tick(preview, 0)
    [false, true].each do |open|
      state[:room].set_door_open(267, open: open)
      clear_room_test_outputs(preview)
      frame = Descent::RoomPreview.render(preview)
      assert.true! frame[:world_lines].any?
      assert.true!(frame[:world_lines].all? { |line| line.values_at(:r, :g, :b) == [255, 0, 0] })
      physics = frame[:world_borders].select { |rect| rect.values_at(:r, :g, :b) == [235, 185, 94] }
      assert.equal! physics.map { |rect| rect.slice(:x, :y, :w, :h) }, state[:room].collision_rects
    end
  end

  def test_debug_lamp_polygon_is_closed_moves_and_uses_blockers_independent_of_camera(args, assert)
    preview = preview_test_args(args)
    preview[:inputs][:keyboard] = keybind_test_keyboard(args, pressed: [:b])
    state = preview_test_tick(preview, 0)
    target = preview[:outputs][Descent::Render::TARGET]
    previous = nil
    previous_offset = nil
    [[176, 176], [260, 90]].each do |x, y|
      state[:camera].follow(x: x, y: y)
      clear_room_test_outputs(preview)
      Descent::RoomPreview.render(preview)
      lines = target.lines.flatten.select { |line| line.values_at(:r, :g, :b) == [255, 0, 0] }
      assert.true! lines.length >= 3
      lines.each_with_index do |line, index|
        following = lines[(index + 1) % lines.length]
        assert.equal! line.values_at(:x2, :y2), following.values_at(:x, :y)
      end
      offset = state[:camera].to_screen(x: 0, y: 0)
      if previous
        assert.equal! lines.length, previous.length
        dx = offset[:x] - previous_offset[:x]
        dy = offset[:y] - previous_offset[:y]
        lines.zip(previous).each do |line, old|
          assert.true! ((line[:x] - old[:x]) - dx).abs < 0.000001
          assert.true! ((line[:x2] - old[:x2]) - dx).abs < 0.000001
          assert.true! ((line[:y] - old[:y]) - dy).abs < 0.000001
          assert.true! ((line[:y2] - old[:y2]) - dy).abs < 0.000001
        end
      end
      previous = lines
      previous_offset = offset
    end

    state[:player].x += 8
    clear_room_test_outputs(preview)
    Descent::RoomPreview.render(preview)
    moved = target.lines.flatten.select { |line| line.values_at(:r, :g, :b) == [255, 0, 0] }
    assert.false! moved == previous

    state[:player].lamp_on = false
    clear_room_test_outputs(preview)
    Descent::RoomPreview.render(preview)
    assert.false!(target.lines.flatten.any? { |line| line.values_at(:r, :g, :b) == [255, 0, 0] })
    assert.true! target.lines.flatten.empty?
    assert.true!(target.primitives.flatten.any? { |sprite| sprite.values_at(:r, :g, :b) == [0, 255, 0] })
  end

  def test_debug_emitter_markers_follow_enabled_sources_and_hide_with_overlay(args, assert)
    preview = preview_test_args(args)
    preview[:inputs][:keyboard] = keybind_test_keyboard(args, pressed: [:b])
    state = preview_test_tick(preview, 0)
    light = state[:room].lights.find { |entry| entry[:id] == 6 }
    state[:camera].follow(x: light[:x], y: light[:y])
    source = state[:room].render_data[:light_sources].find { |entry| entry[:id] == light[:id] }
    marker = state[:camera].to_draw_space(
      { x: source[:x] - 2, y: source[:y] - 2, w: 4, h: 4, path: :solid, r: 0, g: 255, b: 0 }
    )
    clear_room_test_outputs(preview)
    Descent::RoomPreview.render(preview)
    target = preview[:outputs][Descent::Render::TARGET]
    assert.true! target.primitives.flatten.include?(marker)

    state[:room].set_light_enabled(6, enabled: false)
    clear_room_test_outputs(preview)
    Descent::RoomPreview.render(preview)
    assert.false! target.primitives.flatten.include?(marker)
    assert.true! target.lines.flatten.any?

    state[:show_bounds] = false
    clear_room_test_outputs(preview)
    Descent::RoomPreview.render(preview)
    assert.true! target.lines.flatten.empty?
    assert.false!(target.primitives.flatten.any? { |sprite| sprite.values_at(:r, :g, :b) == [0, 255, 0] })
  end

  def test_preview_reveals_south_door_and_cap_then_reload_restores_authored_artwork(args, assert)
    preview = preview_test_args(args)
    state = preview_test_tick(preview, 0)
    room = state[:room]
    door = room.doors.find { |entry| entry[:id] == 267 }
    closed = door[:parts].map { |part| part[:sprite].dup }
    state[:player].reset(x: 176, y: 48)
    out_ticks = Descent::ForegroundFade::FADE_OUT_TICKS
    (1..out_ticks).each { |tick| preview_test_tick(preview, tick) }
    opacity = (Descent::ForegroundFade.multiplier(door[:closed_colliders].first,
                                                  { x: 176, y: 48 }, type: :door) * 255).round
    closed.each do |sprite|
      assert.true! preview_artwork_drawn?(preview, state[:camera].to_draw_space(sprite.merge(a: opacity)))
    end
    assert.equal! door[:parts].map { |part| part[:sprite] }, closed
    unit = room.fade_units.find { |candidate| candidate[:base].equal?(door[:sprite]) }
    history = state[:fade_state][unit.object_id]
    room.set_door_open(267, open: true)
    assert.equal! unit[:colliders], []
    preview_test_tick(preview, out_ticks + 1)
    assert.true! state[:fade_state][unit.object_id].equal?(history)
    restoring = (history[:opacity] * 255).round
    assert.true! restoring > opacity && restoring < 255
    door[:parts].each do |part|
      assert.true! preview_artwork_drawn?(preview, state[:camera].to_draw_space(part[:sprite].merge(a: restoring)))
    end
    preview[:inputs][:keyboard] = keybind_test_keyboard(args, pressed: [:r])
    state = preview_test_tick(preview, out_ticks + 2)
    assert.true!(state[:fade_state].values.all? { |entry| entry[:opacity] >= 1.0 })
    assert.equal! state[:player].y, 176
    assert.equal! state[:room].doors.find { |entry| entry[:id] == 267 }[:parts].map { |part| part[:sprite] }, closed
    # Spawn's camera culls the southern bases. Inspect them with a lower camera
    # while the reset actor remains far enough away to leave them fully opaque.
    state[:camera].follow(x: 176, y: 90)
    clear_room_test_outputs(preview)
    Descent::RoomPreview.render(preview)
    closed.each do |sprite|
      assert.true! preview_artwork_drawn?(preview, state[:camera].to_draw_space(sprite))
    end
  end

  def preview_artwork_drawn?(args, expected)
    args[:outputs][Descent::Render::TARGET].primitives.flatten.any? do |drawn|
      drawn.except(:r, :g, :b) == expected.except(:r, :g, :b)
    end
  end

  # Replace only file I/O for preview tests; parsing still runs in DragonRuby.
  class PreviewTestRuntime
    attr_accessor :contents, :production
    attr_reader :reads, :parses, :paths

    def initialize(gtk, contents)
      @gtk = gtk
      @contents = contents
      @production = false
      @reads = 0
      @parses = 0
      @paths = []
    end

    def read_file(path)
      @reads += 1
      @paths << path
      @contents
    end

    def parse_json(contents)
      @parses += 1
      @gtk.parse_json(contents)
    end

    def current_framerate
      @gtk.current_framerate
    end

    def production?
      @production
    end
  end

  def preview_test_args(args, contents: args.gtk.read_file('tiled/ritual_gate.json'))
    { state: { tick_count: 0 }, outputs: args.outputs,
      inputs: { keyboard: keybind_test_keyboard(args) }, gtk: PreviewTestRuntime.new(args.gtk, contents) }
  end

  def preview_test_tick(args, tick)
    args[:state][:tick_count] = tick
    clear_room_test_outputs(args)
    Descent::RoomPreview.tick(args)
    args[:state][:room_preview]
  end

  def test_room_preview_uses_spawn_reuses_loaded_data_and_renders_through_camera(args, assert)
    args.state.room_preview = { show_bounds: true }
    args.state.room_preview[:player] = nil
    clear_room_test_outputs(args)
    Descent::RoomPreview.tick(args)
    player = args.state.room_preview[:player]
    room = args.state.room_preview[:room]
    camera = args.state.room_preview[:camera]
    target = args.outputs[Descent::Render::TARGET]
    assert.equal! [player.x, player.y], [176, 176]
    assert.equal! [target.w, target.h], [320, 180]
    sprite = target.primitives.flatten.find { |primitive| primitive[:path] == 'sprites/player_idle_lamp_on.png' }
    assert.equal! sprite.except(:r, :g, :b), camera.to_draw_space(player.sprite_to_primitive).except(:r, :g, :b)
    assert.equal! sprite.values_at(:w, :h), [64, 64]
    foot_border = camera.to_screen_space(player.collision_rect.merge(r: 90, g: 255, b: 160))
    assert.true! target.borders.flatten.include?(foot_border)
    blits = args.outputs.primitives.flatten.select { |primitive| primitive[:path] == :scene }
    assert.equal! blits, [camera.viewport.merge(path: Descent::Render::TARGET)]
    clear_room_test_outputs(args)
    Descent::RoomPreview.tick(args)
    assert.true! args.state.room_preview[:room].equal?(room)
    assert.true! args.state.room_preview[:player].equal?(player)
    player.x = 100
    Descent::RoomPreview.reload(args)
    assert.equal! [args.state.room_preview[:player].x, args.state.room_preview[:player].y], [176, 176]
    assert.false! args.state.room_preview[:player].equal?(player)
    assert.equal! args.state.room_preview[:player].collision_rect[:w], 8
    assert.false! args.state.room_preview[:room].equal?(room)
  end

  def test_preview_reloads_changed_contents_resets_play_and_preserves_toggles(args, assert)
    original = args.gtk.read_file('tiled/ritual_gate.json')
    preview = preview_test_args(args, contents: "#{original} ")
    preview[:inputs][:keyboard] = keybind_test_keyboard(args, pressed: [:b])
    state = preview_test_tick(preview, 0)
    room = state[:room]
    player = state[:player]
    player.x = 100
    player.toggle_lamp
    room.set_door_open(218, open: true)
    room.set_light_enabled(6, enabled: false)
    preview[:inputs][:keyboard] = keybind_test_keyboard(args)
    preview[:gtk].contents = "#{original}\n" # Same byte count; contents determine changes.
    assert.true! preview_test_tick(preview, 29)[:room].equal?(room)
    assert.equal! preview[:gtk].reads, 1
    state = preview_test_tick(preview, 30)
    assert.false! state[:room].equal?(room)
    assert.false! state[:player].equal?(player)
    assert.equal! state[:player].x, 176
    assert.true! state[:player].lamp_on
    assert.false! state[:room].doors.find { |door| door[:id] == 218 }[:open]
    assert.true! state[:room].lights.find { |light| light[:id] == 6 }[:enabled]
    assert.true! state[:show_bounds]
    assert.equal! preview[:gtk].parses, 2
    replacement = state[:room]
    assert.true! preview_test_tick(preview, 60)[:room].equal?(replacement)
    assert.equal! preview[:gtk].reads, 3
    assert.equal! preview[:gtk].parses, 2
  end

  def test_preview_retains_valid_room_during_invalid_exports_and_recovers(args, assert)
    preview = preview_test_args(args)
    state = preview_test_tick(preview, 0)
    room, player, camera = state.values_at(:room, :player, :camera)
    room.set_light_enabled(6, enabled: false)
    preview[:gtk].contents = '{'
    state = preview_test_tick(preview, 30)
    assert.true! state[:room].equal?(room)
    assert.true! state[:player].equal?(player)
    assert.true! state[:camera].equal?(camera)
    assert.false! state[:room].lights.find { |light| light[:id] == 6 }[:enabled]
    assert.true! state[:reload_error].is_a?(String)
    assert.true!(preview[:outputs].primitives.flatten.any? { |primitive| primitive[:text]&.start_with?('Reload:') })
    preview_test_tick(preview, 60)
    assert.equal! preview[:gtk].parses, 2 # Failed contents are not parsed on every poll.
    preview[:gtk].contents = "#{args.gtk.read_file('tiled/ritual_gate.json')}\n"
    state = preview_test_tick(preview, 90)
    assert.false! state[:room].equal?(room)
    assert.equal! state[:reload_error], nil
  end

  def test_preview_missing_initial_export_can_recover_and_r_forces_rebuild(args, assert)
    preview = preview_test_args(args, contents: nil)
    state = preview_test_tick(preview, 0)
    assert.equal! state[:room], nil
    assert.true! state[:reload_error].include?('Cannot read Tiled map')
    preview[:gtk].contents = args.gtk.read_file('tiled/ritual_gate.json')
    state = preview_test_tick(preview, 30)
    assert.true! state[:room].is_a?(Descent::Room)
    room = state[:room]
    preview[:inputs][:keyboard] = keybind_test_keyboard(args, pressed: [:r])
    assert.false! preview_test_tick(preview, 31)[:room].equal?(room)
    assert.equal! preview[:gtk].parses, 2
  end

  def test_preview_rejects_invalid_room_data_without_replacing_the_current_room(args, assert)
    preview = preview_test_args(args)
    room = preview_test_tick(preview, 0)[:room]
    preview[:gtk].contents = '{"type":"map","orientation":"orthogonal","infinite":false}'
    state = preview_test_tick(preview, 30)
    assert.true! state[:room].equal?(room)
    assert.true! state[:reload_error].include?('tilewidth')
  end

  def test_preview_does_not_poll_in_production_but_allows_explicit_reload(args, assert)
    preview = preview_test_args(args)
    preview[:gtk].production = true
    room = preview_test_tick(preview, 0)[:room]
    preview[:gtk].contents += "\n"
    assert.true! preview_test_tick(preview, 60)[:room].equal?(room)
    assert.equal! preview[:gtk].reads, 1
    preview[:inputs][:keyboard] = keybind_test_keyboard(args, pressed: [:r])
    assert.false! preview_test_tick(preview, 61)[:room].equal?(room)
  end

  def test_preview_room_selection_reloads_even_when_export_contents_match(args, assert)
    preview = preview_test_args(args)
    room = preview_test_tick(preview, 0)[:room]
    clear_room_test_outputs(preview)
    Descent::RoomPreview.tick(preview, path: 'tiled/another_room.json')
    assert.false! preview[:state][:room_preview][:room].equal?(room)
    assert.equal! preview[:gtk].paths.last, 'tiled/another_room.json'
  end

  def test_preview_drives_light_animation_and_e_only_toggles_on_press(args, assert)
    preview = preview_test_args(args)
    state = preview_test_tick(preview, 0)
    light = state[:room].lights.find { |entry| entry[:id] == 6 }
    sprite = light[:sprite]
    assert.equal! sprite[:source_x], 32
    state[:player].reset(x: 240, y: 220)
    preview_test_tick(preview, 9)
    assert.equal! sprite[:source_x], 64
    preview[:inputs][:keyboard] = keybind_test_keyboard(args, pressed: [:e])
    preview_test_tick(preview, 10)
    assert.false! light[:enabled]
    assert.equal! sprite[:source_x], 0
    preview[:inputs][:keyboard] = keybind_test_keyboard(args, held: [:e])
    preview_test_tick(preview, 18)
    assert.false! light[:enabled]
    assert.equal! sprite[:source_x], 0
    preview[:inputs][:keyboard] = keybind_test_keyboard(args, pressed: [:e])
    preview_test_tick(preview, 27)
    assert.true! light[:enabled]
    assert.equal! sprite[:source_x], 128
    assert.true! preview_artwork_drawn?(preview, state[:camera].to_draw_space(sprite))
  end
end
