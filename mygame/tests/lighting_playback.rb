# frozen_string_literal: true

# Opt-in RoomPreview capture: bin/rake run -- --eval tests/lighting_playback.rb
require 'app/main'

module Main
  LIGHTING_MOUNTED_IDS = [121, 122].freeze

  alias lighting_original_tick tick

  def tick(args)
    @lighting_frame ||= 0
    state = args.state.room_preview
    if state && state[:room]
      case @lighting_frame
      when 30
        state[:player].reset(x: 176, y: 72)
      when 60
        state[:room].set_door_open(267, open: true)
      when 90
        state[:player].lamp_on = false
      when 120
        state[:room].lights.each { |light| state[:room].set_light_enabled(light[:id], enabled: false) }
      when 150
        state[:room].lights.each { |light| state[:room].set_light_enabled(light[:id], enabled: true) }
        state[:player].reset(x: 48, y: 100)
      when 180
        state[:player].reset(x: 36, y: 96)
      when 210
        state[:player].reset(x: 176, y: 36)
      when 240
        state[:room].lights.each do |light|
          state[:room].set_light_enabled(light[:id], enabled: LIGHTING_MOUNTED_IDS.include?(light[:id]))
        end
        state[:player].reset(x: 176, y: 270)
        state[:player].lamp_on = false
      when 270
        state[:room].set_light_enabled(121, enabled: false)
      when 300
        state[:room].set_light_enabled(122, enabled: false)
      end
    end
    lighting_original_tick(args)
    name = { 20 => 'room', 50 => 'closed-door', 80 => 'open-door', 110 => 'lamp-off',
             140 => 'all-off', 170 => 'south-corner', 200 => 'south-wall-contact',
             230 => 'south-door-contact', 260 => 'mounted-pair', 290 => 'mounted-left',
             320 => 'mounted-off' }[@lighting_frame]
    if name
      path = "tmp/lighting-#{name}.png"
      args.outputs.screenshots << { x: 0, y: 0, w: Grid.w, h: Grid.h, path: path }
      puts "LIGHTING_CAPTURE #{name}"
    end
    args.gtk.request_quit if @lighting_frame == 330
    @lighting_frame += 1
  end
end
