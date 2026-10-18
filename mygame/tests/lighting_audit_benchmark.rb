# frozen_string_literal: true

# Opt-in: bin/rake test tests/lighting_audit_benchmark.rb HEADLESS=1
# CPU stages and exact-input reuse opportunities; no production cache is added.
require 'tests/support/lighting_audit_helpers'

class LightingAuditBenchmarkTests
  include LightingAuditHelpers

  def test_many_light_pipeline_audit(args, assert)
    room = tiled_test_room(args)
    player = Descent::Player.new
    player.reset(x: 248, y: 220)
    camera = Descent::Camera.new(bounds: room.bounds)
    camera.follow(x: player.x, y: player.y)
    frame = audit_frame(room, player)
    sources = audit_sources(frame)
    inputs = audit_inputs(frame, sources)
    polygons = audit_cast(inputs)
    lines = audit_lines(polygons)
    visible_inputs = inputs.select do |input|
      Geometry.intersect_rect?(audit_light_bounds(input[:source]), camera.viewport_world)
    end
    edge_count = frame[:light_blockers].sum { |blocker| blocker[:edges].length }
    puts "LIGHT_AUDIT_CONFIG hd=#{Grid.hd?} sources=#{sources.length} room_sources=#{room.lights.length} " \
         "blockers=#{frame[:light_blockers].length} edges=#{edge_count} " \
         "visible_influence_sources=#{visible_inputs.length} outline_lines=#{lines.length}"
    frame[:light_sources].each { |source| puts "LIGHT_AUDIT_SOURCE #{source}" }
    inputs.each_with_index do |input, index|
      source = input[:source]
      buckets = Descent::Raycasting.send(:segment_angle_buckets, source[:x], source[:y], input[:segments])
      candidates = polygons[index].sum do |point|
        buckets[Descent::Raycasting.send(:angle_bucket, point[:angle])].length
      end
      unique_angles = polygons[index].map { |point| point[:angle] }.uniq
      unique_candidates = unique_angles.sum { |angle| buckets[Descent::Raycasting.send(:angle_bucket, angle)].length }
      puts "LIGHT_AUDIT_COUNTS id=#{source[:id]} segments=#{input[:segments].length} rays=#{polygons[index].length} " \
           "candidate_pairs=#{candidates} bucket_entries=#{buckets.sum(&:length)} " \
           "unique_angles=#{unique_angles.length} unique_candidate_pairs=#{unique_candidates}"
      measure("source_#{source[:id]}") { audit_cast([input]) }
    end
    measure('room_data') { room.render_data }
    measure('select_convert_all') { audit_inputs(frame, sources) }
    measure('select_convert_shared') { audit_inputs(frame, sources, shared_segments: true) }
    assert.equal! audit_inputs(frame, sources, shared_segments: true), inputs
    measure('bucket_build_all') do
      inputs.each do |input|
        source = input[:source]
        Descent::Raycasting.send(:segment_angle_buckets, source[:x], source[:y], input[:segments])
      end
    end
    measure('endpoint_angles_all') do
      inputs.each do |input|
        source = input[:source]
        points = input[:segments].flat_map { |segment| [segment[:a], segment[:b]] }
        points.uniq { |point| [point[:x], point[:y]] }.flat_map do |point|
          angle = Math.atan2(point[:y] - source[:y], point[:x] - source[:x])
          [angle - 0.00001, angle, angle + 0.00001]
        end
      end
    end
    measure('cast_all') { audit_cast(inputs) }
    measure('cast_influence_visible') { audit_cast(visible_inputs) }
    measure('outline_all') { audit_lines(polygons) }
    frame[:world_lines] = lines
    measure('render_existing_outlines') do
      clear_room_test_outputs(args)
      Descent::Render.draw(args, frame: frame, camera: camera, fade_state: {}, tick: 0)
    end
    frame[:world_lines] = []
    measure('render_without_outlines') do
      clear_room_test_outputs(args)
      Descent::Render.draw(args, frame: frame, camera: camera, fade_state: {}, tick: 0)
    end
    measure('complete_cpu_frame') do
      clear_room_test_outputs(args)
      live_frame = audit_frame(room, player)
      live_frame[:world_lines] = audit_lines(audit_cast(audit_inputs(live_frame)))
      Descent::Render.draw(args, frame: live_frame, camera: camera, fade_state: {}, tick: 0)
    end
    [16, 32].each do |count|
      repeated = Array.new(count) { |index| inputs[index % inputs.length] }
      measure("cast_repeated_positions_#{count}") { audit_cast(repeated) }
    end
    audit_reuse_trace(args, moving: false)
    audit_reuse_trace(args, moving: true)
    audit_reuse_trace(args, moving: true, interactions: true)
    [[176, 176], [176, 72], [280, 220], [248, 220]].each do |x, y|
      player.reset(x: x, y: y)
      camera.follow(x: x, y: y)
      influencing = audit_sources(audit_frame(room, player)).select do |source|
        Geometry.intersect_rect?(audit_light_bounds(source), camera.viewport_world)
      end
      puts "LIGHT_AUDIT_VIEW x=#{x} y=#{y} influencing_ids=#{influencing.map { |source| source[:id] }}"
    end
    assert.equal! polygons.length, sources.length
    assert.true!(polygons.all? { |polygon| polygon.length >= 3 })
  end

  def measure(name)
    yield
    samples = Array.new(7) do
      GC.start
      started = Time.now
      # Keep native yield calls in the timed region rather than capturing a Proc.
      3.times { yield } # rubocop:disable Style/ExplicitBlockArgument
      (Time.now - started) * 1000 / 3
    end
    puts "LIGHT_AUDIT_STAGE name=#{name} median_ms=#{samples.sort[3].round(3)} " \
         "samples_ms=#{samples.map { |sample| sample.round(3) }.join(',')}"
  end

  def audit_reuse_trace(args, moving:, interactions: false)
    room = tiled_test_room(args)
    player = Descent::Player.new
    player.reset(x: 248, y: 220)
    previous = {}
    misses = {}
    total = 0
    door = room.doors.find { |entry| !entry[:properties].fetch('locked', false) }
    180.times do |tick|
      player.x = 240 + ((tick % 40) * 0.5) if moving
      if interactions
        room.set_door_open(door[:id], open: true) if tick == 90 && door
        room.set_light_enabled(room.lights.first[:id], enabled: false) if tick == 120
        room.set_light_enabled(room.lights.first[:id], enabled: true) if tick == 150
      end
      room.update_animations(tick: tick)
      audit_inputs(audit_frame(room, player)).each do |input|
        id = input[:source][:id]
        # Exact content comparison is only an audit oracle, not a proposed hot-path key.
        signature = input[:segments].to_s
        misses[id] = misses.fetch(id, 0) + 1 if previous[id] != signature
        previous[id] = signature
        total += 1
      end
    end
    puts "LIGHT_AUDIT_REUSE moving=#{moving} interactions=#{interactions} frames=180 queries=#{total} " \
         "changed_inputs=#{misses.values.sum} per_source=#{misses}"
  end
end
