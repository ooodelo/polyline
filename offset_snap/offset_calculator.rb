# frozen_string_literal: true

module OffsetSnapTool
  class OffsetCalculator
    SNAP_STEPS_MM = [100, 250, 500, 1000, 2500, 5000].freeze
    SNAP_TOLERANCE = 0.05
    SNAP_STEPS = SNAP_STEPS_MM.map { |mm| mm.mm }.freeze

    def initialize(state)
      @state = state
    end

    def compute(base_point, direction, cursor_point)
      return unless base_point && direction

      offset = if @state.offset_locked?
                 @state.explicit_offset.to_f
               else
                 dynamic_offset(base_point, direction, cursor_point)
               end

      offset = snap_to_round(offset) if !@state.offset_locked? && @state.snap_enabled?

      final_point = base_point.offset(direction, offset)
      [offset, final_point]
    end

    def dynamic_offset(base_point, direction, cursor_point)
      return 0.0 unless cursor_point

      vector = cursor_point - base_point
      vector % direction
    end

    def snap_to_round(value)
      return value unless value.is_a?(Numeric)

      SNAP_STEPS.each do |step|
        next if step.zero?

        if (value - step).abs <= step * SNAP_TOLERANCE
          return step * (value.negative? ? -1 : 1)
        end
      end
      value
    end
  end
end
