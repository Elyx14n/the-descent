# frozen_string_literal: true

require 'app/room_preview'

module Main
  def boot
    args.state = {}
  end

  def tick(args)
    path = args.gtk.cli_arguments[:map] || Descent::RoomPreview::MAP_PATH
    Descent::RoomPreview.tick(args, path: path)
  end
end
