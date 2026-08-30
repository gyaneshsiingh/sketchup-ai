require 'json'

module Pranjali
  module OpenCodeStudio
    # Extended skill set: parametric furniture kit, heuristic auto-layout,
    # style palettes and richer scene editing. Coordinates in METERS,
    # origin at room corner, +z up. Runs on SketchUp's main thread.
    module FurnitureTools
      D = DesignTools

      module_function

      def hex_material(model, hex)
        D.hex_material(model, hex)
      end

      def finish_group!(g, name, x, y, deg)
        g.name = name
        tr = D.rotation_transform(x, y, 0, deg)
        g.transform!(tr) if tr
        g
      end

      # ---- Parametric furniture kit ----

      def create_bed(a)
        model = Sketchup.active_model
        x = a['x_m'].to_f
        y = a['y_m'].to_f
        w = a['width_m'] || 1.5
        l = a['length_m'] || 2.0
        frame = hex_material(model, a['frame_color_hex'] || '#6B4A2F')
        mattress = hex_material(model, a['mattress_color_hex'] || '#F2F0EB')
        D.wrap_operation(model, 'AI: Create Bed') do
          g = model.active_entities.add_group
          e = g.entities
          D.add_box!(e, [x, y, 0.05], w, l, 0.25, frame)                # frame
          D.add_box!(e, [x + 0.05, y + 0.05, 0.3], w - 0.1, l - 0.1, 0.22, mattress) # mattress
          D.add_box!(e, [x, y + l - 0.08, 0.05], w, 0.08, 1.0, frame)   # headboard
          finish_group!(g, a['name'] || 'Bed', x, y, a['rotation_z_deg'])
          "Created bed (#{w}m x #{l}m) at (#{x.round(2)}, #{y.round(2)})."
        end
      end

      def create_sofa(a)
        model = Sketchup.active_model
        x = a['x_m'].to_f
        y = a['y_m'].to_f
        w = a['width_m'] || 2.0
        dep = a['depth_m'] || 0.9
        fabric = hex_material(model, a['color_hex'] || '#7A6A54')
        D.wrap_operation(model, 'AI: Create Sofa') do
          g = model.active_entities.add_group
          e = g.entities
          D.add_box!(e, [x, y, 0.05], w, dep, 0.35, fabric)               # base
          D.add_box!(e, [x, y + dep - 0.18, 0.05], w, 0.18, 0.75, fabric) # backrest
          D.add_box!(e, [x, y, 0.05], 0.2, dep, 0.55, fabric)             # left arm
          D.add_box!(e, [x + w - 0.2, y, 0.05], 0.2, dep, 0.55, fabric)   # right arm
          finish_group!(g, a['name'] || 'Sofa', x, y, a['rotation_z_deg'])
          "Created sofa (#{w}m x #{dep}m) at (#{x.round(2)}, #{y.round(2)})."
        end
      end

      def create_table(a)
        model = Sketchup.active_model
        x = a['x_m'].to_f
        y = a['y_m'].to_f
        w = a['width_m'] || 1.2
        dep = a['depth_m'] || 0.7
        h = a['height_m'] || 0.75
        wood = hex_material(model, a['color_hex'] || '#8B5A2B')
        D.wrap_operation(model, 'AI: Create Table') do
          g = model.active_entities.add_group
          e = g.entities
          D.add_box!(e, [x, y, h - 0.05], w, dep, 0.05, wood) # top
          leg = 0.08
          [[x, y], [x + w - leg, y], [x, y + dep - leg], [x + w - leg, y + dep - leg]].each do |lx, ly|
            D.add_box!(e, [lx, ly, 0], leg, leg, h - 0.05, wood)
          end
          finish_group!(g, a['name'] || 'Table', x, y, a['rotation_z_deg'])
          "Created table (#{w}m x #{dep}m x #{h}m) at (#{x.round(2)}, #{y.round(2)})."
        end
      end

      def create_wardrobe(a)
        model = Sketchup.active_model
        x = a['x_m'].to_f
        y = a['y_m'].to_f
        w = a['width_m'] || 1.8
        dep = a['depth_m'] || 0.6
        h = a['height_m'] || 2.2
        body = hex_material(model, a['color_hex'] || '#8B5A2B')
        accent = hex_material(model, a['door_color_hex'] || '#A67B4F')
        D.wrap_operation(model, 'AI: Create Wardrobe') do
          g = model.active_entities.add_group
          e = g.entities
          D.add_box!(e, [x, y, 0], w, dep, h, body)
          D.add_box!(e, [x + 0.02, y + dep - 0.02, 0.05], w / 2 - 0.05, 0.02, h - 0.15, accent)
          D.add_box!(e, [x + w / 2 + 0.03, y + dep - 0.02, 0.05], w / 2 - 0.05, 0.02, h - 0.15, accent)
          finish_group!(g, a['name'] || 'Wardrobe', x, y, a['rotation_z_deg'])
          "Created wardrobe (#{w}m x #{dep}m x #{h}m) at (#{x.round(2)}, #{y.round(2)})."
        end
      end

      def create_tv_unit(a)
        model = Sketchup.active_model
        x = a['x_m'].to_f
        y = a['y_m'].to_f
        w = a['width_m'] || 1.6
        dark = hex_material(model, a['color_hex'] || '#3E3428')
        D.wrap_operation(model, 'AI: Create TV Unit') do
          g = model.active_entities.add_group
          D.add_box!(g.entities, [x, y, 0], w, a['depth_m'] || 0.45, a['height_m'] || 0.5, dark)
          finish_group!(g, a['name'] || 'TV Unit', x, y, a['rotation_z_deg'])
          "Created TV unit (#{w}m) at (#{x.round(2)}, #{y.round(2)})."
        end
      end

      def create_wall(a)
        model = Sketchup.active_model
        x = a['x_m'].to_f
        y = a['y_m'].to_f
        l = a['length_m'] || 4.0
        h = a['height_m'] || 2.7
        t = a['thickness_m'] || 0.2
        mat = hex_material(model, a['color_hex'] || '#E8E4DE')
        D.wrap_operation(model, 'AI: Create Wall') do
          g = model.active_entities.add_group
          e = g.entities
          openings = (a['openings'] || []).map do |o|
            o.merge('sill_m' => o['sill_m'] || 0, 'head_m' => o['head_m'] || 2.1)
          end.sort_by { |o| o['offset_m'].to_f }
          cursor = 0.0
          openings.each do |o|
            start = o['offset_m'].to_f
            width = o['width_m'].to_f
            sill = o['sill_m'].to_f
            head = o['head_m'].to_f
            next if start >= l || width <= 0
            stop = [start + width, l].min
            D.add_box!(e, [x + cursor, y, 0], start - cursor, t, h, mat) if start > cursor
            D.add_box!(e, [x + start, y, 0], stop - start, t, sill, mat) if sill > 0
            D.add_box!(e, [x + start, y, head], stop - start, t, [h - head, 0].max, mat) if head < h
            cursor = stop
          end
          D.add_box!(e, [x + cursor, y, 0], l - cursor, t, h, mat) if cursor < l
          finish_group!(g, a['name'] || 'Wall', x, y, a['rotation_z_deg'])
          "Created wall (#{l}m) with #{openings.length} opening(s) at (#{x.round(2)}, #{y.round(2)})."
        end
      end

      # ---- Heuristic auto-layout ----
      # placer.call(room_w, room_d) => [x, y, rot, overrides_or_nil]
      # Negative y means "measured back from the far wall".
      LAYOUTS = {
        'bedroom' => [
          ['create_bed',      ->(w, _d) { [(w - 1.5) / 2, -2.1, 0] }],
          ['create_wardrobe', ->(_w, d) { [0.05, d - 0.7, 90] }],
          ['create_table',    ->(w, _d) { [w / 2 + 0.85, -0.55, 0,
                                           { 'name' => 'Side Table', 'width_m' => 0.45,
                                             'depth_m' => 0.45, 'height_m' => 0.55 }] }]
        ],
        'living' => [
          ['create_sofa',    ->(w, _d) { [(w - 2.0) / 2, 0.05, 0] }],
          ['create_table',   ->(w, d) { [(w - 1.0) / 2, d * 0.35, 0,
                                         { 'name' => 'Coffee Table', 'width_m' => 1.0,
                                           'depth_m' => 0.6, 'height_m' => 0.45 }] }],
          ['create_tv_unit', ->(w, d) { [(w - 1.6) / 2, d - 0.5, 180] }]
        ],
        'dining' => [
          ['create_table', ->(w, d) { [(w - 1.4) / 2, (d - 0.9) / 2, 0,
                                       { 'name' => 'Dining Table', 'width_m' => 1.4,
                                         'depth_m' => 0.9 }] }]
        ]
      }.freeze

      def auto_layout(a)
        model = Sketchup.active_model
        kind = a['room_type'].to_s.downcase
        layout = LAYOUTS[kind]
        return "ERROR: unknown room_type '#{kind}'. Known: #{LAYOUTS.keys.join(', ')}" unless layout

        w = a['width_m'].to_f
        dep = a['length_m'].to_f
        ox = 0.0
        oy = 0.0
        if (rn = a['room_name']) && !rn.to_s.empty?
          g = model.active_entities.grep(Sketchup::Group).find { |gr| gr.name == rn }
          if g
            b = g.bounds
            ox = D.len_to_m(b.min.x)
            oy = D.len_to_m(b.min.y)
            w = D.len_to_m(b.width) if w.zero?
            dep = D.len_to_m(b.depth) if dep.zero?
          end
        end
        return 'ERROR: width_m and length_m required (or a valid room_name)' if w.zero? || dep.zero?

        results = []
        layout.each do |tool, placer|
          pos = placer.call(w, dep)
          overrides = pos[3] || {}
          py = pos[1]
          py += dep if py.negative? # measured back from the far wall
          args = {
            'x_m' => (ox + pos[0]).round(3),
            'y_m' => (oy + py).round(3),
            'rotation_z_deg' => pos[2] || 0
          }.merge(overrides)
          results << D.call(tool, args)
        end
        "Auto-layout '#{kind}' applied to #{w.round(2)}m x #{dep.round(2)}m room:\n" + results.join("\n")
      end

      # ---- Style palettes ----
      STYLES = {
        'scandinavian' => { 'walls' => '#F4F1EC', 'floor' => '#D9C7A7', 'accent' => '#7A8B99' },
        'industrial'   => { 'walls' => '#A8A29B', 'floor' => '#5C5854', 'accent' => '#3E4142' },
        'luxury'       => { 'walls' => '#EFEAE3', 'floor' => '#4A3728', 'accent' => '#B08D57' },
        'bohemian'     => { 'walls' => '#F3E9DC', 'floor' => '#B98A5E', 'accent' => '#C96F4A' },
        'minimalist'   => { 'walls' => '#FFFFFF', 'floor' => '#E0DCD5', 'accent' => '#2B2B2B' }
      }.freeze

      def style_palette(a)
        model = Sketchup.active_model
        palette = STYLES[a['style'].to_s.downcase]
        return "ERROR: unknown style. Known: #{STYLES.keys.join(', ')}" unless palette

        D.wrap_operation(model, "AI: Style #{a['style']}") do
          groups = if a['group_name'] && !a['group_name'].to_s.empty?
                     [model.active_entities.grep(Sketchup::Group).find { |g| g.name == a['group_name'] }].compact
                   else
                     model.active_entities.grep(Sketchup::Group).first(25)
                   end
          wall_m = hex_material(model, palette['walls'])
          floor_m = hex_material(model, palette['floor'])
          accent_m = hex_material(model, palette['accent'])
          walls = floors = accents = 0
          groups.each do |g|
            gmin_z = g.bounds.min.z
            g.entities.grep(Sketchup::Face).each do |f|
              n = f.normal
              if n.z.abs < 0.1
                f.material = wall_m
                walls += 1
              elsif n.z > 0.7 && f.bounds.min.z - gmin_z < 0.35
                f.material = floor_m
                floors += 1
              else
                f.material = accent_m
                accents += 1
              end
            end
          end
          "Applied '#{a['style']}' palette: #{walls} wall face(s), #{floors} floor face(s), #{accents} accent face(s) across #{groups.length} group(s)."
        end
      end

      # ---- Scene editing ----

      def duplicate_object(a)
        model = Sketchup.active_model
        D.wrap_operation(model, 'AI: Duplicate') do
          g = model.active_entities.grep(Sketchup::Group).find { |gr| gr.name == a['group_name'] }
          next "ERROR: no group named '#{a['group_name']}'" if g.nil?
          copy = g.copy
          copy.transform!(Geom::Transformation.translation([
                                                             D.m_to_len(a['dx_m'] || 0),
                                                             D.m_to_len(a['dy_m'] || 0),
                                                             D.m_to_len(a['dz_m'] || 0)
                                                           ]))
          copy.name = a['new_name'] || "#{g.name}_copy"
          "Duplicated '#{g.name}' to '#{copy.name}'."
        end
      end

      def resize_group(a)
        model = Sketchup.active_model
        D.wrap_operation(model, 'AI: Resize') do
          g = model.active_entities.grep(Sketchup::Group).find { |gr| gr.name == a['group_name'] }
          next "ERROR: no group named '#{a['group_name']}'" if g.nil?
          b = g.bounds
          sx = a['width_m'] ? (D.m_to_len(a['width_m']) / b.width) : 1.0
          sy = a['depth_m'] ? (D.m_to_len(a['depth_m']) / b.depth) : 1.0
          sz = a['height_m'] ? (D.m_to_len(a['height_m']) / b.height) : 1.0
          g.transform!(Geom::Transformation.scaling(b.min, sx, sy, sz))
          "Resized '#{g.name}' to #{a['width_m'] || D.len_to_m(b.width).round(2)} x " \
            "#{a['depth_m'] || D.len_to_m(b.depth).round(2)} x " \
            "#{a['height_m'] || D.len_to_m(b.height).round(2)} m."
        end
      end

      def select_by_name(a)
        model = Sketchup.active_model
        pattern = a['pattern'].to_s.downcase
        matches = model.active_entities.grep(Sketchup::Group).select { |g| g.name.downcase.include?(pattern) }
        model.selection.clear
        matches.each { |m| model.selection.add(m) }
        "Selected #{matches.length} group(s) matching '#{pattern}'."
      end

      def list_components(_args = {})
        model = Sketchup.active_model
        defs = model.definition_list.map do |d|
          { 'name' => d.name, 'instances' => d.instances.length }
        end
        JSON.generate('components' => defs)
      end

      # ---- Registry (OpenAI + MCP tool schema) ----
      NUM = { 'type' => 'number' }.freeze
      STR = { 'type' => 'string' }.freeze
      M_SCHEMA = { 'type' => 'object', 'properties' => {} }.freeze
      XYZ = { 'x_m' => NUM, 'y_m' => NUM, 'rotation_z_deg' => NUM }.freeze
      OPENING = {
        'type' => 'object',
        'properties' => { 'offset_m' => NUM, 'width_m' => NUM, 'sill_m' => NUM, 'head_m' => NUM },
        'required' => %w[offset_m width_m]
      }.freeze

      DEFINITIONS = [
        { type: 'function', function: { name: 'create_bed', description: 'Parametric bed with mattress + headboard at position.', parameters: { 'type' => 'object', 'properties' => XYZ.merge('name' => STR, 'width_m' => NUM, 'length_m' => NUM, 'frame_color_hex' => STR, 'mattress_color_hex' => STR), 'required' => %w[x_m y_m] } } },
        { type: 'function', function: { name: 'create_sofa', description: 'Parametric sofa (base, backrest, arms) at position.', parameters: { 'type' => 'object', 'properties' => XYZ.merge('name' => STR, 'width_m' => NUM, 'depth_m' => NUM, 'color_hex' => STR), 'required' => %w[x_m y_m] } } },
        { type: 'function', function: { name: 'create_table', description: 'Parametric table (top + 4 legs).', parameters: { 'type' => 'object', 'properties' => XYZ.merge('name' => STR, 'width_m' => NUM, 'depth_m' => NUM, 'height_m' => NUM, 'color_hex' => STR), 'required' => %w[x_m y_m] } } },
        { type: 'function', function: { name: 'create_wardrobe', description: 'Parametric wardrobe with door panels.', parameters: { 'type' => 'object', 'properties' => XYZ.merge('name' => STR, 'width_m' => NUM, 'depth_m' => NUM, 'height_m' => NUM, 'color_hex' => STR, 'door_color_hex' => STR), 'required' => %w[x_m y_m] } } },
        { type: 'function', function: { name: 'create_tv_unit', description: 'Low TV/media unit.', parameters: { 'type' => 'object', 'properties' => XYZ.merge('name' => STR, 'width_m' => NUM, 'depth_m' => NUM, 'height_m' => NUM, 'color_hex' => STR), 'required' => %w[x_m y_m] } } },
        { type: 'function', function: { name: 'create_wall', description: 'Straight wall with optional door/window openings (offset_m from wall start, sill_m 0 = door).', parameters: { 'type' => 'object', 'properties' => XYZ.merge('name' => STR, 'length_m' => NUM, 'height_m' => NUM, 'thickness_m' => NUM, 'color_hex' => STR, 'openings' => { 'type' => 'array', 'items' => OPENING }), 'required' => %w[x_m y_m length_m] } } },
        { type: 'function', function: { name: 'auto_layout', description: 'Place a heuristic furniture set: bedroom (bed/wardrobe/side table), living (sofa/coffee table/TV) or dining. Give width_m+length_m, or room_name of an existing room group.', parameters: { 'type' => 'object', 'properties' => { 'room_type' => { 'type' => 'string', 'enum' => %w[bedroom living dining] }, 'width_m' => NUM, 'length_m' => NUM, 'room_name' => STR }, 'required' => %w[room_type] } } },
        { type: 'function', function: { name: 'style_palette', description: 'Apply a coordinated palette (walls/floor/accents) to one group or the whole model.', parameters: { 'type' => 'object', 'properties' => { 'style' => { 'type' => 'string', 'enum' => STYLES.keys }, 'group_name' => STR }, 'required' => %w[style] } } },
        { type: 'function', function: { name: 'duplicate_object', description: 'Copy a named group by a delta in meters.', parameters: { 'type' => 'object', 'properties' => { 'group_name' => STR, 'new_name' => STR, 'dx_m' => NUM, 'dy_m' => NUM, 'dz_m' => NUM }, 'required' => %w[group_name] } } },
        { type: 'function', function: { name: 'resize_group', description: 'Scale a named group to target width/depth/height in meters.', parameters: { 'type' => 'object', 'properties' => { 'group_name' => STR, 'width_m' => NUM, 'depth_m' => NUM, 'height_m' => NUM }, 'required' => %w[group_name] } } },
        { type: 'function', function: { name: 'select_by_name', description: 'Select all groups whose name contains the pattern.', parameters: { 'type' => 'object', 'properties' => { 'pattern' => STR }, 'required' => %w[pattern] } } },
        { type: 'function', function: { name: 'list_components', description: 'List component definitions available in the model (use before place_component).', parameters: M_SCHEMA } }
      ].freeze

      def definitions
        DEFINITIONS
      end
    end
  end
end
