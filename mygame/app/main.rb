# frozen_string_literal: true

require 'app/room_scene'

module Main
  def boot
    args.state = {}
  end

  def tick(args)
    args.state.game ||= { paused: false, debug_visible: false }
    args.outputs.background_color = Descent::UI::COLORS.fetch(:bg)
    Descent::RoomScene.tick(args)
  end
end
