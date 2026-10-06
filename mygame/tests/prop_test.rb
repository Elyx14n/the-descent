# frozen_string_literal: true

require 'app/collision_playground'

# The world is drawn into the camera's render target, so clear it alongside the
# screen-space outputs when a test drives several ticks by hand.
def clear_prop_test_outputs(args)
  args.outputs.primitives.clear
  args.outputs.borders.clear
  args.outputs[Descent::Camera::TARGET].primitives.clear
  args.outputs[Descent::Camera::TARGET].borders.clear
end

# Replacing a constant models what saving its Ruby definition does on hot reload.
def with_prop_test_constant(owner, name, replacement)
  original = owner.const_get(name)
  owner.send(:remove_const, name)
  owner.const_set(name, replacement)
  yield
ensure
  owner.send(:remove_const, name)
  owner.const_set(name, original)
end

def test_prop_spawn_uses_catalog_without_requiring_an_override(_args, assert)
  prop = Descent::Prop.spawn(id: :round_stone_column, x: 100, y: 200, facing: :west)
  assert.equal! prop.id, :round_stone_column
  assert.equal! prop.facing, :west
  assert.equal! prop.scale, 1
  assert.equal! prop.collision_rect, { x: 84, y: 200, w: 32, h: 32 }
  primitive = prop.sprite_to_primitive
  assert.equal! primitive[:path], 'sprites/tilesheet.png'
  assert.equal! [primitive[:source_x], primitive[:source_y]], [128, 384]

  other = Descent::Prop.spawn(id: prop.id, x: 300, y: 400)
  assert.false! prop.sprite.equal?(other.sprite)
  assert.false! prop.collider.equal?(other.collider)
  other.reset(x: 500, y: 600)
  assert.equal! [prop.x, prop.y], [100, 200]
end

def test_prop_overrides_scale_art_and_collision_or_disable_collision(_args, assert)
  coffin = Descent::Prop.spawn(id: :closed_stone_coffin, x: 100, y: 200)
  assert.equal! coffin.collision_rect, { x: 88, y: 200, w: 24, h: 10 }
  primitive = coffin.sprite_to_primitive
  assert.equal! [primitive[:w], primitive[:h]], [32, 32]
  assert.equal! [primitive[:source_x], primitive[:source_y]], [448, 320]

  banner = Descent::Prop.spawn(id: :red_banner, x: 100, y: 200)
  assert.equal! banner.collision_rect, nil
  assert.equal! banner.sprite_to_primitive[:source_x], 288
end

def test_scale_only_override_keeps_default_collider(_args, assert)
  overrides = Descent::Prop::PROP_OVERRIDES.merge(round_stone_column: { scale: 2 })
  with_prop_test_constant(Descent::Prop, :PROP_OVERRIDES, overrides) do
    prop = Descent::Prop.spawn(id: :round_stone_column, x: 100, y: 200)
    assert.equal! prop.collision_rect, { x: 68, y: 200, w: 64, h: 64 }
    assert.equal! prop.sprite_to_primitive[:w], 64
  end
end

def test_prop_spawn_rejects_unknown_tile_name(_args, assert)
  error = nil
  begin
    Descent::Prop.spawn(id: :missing_tile, x: 0, y: 0)
  rescue KeyError => e
    error = e
  end
  assert.true! error.is_a?(KeyError)
end

def test_playground_uses_prop_colliders_for_movement(args, assert)
  args.state.player = Descent::Player.new(x: 193, y: 100)
  args.state.playground = { walls: [], show_bounds: true }
  args.inputs.keyboard.key_held.right = true

  20.times do |tick|
    clear_prop_test_outputs(args)
    Descent::CollisionPlayground.tick(args, tick_count: tick)
  end
  # Stopped with its foot collider flush against the coffin's left edge.
  assert.equal! args.state.player.x, 201
  assert.false! args.state.player.moving?
  props = args.state.playground[:props]
  assert.false! Geometry.intersect_rect?(args.state.player.collision_rect, props.first.collision_rect)
  assert.equal! props.last.collision_rect, nil
ensure
  args.inputs.keyboard.key_held.right = false
end

def test_override_reload_updates_existing_props_and_preserves_player(args, assert)
  player = Descent::Player.new(x: 193, y: 100, sanity: 75)
  player.lamp_on = false
  args.state.player = player
  args.state.playground = { walls: [], show_bounds: true }
  Descent::CollisionPlayground.tick(args, tick_count: 0)
  original = args.state.playground[:props].first

  overrides = Descent::Prop::PROP_OVERRIDES.merge(closed_stone_coffin: { scale: 2, collider: { w: 8, h: 6 } })
  with_prop_test_constant(Descent::Prop, :PROP_OVERRIDES, overrides) do
    clear_prop_test_outputs(args)
    Descent::CollisionPlayground.tick(args, tick_count: 1)
    scene = args.outputs[Descent::Camera::TARGET]
    updated = args.state.playground[:props].first
    assert.false! updated.equal?(original)
    assert.equal! updated.collision_rect, { x: 209, y: 97, w: 16, h: 12 }
    camera = args.state.playground[:camera]
    border = camera.to_screen_space(updated.collision_rect.merge(r: 100, g: 180, b: 255))
    assert.true! scene.borders.flatten.include?(border)
    screen_x = camera.to_screen(x: 217, y: 97)[:x]
    rendered = scene.primitives.flatten.find { |p| p[:path] == 'sprites/tilesheet.png' && p[:x] == screen_x }
    assert.equal! rendered[:w], 64
    assert.true! args.state.player.equal?(player)
    assert.equal! [player.x, player.y, player.sanity, player.lamp_on], [193, 100, 75, false]

    # Stable definitions reuse instances on subsequent frames.
    Descent::CollisionPlayground.refresh_props(args.state.playground)
    assert.true! args.state.playground[:props].first.equal?(updated)
  end

  with_prop_test_constant(Descent::Prop, :PROP_OVERRIDES, overrides.merge(closed_stone_coffin: { collider: nil })) do
    clear_prop_test_outputs(args)
    Descent::CollisionPlayground.tick(args, tick_count: 2)
    assert.equal! args.state.playground[:props].first.collision_rect, nil
    # Player only; both props are decorative.
    assert.equal! args.outputs[Descent::Camera::TARGET].borders.flatten.length, 1
  end
end

def test_placement_and_catalog_reload_rebuild_props_without_resetting_playground(_args, assert)
  playground = { danger_death_at: 120, show_bounds: false }
  Descent::CollisionPlayground.refresh_props(playground)
  placements = [{ id: :round_stone_column, x: 200, y: 300, facing: :east }].freeze
  with_prop_test_constant(Descent::CollisionPlayground, :PROP_PLACEMENTS, placements) do
    Descent::CollisionPlayground.refresh_props(playground)
    assert.equal! playground[:props].length, 1
    prop = playground[:props].first
    assert.equal! [prop.id, prop.x, prop.y, prop.facing], [:round_stone_column, 200, 300, :east]
    tiles = Descent::Tilesheet::TILES.merge(round_stone_column: 288).freeze
    with_prop_test_constant(Descent::Tilesheet, :TILES, tiles) do
      Descent::CollisionPlayground.refresh_props(playground)
      updated = playground[:props].first
      assert.false! updated.equal?(prop)
      primitive = updated.sprite_to_primitive
      assert.equal! [primitive[:source_x], primitive[:source_y]], [512, 0]
    end
  end
  assert.equal! playground[:danger_death_at], 120
  assert.false! playground[:show_bounds]
end
