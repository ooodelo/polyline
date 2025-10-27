# frozen_string_literal: true

require 'json'

module OffsetSnapTool
  IDENTITY = Geom::Transformation.new.freeze
  X_AXIS = Geom::Vector3d.new(1, 0, 0).freeze
  Y_AXIS = Geom::Vector3d.new(0, 1, 0).freeze
  Z_AXIS = Geom::Vector3d.new(0, 0, 1).freeze
end

require_relative 'state_manager'
require_relative 'snap_engine'
require_relative 'direction_resolver'
require_relative 'offset_calculator'
require_relative 'renderer'
require_relative 'ui_feedback'
require_relative 'geometry_creator'
require_relative 'history_manager'
require_relative 'tool'

module OffsetSnapTool
  def self.activate_tool
    Sketchup.active_model.select_tool(OffsetSnapTool::Tool.new)
  end

  def self.register_command
    return if const_defined?(:COMMAND)

    command = UI::Command.new('Offset Snap Tool') do
      OffsetSnapTool.activate_tool
    end

    const_set(:COMMAND, command)
    UI.menu('Tools').add_item(command)
  end
end

if defined?(Sketchup) && Sketchup.respond_to?(:active_model)
  OffsetSnapTool.register_command
end
