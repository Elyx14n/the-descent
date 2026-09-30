# frozen_string_literal: true

# Follow the game's movement-then-playback order for isolated player tests.
def step_player(player, input)
  player.update(input)
  player.update_animation
end
