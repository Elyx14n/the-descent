# frozen_string_literal: true

require 'app/room_preview'

module Main
  def boot
    args.state = {}
  end

  def tick(args)
    Descent::RoomPreview.tick(args)
  end
end
