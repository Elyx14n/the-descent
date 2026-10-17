# frozen_string_literal: true

# Opt-in: bin/rake test tests/render_benchmark.rb HEADLESS=1
# Timings cover Ruby preparation/submission, not engine drawing or GPU work.
require 'tests/support/room_helpers'

class RenderBenchmarkTests
  include RoomTestHelpers

  ITERATIONS = 1200
  SAMPLES = 7
  OPERATIONS = %i[room_data camera animations fade frame].freeze

  def test_render_preparation_benchmark(args, assert)
    [1, 3].each do |copies|
      OPERATIONS.each do |operation|
        context = benchmark_context(args, copies)
        120.times { |tick| benchmark_step(args, context, operation, tick) }
        samples = Array.new(SAMPLES) do
          # Reset state outside the timer; each sample starts identically.
          context = benchmark_context(args, copies)
          GC.start
          started = Time.now
          ITERATIONS.times { |tick| benchmark_step(args, context, operation, tick) }
          (Time.now - started) * 1_000_000 / ITERATIONS
        end
        ordered = samples.sort
        puts "RENDER_BENCH copies=#{copies} operation=#{operation} iterations=#{ITERATIONS} " \
             "median_us=#{ordered[SAMPLES.div(2)].round(3)} " \
             "min_us=#{ordered.first.round(3)} max_us=#{ordered.last.round(3)} " \
             "samples_us=#{samples.map { |sample| sample.round(3) }.join(',')}"
        assert.true!(samples.all?(&:positive?))
      end
    end
  end

  def benchmark_context(args, copies)
    room = tiled_test_room(args, benchmark_map(args, copies))
    camera = Descent::Camera.new(bounds: room.bounds)
    player = Descent::Player.new(x: 144, y: 68)
    camera.follow(x: player.x, y: player.y)
    actor = player.render_data
    frame = room.render_data
    frame[:groups] << actor
    groups = frame[:groups].each_with_index.sort_by { |group, index| [-group[:depth], index] }
    world = frame[:floor] + groups.flat_map { |group, _index| group[:sprites] } + frame[:ceiling]
    puts_counts(room, world, camera, copies)
    { room: room, camera: camera, player: player, actor: actor, world: world,
      visible: camera.find_all_intersect_viewport(world), fade_state: {} }
  end

  def puts_counts(room, world, camera, copies)
    @reported_counts ||= {}
    return if @reported_counts[copies]

    @reported_counts[copies] = true
    puts "RENDER_BENCH_COUNTS copies=#{copies} sprites=#{world.length} " \
         "visible=#{camera.find_all_intersect_viewport(world).length} " \
         "units=#{room.fade_units.length} lights=#{room.lights.length} " \
         "edges=#{world.sum { |sprite| sprite.fetch(:occlusion_polygons, []).sum(&:length) }}"
  end

  def benchmark_step(args, context, operation, tick)
    room = context[:room]
    camera = context[:camera]
    case operation
    when :room_data
      room.render_data
    when :camera
      camera.follow(x: 160 + (tick % 240), y: 160 + (tick % 90))
      camera.to_draw_space(context[:visible])
    when :animations
      room.update_animations(tick: tick)
    when :fade
      Descent::ForegroundFade.apply(
        context[:world],
        units: room.fade_units, actors: [context[:actor][:fade_actor]],
        viewport: camera.viewport_world, state: context[:fade_state], tick: tick
      )
    when :frame
      benchmark_frame(args, context, tick)
    end
  end

  def benchmark_frame(args, context, tick)
    room = context[:room]
    player = context[:player]
    phase = tick % 120
    # Stationary view, south-wall fade/reversal, then a repeatable camera pan.
    if phase < 30
      player.reset(**room.spawn)
    elsif phase < 90
      player.reset(x: 144 + ((phase % 3) * 16), y: 68 + ((phase - 30) % 30))
    else
      player.reset(x: 160 + ((phase - 90) * room.bounds[:w].fdiv(30)), y: 176)
    end
    room.set_door_open(267, open: phase == 40) if [0, 40, 80].include?(phase)
    room.set_light_enabled(6, enabled: phase != 40) if [0, 40, 80].include?(phase)
    room.update_animations(tick: tick)
    context[:camera].follow(x: player.x, y: player.y)
    frame = room.render_data
    actor = player.render_data
    frame[:groups] << actor
    frame[:fade_actors] = [actor[:fade_actor]]
    clear_room_test_outputs(args)
    Descent::Render.draw(args, frame: frame, camera: context[:camera],
                               fade_state: context[:fade_state], tick: tick)
  end

  # Three adjacent copies increase total geometry while keeping viewport size
  # fixed. This is a workload fixture, not a playable map or map-assembly API.
  def benchmark_map(args, copies)
    data = tiled_test_map(args)
    return data if copies == 1

    width = data['width']
    stride = data['nextobjectid']
    data['width'] *= copies
    data['layers'].each_with_index do |layer, index|
      if layer['type'] == 'tilelayer'
        layer['data'] = layer['data'].each_slice(width).flat_map { |row| row * copies }
        layer['width'] *= copies
      else
        (1...copies).each do |copy|
          extra = tiled_test_map(args)['layers'][index]['objects'].reject { |entry| entry['type'] == 'Spawn' }
          extra.each do |entry|
            entry['x'] += copy * width * data['tilewidth']
            entry['id'] += copy * stride
            entry.fetch('properties', []).each do |property|
              property['value'] += copy * stride if property['type'] == 'object' && property['value'].positive?
            end
          end
          layer['objects'].concat(extra)
        end
      end
    end
    data
  end
end
