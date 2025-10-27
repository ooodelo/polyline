# frozen_string_literal: true

module OffsetSnapTool
  class Tool
    def initialize(model = Sketchup.active_model)
      @model = model
      @state = StateManager.new
      @history = HistoryManager.new
      @snap_engine = SnapEngine.new(@state)
      @direction_resolver = DirectionResolver.new
      @offset_calculator = OffsetCalculator.new(@state)
      @geometry_creator = GeometryCreator.new(@model)
      @ui_feedback = UIFeedback.new(@state, @history)
      @renderer = Renderer.new(@state, @ui_feedback)
      @view = nil
    end

    def activate
      @view = @model.active_view
      @state.reset
      if (last = @history.last)
        @state.set_history_hint(last)
      end
      Sketchup.set_status_text('', SB_PROMPT)
      Sketchup.set_status_text('', SB_VCB_LABEL)
      Sketchup.set_status_text('', SB_VCB_VALUE)
      @view.invalidate
    end

    def deactivate(view)
      @view = nil
      Sketchup.set_status_text('', SB_PROMPT)
      Sketchup.set_status_text('', SB_VCB_LABEL)
      Sketchup.set_status_text('', SB_VCB_VALUE)
    end

    def resume(view)
      @view = view
      view.invalidate
    end

    def suspend(_view)
      # no-op
    end

    def onCancel(_reason, view)
      reset_tool
      view.invalidate if view
    end

    def onMouseMove(_flags, x, y, view)
      changed = @snap_engine.update(view, x, y)
      cursor_point = @snap_engine.position

      if @state.hovering? && cursor_point
        @state.set_history_hint(@history.last)
      end

      if @state.base_locked?
        @state.set_direction_mode(@direction_resolver.mode)
        direction = @direction_resolver.calculate_direction(view, x, y, @state.base_point)
        if direction
          offset, final_point = @offset_calculator.compute(@state.base_point, direction, cursor_point)
          if final_point
            @state.update_preview(direction: direction, final_point: final_point, offset: offset)
          else
            @state.clear_preview
          end
        else
          @state.clear_preview
        end
      end

      view.invalidate if changed || @state.base_locked?
      @ui_feedback.update_status
    end

    def onLButtonDown(_flags, _x, _y, view)
      cursor_point = @snap_engine.position
      if @state.hovering? && cursor_point
        @state.lock_base(cursor_point)
        @direction_resolver.clear_lock
      elsif @state.base_locked? && @state.final_point
        commit_geometry
      end
      view.invalidate
      @ui_feedback.update_status
    end

    def onLButtonDoubleClick(_flags, _x, _y, view)
      complete_chain
      view.invalidate
      @ui_feedback.update_status
    end

    def onKeyDown(key, _repeat, _flags, view)
      case key
      when VK_ESCAPE
        reset_tool
      when VK_RIGHT
        lock_axis(OffsetSnapTool::X_AXIS, view)
      when VK_LEFT
        lock_axis(OffsetSnapTool::Y_AXIS, view)
      when VK_UP
        lock_axis(OffsetSnapTool::Z_AXIS, view)
      when VK_MENU
        lock_hover_edge(view)
      when 'N'.ord
        lock_hover_face(view)
      when VK_CONTROL
        @state.toggle_snap
      when VK_SPACE
        toggle_chain
      when VK_RETURN
        commit_geometry
      when (defined?(VK_ENTER) ? VK_ENTER : nil)
        commit_geometry
      end
      view.invalidate
      @ui_feedback.update_status
    end

    def onKeyUp(key, _repeat, _flags, view)
      case key
      when VK_RIGHT, VK_LEFT, VK_UP
        unlock_direction(view)
      when VK_MENU
        unlock_direction(view)
      end
      @ui_feedback.update_status
    end

    def onUserText(text, view)
      length = Sketchup.parse_length(text)
      if length
        @state.lock_offset(length)
        @history.remember(length)
      else
        UI.messagebox('Неверное значение длины')
      end
      view.invalidate
      @ui_feedback.update_status
    end

    def draw(view)
      @ui_feedback.update_status
      @renderer.draw(view)
      @snap_engine.input_point.draw(view) if @state.hovering?
    end

    def getMenu(menu)
      menu.add_item('Toggle Snap') { toggle_snap }
      menu.add_item('Reset History') { reset_history }
      menu.add_separator
      menu.add_item(chain_menu_label) { toggle_chain }
    end

    private

    def lock_axis(axis_vector, view)
      @direction_resolver.lock_axis(axis_vector)
      @state.set_direction_mode(@direction_resolver.mode)
      view.lock_inference(axis_vector)
    end

    def lock_hover_edge(view)
      return unless @state.hover_edge

      @direction_resolver.lock_edge(@state.hover_edge, @state.hover_transformation)
      @state.set_direction_mode(@direction_resolver.mode)
      view.lock_inference(@direction_resolver.locked_direction)
    end

    def lock_hover_face(view)
      return unless @state.hover_face

      @direction_resolver.lock_face(@state.hover_face, @state.hover_transformation)
      @state.set_direction_mode(@direction_resolver.mode)
      view.lock_inference(@direction_resolver.locked_direction)
    end

    def unlock_direction(view)
      @direction_resolver.clear_lock
      @state.set_direction_mode(@direction_resolver.mode)
      view.lock_inference(nil)
    end

    def toggle_snap
      @state.toggle_snap
      @ui_feedback.update_status
      @view&.invalidate
    end

    def toggle_chain
      if @state.chain_active?
        @state.reset_chain
      elsif @state.base_point
        @state.begin_chain(@state.base_point)
      end
    end

    def chain_menu_label
      @state.chain_active? ? 'Disable Chain Mode' : 'Enable Chain Mode'
    end

    def commit_geometry
      return unless @state.base_locked? && @state.final_point

      if @state.chain_active? && @state.chain_anchor
        @geometry_creator.create_edge(@state.chain_anchor, @state.final_point)
        @state.commit_chain_step(@state.final_point)
        @state.lock_base(@state.final_point)
      else
        @geometry_creator.create_point(@state.final_point)
        @history.remember(@state.offset_distance)
        if @state.chain_active?
          @state.commit_chain_step(@state.final_point)
          @state.lock_base(@state.final_point)
        else
          reset_tool
        end
      end
    end

    def complete_chain
      if @state.chain_active?
        @state.reset_chain
        reset_tool
      end
    end

    def reset_tool
      @direction_resolver.clear_lock
      @state.reset
      @ui_feedback.update_status
    end

    def reset_history
      @history.reset
      @ui_feedback.update_status
    end
  end
end
