# frozen_string_literal: true

module Descent
  # Physical keys live here. Consumers receive actions and own their behavior.
  module Keybinds
    MOVEMENT = { up: [:w].freeze, left: [:a].freeze,
                 down: [:s].freeze, right: [:d].freeze }.freeze
    BINDINGS = {
      player: {
        sneak: { keys: [:shift].freeze, state: :key_down_or_held?, hint: 'sneak' }.freeze,
        toggle_lamp: { keys: [:f].freeze, state: :key_down?, hint: 'lamp' }.freeze,
        interact: { keys: [:e].freeze, state: :key_down?, hint: 'interact' }.freeze
      }.freeze,
      preview: {
        toggle_bounds: { keys: [:b].freeze, state: :key_down?, hint: 'boxes' }.freeze,
        reload: { keys: [:r].freeze, state: :key_down?, hint: 'load' }.freeze
      }.freeze
    }.freeze

    class << self
      def read(keyboard)
        actions = {}
        BINDINGS.each do |group, bindings|
          actions[group] = {}
          bindings.each do |action, binding|
            actions[group][action] = pressed?(keyboard, binding[:keys], binding[:state])
          end
        end
        actions[:player][:dx] = axis(keyboard, :right, :left)
        actions[:player][:dy] = axis(keyboard, :up, :down)
        actions
      end

      def help_text
        movement = MOVEMENT.values.transpose.map do |keys|
          keys.map(&:capitalize).join
        end.join('/')
        hints = BINDINGS.values.flat_map do |bindings|
          bindings.values.select { |binding| binding[:hint] }.map do |binding|
            "#{binding[:keys].map(&:capitalize).join('/')}: #{binding[:hint]}"
          end
        end
        (["#{movement}: move"] + hints).join('  ')
      end

      private

      def pressed?(keyboard, keys, query)
        keys.any? { |key| keyboard.send(query, key) }
      end

      def axis(keyboard, positive, negative)
        # DragonRuby's key_held excludes the first press frame; include key_down
        # too so movement and sneaking start immediately rather than a tick late.
        (pressed?(keyboard, MOVEMENT.fetch(positive), :key_down_or_held?) ? 1 : 0) -
          (pressed?(keyboard, MOVEMENT.fetch(negative), :key_down_or_held?) ? 1 : 0)
      end
    end
  end
end
