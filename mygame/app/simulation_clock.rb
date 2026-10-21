# frozen_string_literal: true

module Descent
  # Schedules whole 60 Hz steps. Elapsed time never enters gameplay rules.
  class SimulationClock
    RATE = 60
    SECOND_US = 1_000_000
    MAX_STEPS = 8
    STALL_US = 250_000

    attr_reader :tick, :steps, :discarded_us, :discontinuity, :now_us

    def self.read_us
      (Time.now.to_f * SECOND_US).round
    end

    def initialize(now_us:)
      @tick = 0
      @discarded_us = 0
      reset(now_us: now_us)
    end

    def reset(now_us:)
      @now_us = now_us
      @accumulator = 0
      @steps = 0
      @discontinuity = true
    end

    def advance(now_us:)
      elapsed = now_us - @now_us
      @now_us = now_us
      @steps = 0
      @discontinuity = elapsed.negative? || elapsed >= STALL_US
      if @discontinuity
        @discarded_us += [elapsed, 0].max + @accumulator.fdiv(RATE)
        @accumulator = 0
        return 0
      end

      @accumulator += elapsed * RATE
      due = @accumulator.div(SECOND_US)
      @steps = [due, MAX_STEPS].min
      @discarded_us += (due - @steps) * SECOND_US.fdiv(RATE)
      @accumulator %= SECOND_US
      @steps
    end

    # Advance the tick supplied to the next fixed gameplay update.
    def step
      @tick += 1
    end

    def alpha
      @accumulator.fdiv(SECOND_US)
    end

    def presentation_tick
      [@tick - 1 + alpha, 0].max
    end
  end
end
