# frozen_string_literal: true

require 'app/game'
require 'app/collision_playground'

module Main
  def boot
    args.state = {}
  end

  def tick(args)
    args.state.game ||= Descent::Game::STATE_DEFAULTS.dup
    args.outputs.background_color = Descent::Game::BG_COLOR
    Descent::CollisionPlayground.tick(args)
  end
end
