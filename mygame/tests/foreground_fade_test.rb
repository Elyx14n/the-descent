# frozen_string_literal: true

require 'app/foreground_fade'
require 'app/player'
require 'app/enemy'

class ForegroundFadeTests
  VIEWPORT = { x: 0, y: 0, w: 320, h: 180 }.freeze
  FOOTPRINT = { x: 32, y: 32, w: 32, h: 32 }.freeze

  def fade_actor(x: 48, y: 64)
    Descent::Player.new(x: x, y: y).render_data[:fade_actor]
  end

  def fade_artwork(rect = FOOTPRINT.merge(y: 64))
    rect.merge(path: :solid, a: 255)
  end

  def fade(world, sprites:, actors:, footprint: FOOTPRINT, base: nil, type: :wall)
    base ||= sprites.first
    Descent::ForegroundFade.apply(world, units: [{ type: type, base: base, footprint: footprint, sprites: sprites }],
                                         actors: actors, viewport: VIEWPORT)
  end

  def timed_fade(unit, state, tick, actor_data = fade_actor)
    actors = actor_data ? [actor_data] : []
    world = actors.map { |entry| entry[:sprite] } + unit[:sprites]
    Descent::ForegroundFade.apply(world, units: [unit], actors: actors,
                                         viewport: VIEWPORT, state: state, tick: tick)
  end

  def test_type_specific_minimum_opacity_preserves_the_same_distance_curve(_args, assert)
    %i[wall ceiling].each do |type|
      assert.equal! Descent::ForegroundFade.multiplier(FOOTPRINT, { x: 48, y: 64 }, type: type), 0.2
    end
    assert.equal! Descent::ForegroundFade.multiplier(FOOTPRINT, { x: 48, y: 64 }, type: :door), 0.5
    assert.equal! Descent::ForegroundFade.multiplier(FOOTPRINT, { x: 48, y: 80 }, type: :door), 0.75
    assert.equal! Descent::ForegroundFade.multiplier(FOOTPRINT, { x: 48, y: 96 }, type: :door), 1.0
  end

  def test_door_caps_share_the_supporting_base_opacity_and_transition_range(_args, assert)
    actor = fade_actor
    base = fade_artwork(FOOTPRINT).merge(type: :door)
    cap = fade_artwork.merge(type: :ceiling)
    sprites = [base, cap]
    world = [actor[:sprite]] + sprites
    assert.equal! fade(world, sprites: sprites, actors: [actor], type: :door).last(2).map { |sprite| sprite[:a] },
                  [128, 128]
    unit = { type: :door, base: base, footprint: FOOTPRINT, sprites: sprites }
    state = {}
    first = timed_fade(unit, state, 0).last[:a]
    assert.true! first > 128
    settled = timed_fade(unit, state, Descent::ForegroundFade::FADE_OUT_TICKS).last(2)
    assert.equal! settled.map { |sprite| sprite[:a] }, [128, 128]
    restoring = timed_fade(unit, state, Descent::ForegroundFade::FADE_OUT_TICKS + 1, nil).last[:a]
    assert.true! restoring > 128
    assert.true! restoring < 255
  end

  def test_hugging_a_side_wall_does_not_fade_without_crossing_the_center_line(_args, assert)
    actor_data = fade_actor(x: 65)
    cap = fade_artwork
    assert.true! Geometry.intersect_rect?(Descent::ForegroundFade.bounds(actor_data[:sprite]), cap)
    assert.equal! fade([actor_data[:sprite], cap], sprites: [cap], actors: [actor_data]).last[:a], 255
    [32, 63.999].each do |x|
      actor_data = fade_actor(x: x)
      assert.equal! fade([actor_data[:sprite], cap], sprites: [cap], actors: [actor_data]).last[:a], 51
    end
    actor_data = fade_actor(x: 64)
    assert.equal! fade([actor_data[:sprite], cap], sprites: [cap], actors: [actor_data]).last[:a], 255
  end

  def test_a_ceiling_piece_cannot_make_a_background_base_trigger_fading(_args, assert)
    actor_data = fade_actor
    base = fade_artwork(FOOTPRINT)
    cap = fade_artwork
    world = [base, actor_data[:sprite], cap]
    drawn = fade(world, sprites: [base, cap], actors: [actor_data], base: base)
    assert.equal! drawn.values_at(0, 2).map { |sprite| sprite[:a] }, [255, 255]
  end

  def test_artwork_above_the_visible_head_does_not_trigger_fading(_args, assert)
    actor_data = fade_actor
    base = fade_artwork(FOOTPRINT)
    cap = fade_artwork(FOOTPRINT.merge(y: 96))
    assert.true! Geometry.intersect_rect?(Descent::ForegroundFade.bounds(actor_data[:sprite]), cap)
    drawn = fade([actor_data[:sprite], base, cap], sprites: [base, cap], actors: [actor_data], base: base)
    assert.equal! drawn.last[:a], 255
    scaled = Descent::Player.new(x: 48, y: 64, scale: 2).render_data[:fade_actor]
    assert.equal! scaled[:occlusion_height], 52
  end

  def test_fade_out_and_restoration_are_bounded_when_center_line_eligibility_changes(_args, assert)
    cap = fade_artwork
    unit = { type: :wall, base: cap, footprint: FOOTPRINT, sprites: [cap] }
    state = {}
    out_ticks = Descent::ForegroundFade::FADE_OUT_TICKS
    in_ticks = Descent::ForegroundFade::FADE_IN_TICKS
    fading = (0..out_ticks).map { |tick| timed_fade(unit, state, tick).last[:a] }
    assert.true! fading.first < 255
    assert.true! fading.first > 51
    assert.equal! fading.last, 51
    assert.equal! fading.reverse.sort, fading.reverse
    # Cross the column edge while remaining close to the wall.
    outside = fade_actor(x: 64.01)
    restoring = ((out_ticks + 1)..(out_ticks + in_ticks + 1)).map do |tick|
      timed_fade(unit, state, tick, outside).last[:a]
    end
    assert.true! restoring.first > 51
    assert.true! restoring.first < 255
    assert.equal! restoring.last, 255
    assert.equal! restoring.sort, restoring
    restoring.each_cons(2) { |first, second| assert.true! second - first <= 12 }
    assert.equal! cap[:a], 255
  end

  def test_reentering_the_occluder_reverses_a_fade_in_without_a_jump(_args, assert)
    cap = fade_artwork
    unit = { type: :wall, base: cap, footprint: FOOTPRINT, sprites: [cap] }
    state = {}
    out_ticks = Descent::ForegroundFade::FADE_OUT_TICKS
    timed_fade(unit, state, 0)
    assert.equal! timed_fade(unit, state, out_ticks).last[:a], 51
    restoring = timed_fade(unit, state, out_ticks + 4, nil).last[:a]
    resumed = timed_fade(unit, state, out_ticks + 5).last[:a]
    assert.true! resumed < restoring
    assert.true! restoring - resumed <= 26
    # Drawing again in the same tick must not advance the transition twice.
    assert.equal! timed_fade(unit, state, out_ticks + 5).last[:a], resumed
    Descent::ForegroundFade.apply([], units: [], actors: [], viewport: VIEWPORT, state: state, tick: out_ticks + 6)
    assert.equal! state, {}
  end

  def test_opacity_remains_bounded_during_alternating_wall_edge_contacts(_args, assert)
    cap = fade_artwork
    unit = { type: :wall, base: cap, footprint: FOOTPRINT, sprites: [cap] }
    state = {}
    previous = 255
    30.times do |tick|
      actor_data = fade_actor(x: tick.even? ? 63.99 : 64.01)
      alpha = timed_fade(unit, state, tick, actor_data).last[:a]
      assert.true! (alpha - previous).abs <= 26
      previous = alpha
    end
  end

  def test_distance_curve_reaches_minimum_halfway_and_full_opacity(_args, assert)
    [[64, 0.2], [80, 0.6], [96, 1.0], [120, 1.0]].each do |y, expected|
      actual = Descent::ForegroundFade.multiplier(FOOTPRINT, { x: 48, y: y }, type: :wall)
      assert.true! (actual - expected).abs < 0.000001
    end
    samples = [64, 64.25, 72, 80, 88, 95.75, 96].map do |y|
      Descent::ForegroundFade.multiplier(FOOTPRINT, { x: 48, y: y }, type: :wall)
    end
    assert.equal! samples.sort, samples
    assert.true! samples[1] > samples[0]
    assert.true! samples[-2] < samples[-1]
  end

  def test_diagonal_falloff_uses_rounded_distance(_args, assert)
    straight = Descent::ForegroundFade.multiplier(FOOTPRINT, { x: 48, y: 80 }, type: :wall)
    diagonal = Descent::ForegroundFade.multiplier(FOOTPRINT, { x: 80, y: 80 }, type: :wall)
    assert.true! diagonal > straight
    assert.true! diagonal < 1
    assert.equal! Descent::ForegroundFade.multiplier(FOOTPRINT, { x: 88, y: 88 }, type: :wall), 1.0
  end

  def test_fades_only_artwork_drawn_after_and_overlapping_the_actor(_args, assert)
    actor_data = fade_actor
    sprite = actor_data[:sprite]
    wall = fade_artwork
    before = fade([wall, sprite], sprites: [wall], actors: [actor_data])
    after = fade([sprite, wall], sprites: [wall], actors: [actor_data])
    assert.equal! before.last, sprite
    assert.equal! before.first[:a], 255
    assert.equal! after.last[:a], 51
    unrelated = fade_artwork(FOOTPRINT.merge(x: 200))
    assert.equal! fade([sprite, unrelated], sprites: [unrelated], actors: [actor_data]).last[:a], 255
  end

  def test_equal_sprites_retain_their_independent_drawing_order(_args, assert)
    actor_data = fade_actor
    before = fade_artwork
    after = before.dup
    world = [before, actor_data[:sprite], after]
    drawn = fade(world, sprites: [before, after], actors: [actor_data], base: after)
    assert.equal! drawn.first[:a], 51 # A unit shares its strongest contribution across its members.
    drawn = fade(world, sprites: [before], actors: [actor_data])
    assert.equal! drawn.first[:a], 255 # An equal later sprite must not stand in for this member.
    assert.equal! drawn.last[:a], 255
  end

  def test_base_and_cap_share_alpha_without_mutating_authored_artwork(_args, assert)
    actor_data = fade_actor(y: 80)
    wall = fade_artwork(FOOTPRINT).merge(a: 200)
    cap = fade_artwork(FOOTPRINT.merge(y: 64)).merge(a: 100)
    world = [actor_data[:sprite], wall, cap]
    original = world.to_s
    drawn = fade(world, sprites: [wall, cap], actors: [actor_data])
    assert.equal! drawn.map { |sprite| sprite[:a] }, [nil, 120, 60]
    assert.equal! world.to_s, original
    assert.equal! fade(world, sprites: [wall, cap], actors: []).last[:a], 100
  end

  def test_strongest_actor_wins_independently_of_subject_order(_args, assert)
    near = fade_actor
    far = fade_actor(y: 80)
    wall = fade_artwork
    world = [near[:sprite], far[:sprite], wall]
    [[near, far], [far, near], [near, near]].each do |actors|
      assert.equal! fade(world, sprites: [wall], actors: actors).last[:a], 51
    end
    assert.equal! fade(world, sprites: [wall], actors: [far]).last[:a], 153
  end

  def test_unrendered_and_offscreen_actors_cannot_trigger_fading(_args, assert)
    actor_data = fade_actor
    wall = fade_artwork
    assert.equal! fade([wall], sprites: [wall], actors: [actor_data]).last[:a], 255
    offscreen = fade_actor(x: 380)
    wall = fade_artwork(FOOTPRINT.merge(x: 364))
    assert.equal! fade([offscreen[:sprite], wall], sprites: [wall], actors: [offscreen],
                                                   footprint: wall).last[:a], 255
  end

  def test_partial_visibility_and_overlap_resolve_both_sprite_anchors(_args, assert)
    # Actor center is beyond the right viewport edge, but its left half is visible.
    actor_data = fade_actor(x: 330)
    wall = fade_artwork(FOOTPRINT.merge(x: 312, y: 64))
    assert.equal! fade([actor_data[:sprite], wall], sprites: [wall], actors: [actor_data],
                                                    footprint: FOOTPRINT.merge(x: 312)).last[:a], 51
    anchored = { x: 20, y: 30, w: 10, h: 20, anchor_x: 0.5, anchor_y: 1 }
    assert.equal! Descent::ForegroundFade.bounds(anchored), { x: 15, y: 10, w: 10, h: 20 }
  end

  def test_player_and_enemy_supply_the_same_actor_contract(_args, assert)
    [Descent::Player.new(x: 48, y: 64), Descent::Enemy.new(x: 48, y: 64)].each do |actor|
      group = actor.render_data
      actor_data = group[:fade_actor]
      assert.equal! actor_data.values_at(:x, :y), [48, 64]
      assert.true! actor_data[:sprite].equal?(group[:sprites].first)
      assert.equal! actor_data[:occlusion_height], actor.class::OCCLUSION_HEIGHT
      wall = fade_artwork
      assert.equal! fade(group[:sprites] + [wall], sprites: [wall], actors: [actor_data]).last[:a], 51
    end
  end

  def test_overlapping_units_use_minimum_opacity_without_compounding(_args, assert)
    actor_data = fade_actor
    wall = fade_artwork
    units = [FOOTPRINT, FOOTPRINT.merge(y: 0)].map do |rect|
      { type: :wall, base: wall, footprint: rect, sprites: [wall] }
    end
    drawn = Descent::ForegroundFade.apply([actor_data[:sprite], wall], units: units,
                                                                       actors: [actor_data], viewport: VIEWPORT)
    assert.equal! drawn.last[:a], 51
  end

  def test_north_and_same_y_units_stay_opaque_even_when_the_ceiling_overlaps(_args, assert)
    actor_data = fade_actor(y: 80)
    [[80, 96], [96, 96]].each do |base_y, cap_y|
      cap = fade_artwork(FOOTPRINT.merge(y: cap_y))
      # Both frames overlap these caps; neither base is below the actor's feet.
      assert.true! Geometry.intersect_rect?(Descent::ForegroundFade.bounds(actor_data[:sprite]), cap)
      result = fade([actor_data[:sprite], cap], sprites: [cap], actors: [actor_data],
                                                footprint: FOOTPRINT.merge(y: base_y))
      assert.equal! result.last[:a], 255
    end
  end

  def test_lower_base_in_the_same_grid_row_can_reveal_a_genuinely_blocking_cap(_args, assert)
    actor_data = fade_actor(x: 80, y: 80)
    footprint = { x: 64, y: 64, w: 32, h: 32 }
    cap = fade_artwork(footprint.merge(y: 96))
    result = fade([actor_data[:sprite], cap], sprites: [cap], actors: [actor_data], footprint: footprint)
    assert.equal! result.last[:a], 51
  end

  def test_side_columns_and_bottom_frame_padding_do_not_count_as_occlusion(_args, assert)
    actor_data = fade_actor
    side = fade_artwork(FOOTPRINT.merge(x: 64, y: 64))
    assert.true! Geometry.intersect_rect?(Descent::ForegroundFade.bounds(actor_data[:sprite]), side)
    assert.equal! fade([actor_data[:sprite], side], sprites: [side], actors: [actor_data],
                                                    footprint: FOOTPRINT.merge(x: 64)).last[:a], 255

    actor_data = fade_actor(y: 80)
    below = fade_artwork(FOOTPRINT)
    assert.true! Geometry.intersect_rect?(Descent::ForegroundFade.bounds(actor_data[:sprite]), below)
    assert.equal! fade([actor_data[:sprite], below], sprites: [below], actors: [actor_data]).last[:a], 255
  end
end
