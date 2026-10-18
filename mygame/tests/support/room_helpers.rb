# frozen_string_literal: true

require 'app/room_preview'

module RoomTestHelpers
  def tiled_test_map(args)
    args.gtk.parse_json_file('tiled/ritual_gate.json')
  end

  def tiled_test_room(args, data = nil)
    decoded = Descent::TiledDeserializer.deserialize(
      data || tiled_test_map(args),
      path: 'tiled/ritual_gate.json'
    )
    Descent::Room.new(**decoded)
  end

  def tiled_test_error(_args, data)
    Descent::TiledDeserializer.deserialize(data, path: 'tiled/ritual_gate.json')
    nil
  rescue ArgumentError => e
    e.message
  end

  def clear_room_test_outputs(args)
    args.outputs.primitives.clear
    args.outputs.borders.clear
    args.outputs[Descent::Render::TARGET].lines.clear
    args.outputs[Descent::Render::TARGET].primitives.clear
    args.outputs[Descent::Render::TARGET].borders.clear
    args.outputs[Descent::Lighting::LIGHTMAP_TARGET].primitives.clear
    args.outputs[Descent::Lighting::LIGHT_MASK_TARGET].primitives.clear
  end

  def render_room_test(args)
    state = args.state.room_preview
    frame = state[:room].render_data
    frame[:groups] << state[:player].render_data
    Descent::Render.draw(args, frame: frame, camera: state[:camera])
  end
end
