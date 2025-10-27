# frozen_string_literal: true

module OffsetSnapTool
  class StateManager
    attr_reader :state, :base_point, :final_point, :direction
    attr_reader :offset_distance, :explicit_offset, :direction_mode
    attr_reader :hover_point, :hover_edge, :hover_face, :hover_transformation

    def initialize
      reset
    end

    def reset
      @state = :hovering
      @base_point = nil
      @final_point = nil
      @direction = nil
      @direction_mode = :free
      @offset_distance = 0.0
      @explicit_offset = nil
      @offset_locked = false
      @chain_active = false
      @chain_anchor = nil
      @snap_enabled = true
      @hover_point = nil
      @hover_edge = nil
      @hover_face = nil
      @hover_transformation = OffsetSnapTool::IDENTITY
      @history_hint = nil
      @status_dirty = true
    end

    def hovering?
      @state == :hovering
    end

    def base_locked?
      @state == :base_locked
    end

    def offset_locked?
      @offset_locked
    end

    def snap_enabled?
      @snap_enabled
    end

    def direction_locked?
      @direction_mode != :free
    end

    def history_hint
      @history_hint
    end

    def status_dirty?
      dirty = @status_dirty
      @status_dirty = false
      dirty
    end

    def set_history_hint(value)
      @history_hint = value
      flag_status_dirty
    end

    def lock_base(point)
      raise ArgumentError, 'Base point required' unless point

      @base_point = Geom::Point3d.new(point)
      @state = :base_locked
      clear_preview
      unlock_offset
      @history_hint = nil
      flag_status_dirty
    end

    def clear_base
      @base_point = nil
      transition_to_hovering
    end

    def transition_to_hovering
      @state = :hovering
      clear_preview
      unlock_offset
      flag_status_dirty
    end

    def update_preview(direction:, final_point:, offset:)
      @direction = direction
      @final_point = final_point
      @offset_distance = offset
      flag_status_dirty
    end

    def clear_preview
      @direction = nil
      @final_point = nil
      @offset_distance = 0.0
    end

    def lock_offset(length)
      @explicit_offset = length
      @offset_locked = true
      flag_status_dirty
    end

    def unlock_offset
      @explicit_offset = nil
      @offset_locked = false
      flag_status_dirty
    end

    def toggle_snap
      @snap_enabled = !@snap_enabled
      flag_status_dirty
    end

    def set_snap(enabled)
      @snap_enabled = enabled
      flag_status_dirty
    end

    def chain_active?
      @chain_active
    end

    def chain_anchor
      @chain_anchor
    end

    def toggle_chain_mode
      @chain_active = !@chain_active
      @chain_anchor = @final_point if @chain_active && @final_point
      flag_status_dirty
    end

    def begin_chain(point)
      @chain_anchor = point
      @chain_active = true
      flag_status_dirty
    end

    def reset_chain
      @chain_active = false
      @chain_anchor = nil
      flag_status_dirty
    end

    def commit_chain_step(new_anchor)
      @chain_anchor = new_anchor if @chain_active
      flag_status_dirty
    end

    def set_direction_mode(mode)
      @direction_mode = mode
      flag_status_dirty
    end

    def set_hover(point: nil, edge: nil, face: nil, transformation: nil)
      @hover_point = point
      @hover_edge = edge
      @hover_face = face
      @hover_transformation = transformation || OffsetSnapTool::IDENTITY
    end

    private

    def flag_status_dirty
      @status_dirty = true
    end
  end
end
