# frozen_string_literal: true

module OffsetSnapTool
  class SnapEngine
    attr_reader :input_point

    def initialize(state)
      @state = state
      @input_point = Sketchup::InputPoint.new
      @last_xy = nil
    end

    def update(view, x, y)
      coords = [x, y]
      return false if @last_xy == coords

      changed = @input_point.pick(view, x, y)
      @last_xy = coords
      if @input_point.valid?
        @state.set_hover(
          point: @input_point.position,
          edge: @input_point.edge,
          face: @input_point.face,
          transformation: @input_point.transformation
        )
      else
        @state.set_hover(point: nil, edge: nil, face: nil, transformation: nil)
      end
      changed
    end

    def position
      return nil unless @input_point.valid?

      @input_point.position
    end
  end
end
