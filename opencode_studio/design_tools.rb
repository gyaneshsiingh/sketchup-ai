require 'json'

module Pranjali
  module OpenCodeStudio
    # Built-in "skills" the AI agent can call. All coordinates are in METERS,
    # origin at the room corner, +z up. Every method executes on SketchUp's
    # main thread (scheduled by MainThreadRunner).
    module DesignTools
      INCH = 39.3700787401574803 # inches per meter
      METERS = 1.0 / INCH

      module_function

      def m_to_len(m)
        m.to_f * INCH
      end

      def len_to_m(len)
        len.to_f * METERS
      end

      def hex_material(model, hex)
        return nil if hex.nil? || hex.to_s.strip.empty?
        clean = hex.to_s.strip
        clean = "##{clean}" unless clean.start_with?('#')
        name = "AI_#{clean.delete('#').upcase}"
        mat = model.materials[name]
        return mat if mat
        mat = model.materials.add(name)
        mat.color = Sketchup::Color.new(clean)
        mat
      rescue StandardError
        nil
      end

      def wrap_operation(model, label)
        model.start_operation(label, true)
        result = yield
        model.commit_operation
        result
      rescue StandardError => e
        model.abort_operation
        raise e
      end

      def add_box!(entities, origin, w, d, h, mat)
        x, y, z = origin.map { |v| m_to_len(v) }
        pts = [
          Geom::Point3d.new(x, y, z),
          Geom::Point3d.new(x + m_to_len(w), y, z),
          Geom::Point3d.new(x + m_to_len(w), y + m_to_len(d), z),
          Geom::Point3d.new(x, y + m_to_len(d), z)
        ]
        face = entities.add_face(pts)
        face.reverse! if face.normal.z < 0
        face.pushpull(m_to_len(h))
        entities.grep(Sketchup::Face).each { |f| f.material = mat if mat }
        true
      end

      def rotation_transform(cx, cy, cz, deg)
        return nil if deg.to_f.zero?
        origin = Geom::Point3d.new(m_to_len(cx), m_to_len(cy), m_to_len(cz))
        Geom::Transformation.rotation(origin, Geom::Vector3d.new(0, 0, 1), deg.to_f * Math::PI / 180.0)
      end

      # ---- Tool implementations (all return a String result) ----

      def query_scene(_args = {})
        model = Sketchup.active_model
        groups = model.active_entities.grep(Sketchup::Group).first(60).map do |g|
          b = g.bounds
          {
            'name' => g.name,
            'size_m' => {
              'w' => len_to_m(b.width).round(3),
              'd' => len_to_m(b.depth).round(3),
              'h' => len_to_m(b.height).round(3)
            }
          }
        end
        JSON.generate(
          'model_name' => model.title,
          'units_note' => 'all tool inputs/outputs are meters',
          'top_level_entities' => model.active_entities.length,
          'groups' => groups,
          'selection_count' => model.selection.length
        )
      end

      def create_room(a)
        model = Sketchup.active_model
        name = a['name'] || 'Room'
        w = a['width_m'] || 4.0
        d = a['length_m'] || 5.0
        h = a['height_m'] || 2.7
        t = a['wall_thickness_m'] || 0.2

        wrap_operation(model, "AI: Create Room #{name}") do
          ents = model.active_entities
          room = ents.add_group
          room.name = name
          re = room.entities

          floor_mat = hex_material(model, a['floor_color_hex'])
          floor = re.add_face([
                                Geom::Point3d.new(0, 0, 0),
                                Geom::Point3d.new(m_to_len(w), 0, 0),
                                Geom::Point3d.new(m_to_len(w), m_to_len(d), 0),
                                Geom::Point3d.new(0, m_to_len(d), 0)
                              ])
          floor.reverse! if floor.normal.z < 0
          floor.pushpull(m_to_len(0.1))
          re.grep(Sketchup::Face).each { |f| f.material = floor_mat if floor_mat }

          wall_mat = hex_material(model, a['wall_color_hex'])
          walls = [
            [0, 0, w, t],
            [0, d - t, w, t],
            [0, t, t, d - 2 * t],
            [w - t, t, t, d - 2 * t]
          ]
          walls.each_with_index do |(wx, wy, ww, wd), i|
            g = re.add_group
            g.name = "Wall_#{i + 1}"
            add_box!(g.entities, [wx, wy, 0], ww, wd, h, wall_mat)
          end
          "Created room '#{name}' (#{w}m x #{d}m x #{h}m) with floor + 4 walls at origin."
        end
      end

      def create_box(a)
        model = Sketchup.active_model
        name = a['name'] || 'Object'
        wrap_operation(model, "AI: Create #{name}") do
          ents = model.active_entities
          g = ents.add_group
          g.name = name
          mat = hex_material(model, a['color_hex'])
          add_box!(g.entities,
                   [a['x_m'].to_f, a['y_m'].to_f, a['z_m'].to_f],
                   a['width_m'] || 0.5, a['depth_m'] || 0.5, a['height_m'] || 0.5, mat)
          tr = rotation_transform(a['x_m'].to_f, a['y_m'].to_f, a['z_m'].to_f, a['rotation_z_deg'])
          g.transformation = tr if tr
          "Created '#{name}' at (#{a['x_m']}, #{a['y_m']}, #{a['z_m']}) m."
        end
      end

      def place_component(a)
        model = Sketchup.active_model
        cname = a['component_name'].to_s
        fallback = a['fallback_name'] || cname
        wrap_operation(model, "AI: Place #{cname}") do
          defn = model.definition_list.find do |d|
            d.name.downcase.include?(cname.downcase)
          end
          ents = model.active_entities
          x = a['x_m'].to_f
          y = a['y_m'].to_f
          z = a['z_m'].to_f
          if defn
            t = Geom::Transformation.new([m_to_len(x), m_to_len(y), m_to_len(z)])
            rot = rotation_transform(x, y, z, a['rotation_z_deg'])
            t = rot * t if rot
            inst = ents.add_instance(defn, t)
            inst.name = fallback
            "Placed component '#{defn.name}' at (#{x}, #{y}, #{z}) m."
          else
            g = ents.add_group
            g.name = fallback
            mat = hex_material(model, a['color_hex'])
            add_box!(g.entities, [x, y, z],
                     a['fallback_width_m'] || 0.6, a['fallback_depth_m'] || 0.6,
                     a['fallback_height_m'] || 0.75, mat)
            tr = rotation_transform(x, y, z, a['rotation_z_deg'])
            g.transformation = tr if tr
            "No component named '#{cname}' in model; placed a placeholder box '#{fallback}' instead."
          end
        end
      end

      def apply_color(a)
        model = Sketchup.active_model
        mat = hex_material(model, a['hex'])
        return 'ERROR: invalid color' unless mat
        count = 0
        wrap_operation(model, "AI: Paint #{a['hex']}") do
          targets = model.selection.to_a
          targets = model.active_entities.grep(Sketchup::Group).last(1) if targets.empty? && a['target'] == 'last_group'
          targets.each do |e|
            faces = case e
                    when Sketchup::Face then [e]
                    when Sketchup::Group, Sketchup::ComponentInstance
                      e.entities.grep(Sketchup::Face)
                    else []
                    end
            faces.each do |f|
              f.material = mat
              count += 1
            end
          end
          "Painted #{count} face(s) with #{a['hex']}."
        end
      end

      def delete_selection(_args = {})
        model = Sketchup.active_model
        wrap_operation(model, 'AI: Delete Selection') do
          n = model.selection.length
          model.selection.to_a.each(&:erase!)
          "Deleted #{n} object(s)."
        end
      end

      def move_group(a)
        model = Sketchup.active_model
        wrap_operation(model, 'AI: Move') do
          g = model.active_entities.grep(Sketchup::Group).find { |gr| gr.name == a['group_name'] }
          next "ERROR: no group named '#{a['group_name']}'" if g.nil?
          t = Geom::Transformation.translation([
                                                 m_to_len(a['dx_m'] || 0),
                                                 m_to_len(a['dy_m'] || 0),
                                                 m_to_len(a['dz_m'] || 0)
                                               ])
          g.transform!(t)
          "Moved '#{g.name}'."
        end
      end

      def rotate_group(a)
        model = Sketchup.active_model
        wrap_operation(model, 'AI: Rotate') do
          g = model.active_entities.grep(Sketchup::Group).find { |gr| gr.name == a['group_name'] }
          next "ERROR: no group named '#{a['group_name']}'" if g.nil?
          b = g.bounds
          origin = Geom::Point3d.new(b.center.x, b.center.y, b.center.z)
          tr = Geom::Transformation.rotation(origin, Geom::Vector3d.new(0, 0, 1), a['angle_deg'].to_f * Math::PI / 180.0)
          g.transform!(tr)
          "Rotated '#{g.name}' by #{a['angle_deg']} degrees."
        end
      end

      def set_units(a)
        model = Sketchup.active_model
        units = { 'inches' => 0, 'feet' => 1, 'mm' => 2, 'cm' => 3, 'meters' => 4 }
        idx = units[a['unit'].to_s.downcase]
        return "ERROR: unknown unit '#{a['unit']}'" unless idx
        model.options['UnitsOptions']['LengthUnit'] = idx
        model.options['UnitsOptions']['LengthPrecision'] = 3
        "Units set to #{a['unit']}."
      rescue StandardError => e
        "ERROR: #{e.message}"
      end

      def add_tag(a)
        model = Sketchup.active_model
        layer = model.layers.add(a['name'].to_s)
        "Tag '#{layer.name}' created. Use SketchUp's Tags panel to assign it."
      rescue StandardError => e
        "ERROR: #{e.message}"
      end

      def zoom_extents(_args = {})
        Sketchup.active_model.active_view.zoom_extents
        'Zoomed to extents.'
      end

      # ---- Registry consumed by the agent ----
      # Args use JSON Schema; keep descriptions tight to steer the model.
      M_SCHEMA = { 'type' => 'object', 'properties' => {}, 'additionalProperties' => false }.freeze
      NUM = { 'type' => 'number' }.freeze

      DEFINITIONS = [
        { type: 'function', function: { name: 'query_scene', description: 'Inspect the current SketchUp model: groups, sizes (meters), selection.', parameters: M_SCHEMA } },
        { type: 'function', function: { name: 'create_room', description: 'Build a room: floor slab + 4 walls, origin at room corner. Input in meters.', parameters: { 'type' => 'object', 'properties' => { 'name' => { 'type' => 'string' }, 'width_m' => NUM, 'length_m' => NUM, 'height_m' => NUM, 'wall_thickness_m' => NUM, 'wall_color_hex' => { 'type' => 'string' }, 'floor_color_hex' => { 'type' => 'string' } }, 'required' => %w[name width_m length_m] } } },
        { type: 'function', function: { name: 'create_box', description: 'Create a box (generic furniture/solid) at position in meters.', parameters: { 'type' => 'object', 'properties' => { 'name' => { 'type' => 'string' }, 'x_m' => NUM, 'y_m' => NUM, 'z_m' => NUM, 'width_m' => NUM, 'depth_m' => NUM, 'height_m' => NUM, 'rotation_z_deg' => NUM, 'color_hex' => { 'type' => 'string' } }, 'required' => %w[name x_m y_m z_m] } } },
        { type: 'function', function: { name: 'place_component', description: 'Place an existing component by (partial) name; falls back to a placeholder box.', parameters: { 'type' => 'object', 'properties' => { 'component_name' => { 'type' => 'string' }, 'x_m' => NUM, 'y_m' => NUM, 'z_m' => NUM, 'rotation_z_deg' => NUM, 'fallback_name' => { 'type' => 'string' }, 'fallback_width_m' => NUM, 'fallback_depth_m' => NUM, 'fallback_height_m' => NUM, 'color_hex' => { 'type' => 'string' } }, 'required' => %w[component_name x_m y_m z_m] } } },
        { type: 'function', function: { name: 'apply_color', description: 'Apply a hex color to all faces in the current selection.', parameters: { 'type' => 'object', 'properties' => { 'hex' => { 'type' => 'string' }, 'target' => { 'type' => 'string', 'enum' => ['selection'] } }, 'required' => %w[hex] } } },
        { type: 'function', function: { name: 'delete_selection', description: 'Erase everything in the current selection.', parameters: M_SCHEMA } },
        { type: 'function', function: { name: 'move_group', description: 'Move a named group by delta in meters.', parameters: { 'type' => 'object', 'properties' => { 'group_name' => { 'type' => 'string' }, 'dx_m' => NUM, 'dy_m' => NUM, 'dz_m' => NUM }, 'required' => %w[group_name] } } },
        { type: 'function', function: { name: 'rotate_group', description: 'Rotate a named group around its center (z axis), degrees.', parameters: { 'type' => 'object', 'properties' => { 'group_name' => { 'type' => 'string' }, 'angle_deg' => NUM }, 'required' => %w[group_name angle_deg] } } },
        { type: 'function', function: { name: 'set_units', description: 'Set model display units.', parameters: { 'type' => 'object', 'properties' => { 'unit' => { 'type' => 'string', 'enum' => ['inches', 'feet', 'mm', 'cm', 'meters'] } }, 'required' => %w[unit] } } },
        { type: 'function', function: { name: 'add_tag', description: 'Create a tag (layer) in the model.', parameters: { 'type' => 'object', 'properties' => { 'name' => { 'type' => 'string' } }, 'required' => %w[name] } } },
        { type: 'function', function: { name: 'zoom_extents', description: 'Zoom the view to fit the whole model.', parameters: M_SCHEMA } }
      ].freeze

      def definitions
        defs = DEFINITIONS.dup
        defs += FurnitureTools.definitions if defined?(FurnitureTools)
        defs
      end

      def call(name, args)
        name = name.to_s
        target = if DesignTools.respond_to?(name)
                   DesignTools
                 elsif defined?(FurnitureTools) && FurnitureTools.respond_to?(name)
                   FurnitureTools
                 end
        return "ERROR: unknown tool '#{name}'" unless target
        target.send(name, args || {})
      rescue StandardError => e
        "ERROR: #{e.class}: #{e.message}"
      end
    end
  end
end
