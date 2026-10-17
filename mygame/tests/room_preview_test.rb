# frozen_string_literal: true

require 'tests/support/room_helpers'
require 'tests/support/keybind_helpers'

class RoomPreviewTests
  include RoomTestHelpers
  include KeybindTestHelpers

  def test_preview_reveals_south_door_and_cap_then_reload_restores_authored_artwork(args, assert)
    preview = preview_test_args(args)
    state = preview_test_tick(preview, 0)
    room = state[:room]
    door = room.doors.find { |entry| entry[:id] == 267 }
    closed = door[:parts].map { |part| part[:sprite].dup }
    state[:player].reset(x: 176, y: 72)
    out_ticks = Descent::ForegroundFade::FADE_OUT_TICKS
    (1..out_ticks).each { |tick| preview_test_tick(preview, tick) }
    opacity = (Descent::ForegroundFade.multiplier({ x: 160, y: 32, w: 32, h: 32 },
                                                  { x: 176, y: 72 }, type: :door) * 255).round
    closed.each do |sprite|
      assert.true! preview[:outputs][Descent::Render::TARGET].primitives.flatten.include?(
        state[:camera].to_draw_space(sprite.merge(a: opacity))
      )
    end
    assert.equal! door[:parts].map { |part| part[:sprite] }, closed
    room.set_door_open(267, open: true)
    preview_test_tick(preview, out_ticks + 1)
    door[:parts].each do |part|
      assert.true! preview[:outputs][Descent::Render::TARGET].primitives.flatten.include?(
        state[:camera].to_draw_space(part[:sprite].merge(a: opacity))
      )
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
      assert.true! preview[:outputs][Descent::Render::TARGET].primitives.flatten.include?(
        state[:camera].to_draw_space(sprite)
      )
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

    def get_pixels(path)
      @gtk.get_pixels(path)
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
    assert.equal! sprite, camera.to_draw_space(player.sprite_to_primitive)
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
    assert.true! preview[:outputs][Descent::Render::TARGET].primitives.flatten.include?(
      state[:camera].to_draw_space(sprite)
    )
  end
end
