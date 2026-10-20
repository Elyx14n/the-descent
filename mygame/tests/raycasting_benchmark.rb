# frozen_string_literal: true

# Opt-in: bin/rake test tests/raycasting_benchmark.rb HEADLESS=1
# Measures Ruby preparation, not engine/GPU drawing or displayed FPS.
require 'tests/support/room_helpers'

class RaycastingBenchmarkTests
  include RoomTestHelpers

  SAMPLES = 5
  ITERATIONS = 3
  OPERATIONS = %i[room_data polygon_full polygon_local preview_off preview_on].freeze

  def test_lamp_raycasting_benchmark(args, assert)
    puts "RAYCAST_CONFIG hd=#{Grid.hd?} render_scale=#{Grid.render_scale}"
    room = tiled_test_room(args)
    player = Descent::Player.new
    camera = Descent::Camera.new(**room.spawn.slice(:x, :y))
    [[176, 176], [176, 72], [280, 220], [248, 220]].each do |x, y|
      player.reset(x: x, y: y)
      camera.follow(x: x, y: y)
      context = { room: room, player: player, camera: camera, fade_state: {}, show_bounds: false }
      args.state.room_preview = context
      lamp = player.light_source
      corners = [[lamp[:x] - lamp[:radius], lamp[:y] - lamp[:radius]],
                 [lamp[:x] + lamp[:radius], lamp[:y] - lamp[:radius]],
                 [lamp[:x] + lamp[:radius], lamp[:y] + lamp[:radius]],
                 [lamp[:x] - lamp[:radius], lamp[:y] + lamp[:radius]]].map { |px, py| { x: px, y: py } }
      border = corners.each_with_index.map { |point, index| { a: point, b: corners[(index + 1) % corners.length] } }
      bounds = { x: lamp[:x] - lamp[:radius], y: lamp[:y] - lamp[:radius],
                 w: lamp[:radius] * 2, h: lamp[:radius] * 2 }
      blockers = room.render_data[:light_blockers]
      all_segments = benchmark_segments(blockers) + border
      local_blockers = blockers.select do |blocker|
        Geometry.intersect_rect?(blocker.fetch(:bounds, blocker[:sprite]), bounds)
      end
      local_segments = benchmark_segments(local_blockers) + border
      endpoints = all_segments.flat_map { |segment| [segment[:a], segment[:b]] }.uniq.length
      puts "RAYCAST_COUNTS x=#{x} y=#{y} full_segments=#{all_segments.length} " \
           "local_segments=#{local_segments.length} " \
           "full_rays=#{endpoints * 3} " \
           "naive_pair_checks=#{all_segments.length * endpoints * 3}"
      OPERATIONS.each do |operation|
        benchmark_operation(args, context, operation, lamp, all_segments, local_segments)
        samples = Array.new(SAMPLES) do
          GC.start
          started = Time.now
          ITERATIONS.times do
            benchmark_operation(args, context, operation, lamp, all_segments, local_segments)
          end
          (Time.now - started) * 1000 / ITERATIONS
        end
        puts "RAYCAST_BENCH x=#{x} y=#{y} operation=#{operation} " \
             "median_ms=#{samples.sort[SAMPLES.div(2)].round(3)} " \
             "samples_ms=#{samples.map { |sample| sample.round(3) }.join(',')}"
        assert.true!(samples.all?(&:positive?))
      end
    end
  end

  def benchmark_segments(blockers)
    blockers.flat_map do |blocker|
      blocker[:edges].map do |edge|
        { a: { x: edge[:x], y: edge[:y] }, b: { x: edge[:x2], y: edge[:y2] } }
      end
    end
  end

  def benchmark_operation(args, context, operation, lamp, all_segments, local_segments)
    case operation
    when :room_data
      context[:room].render_data
    when :polygon_full, :polygon_local
      segments = operation == :polygon_full ? all_segments : local_segments
      Descent::Raycasting.get_sight_polygon(lamp[:x], lamp[:y], segments: segments)
    when :preview_off, :preview_on
      context[:show_bounds] = operation == :preview_on
      clear_room_test_outputs(args)
      Descent::RoomPreview.render(args)
    end
  end
end
