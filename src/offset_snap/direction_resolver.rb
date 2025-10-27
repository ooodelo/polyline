# frozen_string_literal: true

module OffsetSnapTool
  class DirectionResolver
    attr_reader :locked_direction

    def initialize
      @mode = :free
      @locked_direction = nil
    end

    def mode
      @mode
    end

    def clear_lock
      @mode = :free
      @locked_direction = nil
    end

    def lock_axis(axis_vector)
      vector = axis_vector.clone
      return if vector.length.zero?

      vector.normalize!
      @locked_direction = vector
      @mode = case axis_vector
              when OffsetSnapTool::X_AXIS then :axis_x
              when OffsetSnapTool::Y_AXIS then :axis_y
              when OffsetSnapTool::Z_AXIS then :axis_z
              else :axis
              end
    end

    def lock_edge(edge, transformation)
      return unless edge

      direction = Geom::Vector3d.new(edge.line[1])
      direction.transform!(transformation) if transformation
      return if direction.length.zero?

      direction.normalize!
      @locked_direction = direction
      @mode = :edge_parallel
    end

    def lock_face(face, transformation)
      return unless face

      normal = Geom::Vector3d.new(face.normal)
      if transformation && transformation != OffsetSnapTool::IDENTITY
        normal.transform!(transformation.inverse.transpose)
      end
      return if normal.length.zero?

      normal.normalize!
      @locked_direction = normal
      @mode = :face_normal
    end

    def calculate_direction(view, x, y, base_point)
      return @locked_direction if @locked_direction

      origin, ray_dir = view.pickray(x, y)
      return nil unless origin && ray_dir

      if base_point
        dir = Geom::Vector3d.new(ray_dir)
        return nil if dir.length.zero?

        dir.normalize!
        t = dir.dot(base_point - origin) / dir.dot(dir)
        closest = origin + dir * t
        vector = closest - base_point
        vector = dir if vector.length < 1e-6
        vector.normalize!
        vector
      else
        dir = Geom::Vector3d.new(ray_dir)
        dir.normalize!
        dir
      end
    end
  end
end
