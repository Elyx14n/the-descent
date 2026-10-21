# frozen_string_literal: true

# Opt-in: bin/rake run -- --eval tests/lighting_audit_playback.rb
# Isolates casting, debug-line submission, and exact-input polygon reuse.
# The comparison cache is an audit oracle, not a production cache design.
require 'app/main'
require 'tests/support/lighting_audit_helpers'

# Standalone probe patches both the preview and frame loop in this process only.
# rubocop:disable Style/OneClassPerFile
module Descent
  module RoomPreview
    extend LightingAuditHelpers

    class << self
      # Isolate the historical casting stages from the integrated filled pass.
      def prepare_lighting(_frame, _state)
        nil
      end

      def add_diagnostics(frame, state, args)
        mode = args.state.lighting_audit_mode
        sources = audit_sources(frame)
        sources = sources.select { |source| source[:id] == :player } if mode == :player_compute
        inputs = audit_inputs(frame, sources)
        casts = 0
        polygons = if mode == :frozen_outlines
                     state[:audit_frozen_polygons] ||= audit_cast(inputs)
                   elsif %i[cached_compute cached_outlines].include?(mode)
                     cache = state[:audit_polygons] ||= {}
                     inputs.map do |input|
                       id = input[:source][:id]
                       previous = cache[id]
                       if previous && previous[:segments] == input[:segments]
                         previous[:polygon]
                       else
                         casts += 1
                         polygon = audit_cast([input]).first
                         cache[id] = { segments: input[:segments], polygon: polygon }
                         polygon
                       end
                     end
                   else
                     casts = inputs.length
                     audit_cast(inputs)
                   end
        frame[:world_lines] = if %i[all_outlines frozen_outlines cached_outlines].include?(mode)
                                audit_lines(polygons)
                              else
                                []
                              end
        return unless args.state.lighting_audit_measure

        args.state.lighting_audit_casts += casts
        args.state.lighting_audit_queries += inputs.length
      end
    end
  end
end

module Main
  LIGHTING_AUDIT_MODES = %i[
    scene player_compute all_compute all_outlines frozen_outlines cached_compute cached_outlines
  ].freeze
  LIGHTING_AUDIT_CASES = [640, 1920].flat_map do |width|
    LIGHTING_AUDIT_MODES.map { |mode| [width, width == 640 ? 360 : 1080, mode] }
  end.freeze

  alias lighting_audit_original_tick tick

  def tick(args)
    @audit_phase ||= 0
    @audit_frame ||= 0
    @audit_loop_samples ||= []
    @audit_prep_samples ||= []
    width, height, mode = LIGHTING_AUDIT_CASES[@audit_phase]
    now = Time.now
    args.state.room_preview ||= {}
    state = args.state.room_preview
    if @audit_frame.zero?
      args.gtk.set_window_size(width, height)
      state[:audit_polygons] = nil
      state[:audit_frozen_polygons] = nil
      args.state.lighting_audit_casts = 0
      args.state.lighting_audit_queries = 0
    end
    args.state.lighting_audit_mode = mode
    args.state.lighting_audit_measure = @audit_frame >= 30
    state[:show_bounds] = mode != :scene
    player = state[:player]
    if player
      player.x = 240 + ((@audit_frame % 40) * 0.5)
      player.y = 220
    end
    lighting_audit_original_tick(args)
    if @audit_frame >= 30
      @audit_loop_samples << ((now - @audit_previous_tick) * 1000)
      @audit_prep_samples << ((Time.now - now) * 1000)
    end
    @audit_previous_tick = now
    @audit_frame += 1
    return unless @audit_frame == 90

    puts "LIGHT_AUDIT_PLAYBACK window=#{width}x#{height} mode=#{mode} frames=60 " \
         "fps=#{(60_000 / @audit_loop_samples.sum).round(2)} " \
         "median_prep_ms=#{@audit_prep_samples.sort[30].round(3)} " \
         "p95_prep_ms=#{@audit_prep_samples.sort[56].round(3)} " \
         "mean_prep_ms=#{(@audit_prep_samples.sum / 60).round(3)} " \
         "max_prep_ms=#{@audit_prep_samples.max.round(3)} " \
         "median_loop_ms=#{@audit_loop_samples.sort[30].round(3)} " \
         "max_loop_ms=#{@audit_loop_samples.max.round(3)} " \
         "casts=#{args.state.lighting_audit_casts} queries=#{args.state.lighting_audit_queries}"
    @audit_phase += 1
    if @audit_phase == LIGHTING_AUDIT_CASES.length
      args.gtk.request_quit
    else
      @audit_frame = 0
      @audit_loop_samples = []
      @audit_prep_samples = []
    end
  end
end
# rubocop:enable Style/OneClassPerFile
