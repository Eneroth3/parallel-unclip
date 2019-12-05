module Eneroth
  module UnclipParallel
    PERSPECTIVE_ERROR =
      "#{EXTENSION.name} only functions on parallel projection cameras. "\
      "Clipping on perspective cameras has a different cause, to which this "\
      "solution can't be applied."

    # Find intersections between line and sphere.
    #
    # @param line [Array<(Geom::Point3d, Geom::Vector3d)>]
    # @param center [Geom::Point3d]
    # @param radius [Length]
    #
    # @return [Array<Geom::Point3d>] Array may contain 2, 1 or 0 points.
    def self.intersect_line_sphere(line, center, radius)
      raise ArgumentError "Invalid vector" unless line[1].valid?
      direction = line[1].normalize
      origin = line[0]

      if radius == 0
        return [] unless center.on_line? line
        return [center]
      end

      # Calculate distance d along line to intersections.
      # d = first_term +- sqrt(second_term_squared)
      first_term = -(direction % (origin - center))
      second_term_squared =
        (direction % (origin - center))**2 -
        (origin - center) % (origin - center) + radius**2

      # No intersection when second term is imaginary.
      return [] if second_term_squared < 0

      second_term = Math.sqrt(second_term_squared)

      d0 = first_term + second_term
      d1 = first_term - second_term

      point0 = origin.offset(direction, d0)
      point1 = origin.offset(direction, d1)

      return [point0] if point0 == point1

      [point0, point1]
    end

    # Find intersection between ray and sphere.
    #
    # @param ray [Array<(Geom::Point3d, Geom::Vector3d)>]
    # @param center [Geom::Point3d]
    # @param radius [Length]
    #
    # @return [Geom::Point3d, nil]
    def self.intersect_ray_sphere(ray, center, radius)
      intersections = intersect_line_sphere(ray, center, radius)
      intersections.select! { |pt| (pt - ray[0]) % ray[1] >= 0 }

      intersections.min_by { |pt| pt.distance(ray[0]) }
    end

    # Move camera backwards outside of model bounding box if it isn't already.
    def self.move_back
      model = Sketchup.active_model
      camera = model.active_view.camera

      point = intersect_ray_sphere(
        [camera.eye, camera.direction.reverse],
        model.bounds.center,
        model.bounds.diagonal / 2
      )
      return unless point

      camera.set(point, point.offset(camera.direction), camera.up)
    end

    # Remove clipping for parallel projection camera.
    def self.unclip
      if Sketchup.active_model.active_view.camera.perspective?
        UI.messagebox(PERSPECTIVE_ERROR)
        return
      end

      move_back
    end

    unless @loaded
      @loaded = true

      menu = UI.menu("Plugins")
      menu.add_item(EXTENSION.name) { unclip }
    end
  end
end
