# frozen_string_literal: true

module OffsetSnapTool
  class GeometryCreator
    def initialize(model)
      @model = model
    end

    def create_point(point)
      with_operation('Create Offset Point') do |entities|
        entities.add_cpoint(point)
      end
    end

    def create_edge(start_point, end_point)
      with_operation('Create Offset Edge') do |entities|
        entities.add_line(start_point, end_point)
      end
    end

    private

    def with_operation(name)
      @model.start_operation(name, true, false, true)
      entities = @model.active_entities
      yield entities
      @model.commit_operation
    rescue StandardError
      @model.abort_operation
      raise
    end
  end
end
