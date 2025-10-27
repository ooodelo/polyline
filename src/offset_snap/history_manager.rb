# frozen_string_literal: true

module OffsetSnapTool
  class HistoryManager
    KEY = 'OffsetSnapTool'
    ATTR = 'offset_history'
    LIMIT = 10

    def initialize
      @values = load_history
    end

    def remember(value)
      return unless value.is_a?(Numeric)

      @values.delete_if { |v| (v - value).abs < 1e-4 }
      @values.unshift(value)
      @values = @values.take(LIMIT)
      persist
    end

    def last
      @values.first
    end

    def last_formatted
      return '' unless last

      Sketchup.format_length(last)
    end

    def reset
      @values.clear
      persist
    end

    private

    def load_history
      stored = Sketchup.read_default(KEY, ATTR)
      stored = '[]' if stored.nil? || stored.empty?
      JSON.parse(stored).map(&:to_f)
    rescue StandardError
      []
    end

    def persist
      Sketchup.write_default(KEY, ATTR, JSON.dump(@values))
    end
  end
end
