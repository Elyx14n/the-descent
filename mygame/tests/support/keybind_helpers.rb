# frozen_string_literal: true

module KeybindTestHelpers
  def keybind_test_keyboard(args, held: [], pressed: [])
    keyboard = args.inputs.keyboard.class.new
    held.each { |key| keyboard.key_held.send("#{key}=", true) }
    pressed.each { |key| keyboard.key_down.send("#{key}=", true) }
    keyboard
  end
end
