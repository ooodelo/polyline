# frozen_string_literal: true

module OffsetSnapTool
  class UIFeedback
    HUD_OFFSET = Geom::Vector3d.new(15, 20, 0).freeze

    def initialize(state, history)
      @state = state
      @history = history
      @hud_lines = []
    end

    def update_status
      return unless @state.status_dirty?

      Sketchup.set_status_text(status_line, SB_PROMPT)
      Sketchup.set_status_text(vcb_value, SB_VCB_VALUE)
      Sketchup.set_status_text(mode_hint, SB_VCB_LABEL)
    end

    def draw_hud(view)
      build_hud_lines(view)
      return if @hud_lines.empty?

      @hud_lines.each do |text, position|
        view.draw_text(position, text)
      end
    end

    def status_line
      if @state.hovering?
        'Укажите базовую точку смещения'
      elsif @state.base_locked?
        'Задайте направление и длину смещения'
      else
        'Offset Snap Tool'
      end
    end

    def vcb_value
      if @state.offset_locked?
        Sketchup.format_length(@state.explicit_offset)
      elsif @state.offset_distance
        Sketchup.format_length(@state.offset_distance)
      elsif @state.history_hint
        Sketchup.format_length(@state.history_hint)
      else
        @history.last_formatted
      end
    end

    def mode_hint
      case @state.direction_mode
      when :axis_x then 'X-axis lock'
      when :axis_y then 'Y-axis lock'
      when :axis_z then 'Z-axis lock'
      when :edge_parallel then 'Edge ||'
      when :face_normal then 'Face ⊥'
      else
        'Free'
      end
    end

    private

    def build_hud_lines(view)
      @hud_lines.clear
      return unless @state.base_point

      base_screen = view.screen_coords(@state.base_point)
      hud_origin = Geom::Point3d.new(base_screen.x + HUD_OFFSET.x, base_screen.y + HUD_OFFSET.y, 0)

      @hud_lines << ["Mode: #{mode_hint}", hud_origin]
      if @state.offset_distance
        offset_text = Sketchup.format_length(@state.offset_distance)
        offset_text = "#{offset_text} (locked)" if @state.offset_locked?
        @hud_lines << ["Offset: #{offset_text}", hud_origin.offset(Geom::Vector3d.new(0, 16, 0))]
      end
      if @state.chain_active?
        @hud_lines << ['Chain mode: ON', hud_origin.offset(Geom::Vector3d.new(0, 32, 0))]
      end
      unless @state.snap_enabled?
        @hud_lines << ['Snap: OFF', hud_origin.offset(Geom::Vector3d.new(0, 48, 0))]
      end
    end
  end
end
