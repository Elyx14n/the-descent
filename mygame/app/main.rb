# frozen_string_literal: true

require 'app/collision_playground'

module Main
  def boot
    args.state = {}
  end

  def tick(args)
    args.state.game ||= { paused: false, debug_visible: false }
    args.outputs.background_color = Descent::UI::COLORS.fetch(:bg)
    Descent::CollisionPlayground.tick(args)
  end
end
