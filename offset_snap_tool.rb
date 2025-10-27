# frozen_string_literal: true

require 'sketchup.rb'
require 'extensions.rb'

module OffsetSnapTool
  unless const_defined?(:PLUGIN_ID)
    PLUGIN_ID = 'com.offsetsnap.tool'.freeze
    PLUGIN_NAME = 'Offset Snap Tool'.freeze
    PLUGIN_PATH = File.join(__dir__, 'offset_snap', 'loader.rb').freeze
  end

  extension = SketchupExtension.new(PLUGIN_NAME, PLUGIN_PATH)
  extension.version = '1.0.0'
  extension.description = 'Interactive offset tool with snapping support.'
  extension.creator = 'Offset Snap Tool Authors'
  extension.copyright = '© Offset Snap Tool Authors'
  extension.id = PLUGIN_ID if extension.respond_to?(:id=)

  Sketchup.register_extension(extension, true)
end
