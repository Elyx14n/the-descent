# frozen_string_literal: true

require 'app/room_preview'

module RoomTestHelpers
  def tiled_test_map(args)
    args.gtk.parse_json_file('tiled/ritual_gate.json')
  end

  def tiled_test_room(args, data = nil)
    decoded = Descent::TiledDeserializer.deserialize(
      data || tiled_test_map(args),
      path: 'tiled/ritual_gate.json',
      image_loader: ->(image) { args.gtk.get_pixels(image) }
    )
    Descent::Room.new(**decoded)
  end

  def tiled_test_error(args, data)
    Descent::TiledDeserializer.deserialize(data, path: 'tiled/ritual_gate.json',
                                                 image_loader: ->(image) { args.gtk.get_pixels(image) })
    nil
  rescue ArgumentError => e
    e.message
  end

  def clear_room_test_outputs(args)
    args.outputs.primitives.clear
    args.outputs.borders.clear
    args.outputs[Descent::Render::TARGET].primitives.clear
    args.outputs[Descent::Render::TARGET].borders.clear
  end

  def render_room_test(args)
    state = args.state.room_preview
    frame = state[:room].render_data
    frame[:groups] << state[:player].render_data
    Descent::Render.draw(args, frame: frame, camera: state[:camera])
  end
end
