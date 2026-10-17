# frozen_string_literal: true

require 'tests/support/room_helpers'

class TiledOpacityTests
  include RoomTestHelpers

  def test_l_shaped_tiles_only_fade_where_a_broad_occupied_span_crosses_the_actor(args, assert)
    data = tiled_test_map(args)
    occluders = occluder_fixture(args)
    # Generated L: broad top arm, narrow right arm, empty lower-left corner.
    record = occluders['tilesets'].find { |entry| entry['image'] == 'sprites/environment_tilesheet.png' }['tiles'][20]
    record['polygons'] = [[[0, 26], [26, 26], [26, 0], [32, 0], [32, 32], [0, 32]]]
    record['bounds'] = [0, 0, 32, 32]
    decoded = Descent::TiledDeserializer.deserialize(data, path: 'tiled/ritual_gate.json', occluders: occluders)
    cap = decoded[:collections][:objects].find { |entry| entry[:id] == 193 }[:sprite].merge(x: 32, y: 64)
    assert.equal! cap[:occlusion_bounds], { x: 0, y: 0, w: 32, h: 32 }
    base = { x: 32, y: 32, w: 32, h: 32, path: :solid }
    unit = { type: :wall, base: base, footprint: base, sprites: [base, cap] }
    positions = [40, 60]
    [false, true].each do |flip_h|
      [false, true].each do |flip_v|
        cap[:flip_horizontally] = flip_h
        cap[:flip_vertically] = flip_v
        # The broad arm must overlap with positive height, not merely touch the body.
        clear_y = flip_v ? 70 : 64
        blocked_y = flip_v ? clear_y - 0.01 : clear_y + 0.01
        positions.each do |x|
          [[clear_y, false], [blocked_y, true]].each do |y, should_fade|
            actor = Descent::Player.new(x: x, y: y).render_data[:fade_actor]
            drawn = Descent::ForegroundFade.apply([actor[:sprite], base, cap], units: [unit], actors: [actor],
                                                                               viewport: { x: 0, y: 0, w: 320, h: 180 })
            assert.equal! drawn.last[:a] < 255, should_fade
          end
        end
      end
    end
  end

  def test_generated_disconnected_polygons_do_not_bridge_the_gap(args, assert)
    occluders = occluder_fixture(args)
    record = occluders['tilesets'].find { |entry| entry['image'] == 'sprites/environment_tilesheet.png' }['tiles'][20]
    record['polygons'] = [[[0, 0], [6, 0], [6, 32], [0, 32]], [[26, 0], [32, 0], [32, 32], [26, 32]]]
    record['bounds'] = [0, 0, 32, 32]
    decoded = Descent::TiledDeserializer.deserialize(tiled_test_map(args), path: 'tiled/ritual_gate.json',
                                                                           occluders: occluders)
    sprite = decoded[:collections][:objects].find { |entry| entry[:id] == 193 }[:sprite].merge(x: 32, y: 64)
    assert.equal! sprite[:occlusion_polygons].length, 2
    actor = Descent::Player.new(x: 48, y: 64).render_data[:fade_actor]
    base = { x: 32, y: 32, w: 32, h: 32, path: :solid }
    unit = { type: :wall, base: base, footprint: base, sprites: [base, sprite] }
    drawn = Descent::ForegroundFade.apply([actor[:sprite], base, sprite], units: [unit], actors: [actor],
                                                                          viewport: { x: 0, y: 0, w: 320, h: 180 })
    assert.equal! drawn.last[:a], 255
  end

  def test_generated_bounds_follow_scale_and_flips_and_explicit_empty_tiles_stay_empty(args, assert)
    data = tiled_test_map(args)
    occluders = occluder_fixture(args)
    records = occluders['tilesets'].find { |entry| entry['image'] == 'sprites/environment_tilesheet.png' }['tiles']
    records[20] = { 'polygons' => [[[2, 24], [5, 24], [5, 27], [2, 27]]],
                    'bounds' => [2, 24, 3, 3] }
    records[24] = { 'polygons' => [], 'bounds' => nil }
    object = data['layers'].find { |layer| layer['name'] == 'Walls' }['objects'].find { |entry| entry['id'] == 193 }
    object['width'] = 64
    object['height'] = 48
    object['gid'] |= Descent::TiledDeserializer::HORIZONTAL | Descent::TiledDeserializer::VERTICAL
    decoded = Descent::TiledDeserializer.deserialize(data, path: 'tiled/ritual_gate.json', occluders: occluders)
    wall = decoded[:collections][:objects].find { |entry| entry[:id] == 193 }[:sprite]
    assert.equal! wall[:occlusion_bounds], { x: 2, y: 24, w: 3, h: 3 }
    assert.equal! Descent::SpriteGeometry.occupied_bounds(wall), { x: 54, y: 103.5, w: 6, h: 4.5 }
    empty = decoded[:collections][:objects].find { |entry| entry[:id] == 166 }[:sprite]
    assert.equal! Descent::SpriteGeometry.occupied_bounds(empty), nil
    assert.equal! Descent::SpriteGeometry.polygons(empty), []
  end

  def test_door_variants_replace_generated_geometry_without_changing_the_supporting_footprint(args, assert)
    room = tiled_test_room(args)
    [216, 217].each do |id|
      door = room.doors.find { |entry| entry[:id] == id }
      sprite = door[:sprite]
      unit = room.fade_units.find { |candidate| candidate[:base].equal?(sprite) }
      footprint = unit[:footprint].dup
      closed = sprite[:occlusion_bounds].dup
      closed_polygons = sprite[:occlusion_polygons]
      open_bounds = door[:parts].first[:open_sprite][:occlusion_bounds]
      assert.equal! closed[:w], 6
      room.set_door_open(id, open: true)
      assert.true! sprite.equal?(unit[:base])
      assert.equal! sprite[:occlusion_bounds], open_bounds
      assert.true! sprite[:occlusion_polygons] != closed_polygons
      assert.equal! unit[:footprint], footprint
      room.set_door_open(id, open: false)
      assert.equal! sprite[:occlusion_bounds], closed
      assert.equal! sprite[:occlusion_polygons], closed_polygons
    end
  end

  class AssetRuntime
    def initialize(gtk, overrides)
      @gtk = gtk
      @overrides = overrides
    end

    def read_file(path)
      return @overrides[path] if @overrides.key?(path)

      @gtk.read_file(path)
    end

    def parse_json(contents)
      @gtk.parse_json(contents)
    end
  end

  def test_missing_and_outdated_assets_give_a_regeneration_command(args, assert)
    path = Descent::OccluderData::PATH
    runtime = AssetRuntime.new(args.gtk, path => nil)
    assert.true! asset_error(runtime).include?('bin/rake assets:occluders')
    runtime = AssetRuntime.new(args.gtk, path => '{"format_version":2}')
    assert.true! asset_error(runtime).include?('Unsupported occluder data')
    image = 'sprites/environment_tilesheet.png'
    changed = "#{args.gtk.read_file(image)}changed"
    runtime = AssetRuntime.new(args.gtk, image => changed)
    message = asset_error(runtime)
    assert.true! message.include?('Outdated occluders')
    assert.true! message.include?(image)
    assert.true! message.include?('bin/rake assets:occluders')
  end

  def test_missing_tilesets_and_changed_grid_metadata_are_rejected(args, assert)
    data = tiled_test_map(args)
    occluders = occluder_fixture(args)
    occluders['tilesets'].shift
    error = nil
    begin
      Descent::TiledDeserializer.deserialize(data, path: 'tiled/ritual_gate.json', occluders: occluders)
    rescue ArgumentError => e
      error = e.message
    end
    assert.true! error&.include?('Missing or outdated occluders')
    data['tilesets'][0]['columns'] += 1
    error = nil
    begin
      Descent::TiledDeserializer.deserialize(data, path: 'tiled/ritual_gate.json', occluders: occluder_fixture(args))
    rescue ArgumentError => e
      error = e.message
    end
    assert.true! error&.include?('Missing or outdated occluders')
  end

  private

  def occluder_fixture(args)
    args.gtk.parse_json_file(Descent::OccluderData::PATH)
  end

  def asset_error(runtime)
    Descent::OccluderData.load(runtime)
    nil
  rescue ArgumentError => e
    e.message
  end
end
