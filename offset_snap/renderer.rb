# frozen_string_literal: true

module OffsetSnapTool
  class Renderer
    BASE_COLOR = Sketchup::Color.new(255, 128, 0)
    HOVER_COLOR = Sketchup::Color.new(0, 160, 255)
    FINAL_COLOR = Sketchup::Color.new(32, 200, 120)
    LOCK_COLOR = {
      axis_x: Sketchup::Color.new(255, 0, 0),
      axis_y: Sketchup::Color.new(0, 200, 0),
      axis_z: Sketchup::Color.new(0, 0, 255),
      edge_parallel: Sketchup::Color.new(255, 128, 0),
      face_normal: Sketchup::Color.new(128, 0, 255)
    }.freeze

    def initialize(state, ui_feedback)
      @state = state
      @ui_feedback = ui_feedback
    end

    def draw(view)
      draw_hover(view)
      draw_preview(view)
      draw_locks(view)
      @ui_feedback.draw_hud(view)
    end

    private

    def draw_hover(view)
      return unless @state.hover_point
      return unless @state.hovering?

      view.drawing_color = HOVER_COLOR
      view.draw_points([@state.hover_point], 8, 5)
    end

    def draw_preview(view)
      return unless @state.base_point

      view.drawing_color = BASE_COLOR
      view.draw_points([@state.base_point], 10, 2)

      return unless @state.final_point

      lock_color = LOCK_COLOR[@state.direction_mode]
      view.drawing_color = lock_color || FINAL_COLOR
      view.line_width = 2
      view.draw(GL_LINES, [@state.base_point, @state.final_point])
      view.draw_points([@state.final_point], 8, 2)
      view.line_width = 1
    end

    def draw_locks(view)
      return unless @state.base_locked?
      return unless @state.direction_locked?
      return unless @state.direction

      color = LOCK_COLOR[@state.direction_mode]
      view.drawing_color = color if color
      direction = @state.direction
      base = @state.base_point
      far_point = base.offset(direction, 10.m)
      view.draw(GL_LINES, [base, far_point])
    end
  end
end
