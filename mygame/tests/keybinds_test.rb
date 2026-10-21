# frozen_string_literal: true

require 'app/keybinds'
require 'tests/support/keybind_helpers'

class KeybindsTests
  include KeybindTestHelpers

  def test_keybinds_wasd_movement_starts_on_press_and_opposing_keys_cancel(args, assert)
    keyboard = keybind_test_keyboard(args, pressed: %i[w d shift])
    input = Descent::Keybinds.read(keyboard)[:player]
    assert.equal! input.values_at(:dx, :dy, :sneak), [1, 1, true]
    keyboard = keybind_test_keyboard(args, held: %i[w d shift])
    assert.equal! Descent::Keybinds.read(keyboard)[:player], input
    keyboard = keybind_test_keyboard(args, held: %i[w d], pressed: %i[s a])
    assert.equal! Descent::Keybinds.read(keyboard)[:player].values_at(:dx, :dy), [0, 0]
    assert.equal! Descent::Keybinds.read(keybind_test_keyboard(args))[:player].values_at(:dx, :dy), [0, 0]
    %i[up down left right].each do |key|
      keyboard = keybind_test_keyboard(args, pressed: [key])
      assert.equal! Descent::Keybinds.read(keyboard)[:player].values_at(:dx, :dy), [0, 0]
    end
  end

  def test_keybinds_lamp_interaction_and_preview_toggles_fire_only_on_press(args, assert)
    keyboard = keybind_test_keyboard(args, held: %i[d shift], pressed: %i[f e r b])
    actions = Descent::Keybinds.read(keyboard)
    assert.equal! actions[:player].values_at(:dx, :sneak, :toggle_lamp, :interact), [1, true, true, true]
    assert.true! actions[:preview].values.all?
    keyboard = keybind_test_keyboard(args, held: %i[d shift f e r b])
    actions = Descent::Keybinds.read(keyboard)
    assert.equal! actions[:player].values_at(:dx, :sneak, :toggle_lamp, :interact), [1, true, false, false]
    assert.false! actions[:preview].values.any?
  end

  def test_keybinds_help_matches_the_registered_controls(_args, assert)
    assert.equal! Descent::Keybinds.help_text,
                  'WASD: move  Shift: sneak  F: lamp  E: interact  B: debug  R: load'
  end
end
