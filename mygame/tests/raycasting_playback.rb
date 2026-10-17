# frozen_string_literal: true

# Opt-in rendered-frame probe (not part of the unit suite):
# bin/rake run -- --eval tests/raycasting_playback.rb
# Moving lamp, 30 warm-up frames and 60 measured frames per size/debug setting.
require 'app/main'

module Main
  RAYCAST_PLAYBACK_CASES = [
    [640, 360, false], [640, 360, true],
    [1920, 1080, false], [1920, 1080, true]
  ].freeze

  alias raycasting_original_tick tick

  def tick(args)
    @raycast_phase ||= 0
    @raycast_frame ||= 0
    @raycast_loop_samples ||= []
    @raycast_prep_samples ||= []
    width, height, debug = RAYCAST_PLAYBACK_CASES[@raycast_phase]
    now = Time.now
    args.gtk.set_window_size(width, height) if @raycast_frame.zero?
    args.state.room_preview ||= {}
    args.state.room_preview[:show_bounds] = debug
    player = args.state.room_preview[:player]
    if player
      player.x = 240 + ((@raycast_frame % 40) * 0.5)
      player.y = 220
    end
    raycasting_original_tick(args)
    if @raycast_frame >= 30
      @raycast_loop_samples << ((now - @raycast_previous_tick) * 1000)
      @raycast_prep_samples << ((Time.now - now) * 1000)
    end
    @raycast_previous_tick = now
    @raycast_frame += 1
    return unless @raycast_frame == 90

    elapsed = @raycast_loop_samples.sum
    puts "RAYCAST_PLAYBACK window=#{width}x#{height} debug=#{debug} " \
         "frames=#{@raycast_loop_samples.length} " \
         "loop_fps=#{(@raycast_loop_samples.length * 1000 / elapsed).round(2)} " \
         "median_loop_ms=#{@raycast_loop_samples.sort[30].round(3)} " \
         "median_prep_ms=#{@raycast_prep_samples.sort[30].round(3)}"
    @raycast_phase += 1
    if @raycast_phase == RAYCAST_PLAYBACK_CASES.length
      args.gtk.request_quit
    else
      @raycast_frame = 0
      @raycast_loop_samples = []
      @raycast_prep_samples = []
    end
  end
end
