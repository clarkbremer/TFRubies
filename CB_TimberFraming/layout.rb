##  load "C:/Users/clark/Google Drive/TF/Sketchup/Rubies/CB_TimberFraming/CB_TimberFraming/layout.rb"

module CB_TF
    def CB_TF.send_shops_to_layout
        model = Sketchup.active_model
        scenes = model.pages
        tf_iso_scene = nil
        tf_shops_scene = nil
        scenes.each_with_index do |scene, i|
            if scene.name == "tf_shops"
                tf_shops_scene = i
            end
            if scene.name == "tf_iso"
                tf_iso_scene = i
            end
        end

        if tf_iso_scene == nil and tf_shops_scene == nil
            UI.messagebox("This does not look like a shop drawing model (missing special scenes)")
            return
        end

        # find the iso_timber, which is where we stashed the project name
        project_name = nil
        model.entities.each do |ent|
            if ent.name == "iso_timber"
                project_name = ent.get_attribute(JAD, "project_name")
                break
            end
        end

        puts "project_name: #{project_name}"
        unless project_name
            UI.messagebox("This does not look like a shop drawing model (missing iso_timber)")
            return
        end

        unless model.modified?
            save_status = model.save()
            unless save_status
                UI.messagebox("Shop drawing model must be saved before sending to layout")
                return
            end
        end

        layout_file_name = "#{File.dirname(model.path)}\\#{project_name}.layout"

        puts "layout_file_name: #{layout_file_name}"
        if layout_file_name && File.exists?(layout_file_name)
            doc =  Layout::Document.open(layout_file_name)
        else
            puts "doc not found, creating new"
            template_file_name = UI.openpanel("Choose a Layout Template", "", "Layout|*.layout||")
            puts "template_file_name: #{template_file_name}"
            return unless template_file_name
            doc = Layout::Document.new(template_file_name)
            page = doc.pages.first
            page.name = "Cover Page"
            pi = doc.page_info
            layer = doc.layers.add(model.title)
            layer.set_nonshared(page, Layout::Layer::UNSHARELAYERACTION_CLEAR)

            anchor = Geom::Point2d.new(pi.width / 2, pi.height / 2)
            text = Layout::FormattedText.new("#{project_name} Shop Drawings", anchor, Layout::FormattedText::ANCHOR_TYPE_CENTER_CENTER)
            style = text.style
            style.font_size = 36.0
            text.style = style
            doc.add_entity(text, layer, page)
            doc.save(layout_file_name)
        end

        pages = doc.pages
        existing_page = nil
        pages.each { |page| existing_page = page if page.name == model.title }
        if existing_page
            result = UI.messagebox("Page '#{model.title}' already exists.  Overwrite?", MB_YESNO)
            if result == IDYES
                result = pages.remove(existing_page)
            else
                UI.messagebox("Page not saved to layout")
                return
            end
        end

        page = pages.add(model.title)
        layer = doc.layers.add(model.title)
        layer.set_nonshared(page, Layout::Layer::UNSHARELAYERACTION_CLEAR)
        page.set_layer_visibility(layer, true)
        pi = doc.page_info

        # add iso viewport
        view_bounds = Geom::Bounds2d.new(
        pi.left_margin + (pi.width * 0.75),  
        pi.top_margin + 0.1,
        (pi.width / 5) - (pi.left_margin + pi.right_margin),
        pi.height - (pi.top_margin + pi.bottom_margin) - 0.2
        )
        viewport = Layout::SketchUpModel.new(model.path, view_bounds)
        viewport.current_scene = tf_iso_scene + 1
        doc.add_entity( viewport, layer, page )
        viewport.render_mode= Layout::SketchUpModel::RASTER_RENDER
        viewport.render if viewport.render_needed?

        # add shops viewport
        view_bounds = Geom::Bounds2d.new(
        pi.left_margin + 1,  
        pi.top_margin + 0.1,
        (pi.width * 3 / 4) - (pi.left_margin + pi.right_margin),
        ( pi.height - (pi.top_margin + pi.bottom_margin) ) * 0.75
        )
        viewport = Layout::SketchUpModel.new(model.path, view_bounds)
        viewport.current_scene = tf_shops_scene + 1
        doc.add_entity( viewport, layer, page )
        viewport.render_mode= Layout::SketchUpModel::HYBRID_RENDER
        viewport.render if viewport.render_needed?

        # add_auto_dimensions(viewport)

        begin
            doc.save
        rescue ArgumentError  => err
            UI.messagebox("Error saving layout file (#{err}).  Is it open in Layout?")
            return
        end
        UI.messagebox("Page #{model.title} added to #{project_name}")

    end


    ##############################################
    ##
    ##  *** EXPERIMENTAL ***
    ##
    ##  Add auto-dimensions to shop drawings
    ##
    def CB_TF.add_auto_dimensions(layout_model)
        puts "Adding Dimensions to shop drawings"

        model = Sketchup.active_model
        lowest_z = 1000
        ci = nil

        model.entities.each do |ent|
            next if ent.hidden?
            next unless ent.instance_of? Sketchup::ComponentInstance
            p = ent.bounds.center
            p.transform!ent.transformation
            if p.z < lowest_z
                lowest_z = p.z 
                ci = ent
            end
        end
        return unless ci # no instances?

        cd = ci.definition
        lowest_z = 1000;

        end_eps = []
        cd.entities.each do |ent|
            if ent.instance_of? Sketchup::Face
                p = ent.bounds.center
                p.transform!ci.transformation
                lowest_z = p.z if p.z < lowest_z
            end
            next unless ent.instance_of? Sketchup::ComponentInstance
            next unless ent.definition.get_attribute( JAD, "tenon", false)
            next if ent.hidden?
            puts "ent found: #{ent.definition.name}"
            end_point = Geom::Point3d.new(0,0,0)
            end_point.transform!ent.transformation  # origin of ent in timber space
            puts "Origin of ent in timber coordinates: #{end_point.to_s}"
            end_point.transform!ci.transformation  # origin of ent in global space
            puts "Origin of ent in global coordinates: #{end_point.to_s}"
            end_point.y = 0
            end_eps << { pt: end_point, ci: ci, pid: ci.persistent_id }
        end

        start_point = Geom::Point3d.new(0,0,0)
        start_vertex = cd.entities.add_cpoint(start_point)
        # start_vertex = vertex_at_origin(ci)
        puts "start_vertex: #{start_vertex.position.inspect}"
        start_point.transform!ci.transformation  # origin of timber in global space
        puts "Origin of timber in global coordinates: #{start_point.to_s}"

        start_point.y = 0
        start_point.z = lowest_z
        # remove duplicates (note that uniq! won't work, as these x are "Length" objects, not ints.)
        end_eps.delete_if do |ep|
            end_eps[end_eps.index(ep)+1..-1].any? { |other| ep[:pt] == other[:pt] }
        end

        # sort by X distance
        end_eps.sort! do |a, b|
            a[:pt].x <=> b[:pt].x
        end

        puts "layout_model: #{layout_model.inspect}, start_point: #{start_point.inspect}, pid: #{ci.persistent_id.inspect}"

        # layout_model.entities.entities.each do |ent|
        #     puts "Layout Model Ent: #{ent.inspect}"
        #     if ent.instance_of? Layout::Group
        #         ent.entities.each do |ee|
        #             puts "\tLayout Groups Ent: #{ee.inspect}"
        #             if ee.instance_of? Layout::Group
        #                 ee.entities.each do |eee|
        #                     puts "\t\tLayout Groups Ent: #{eee.inspect}"
        #                 end
        #             end
        
        #         end
        #     end
        # end        

        # start_cp = Layout::ConnectionPoint.new(layout_model, start_point, ci.persistent_id.to_s)
        start_cp = Layout::ConnectionPoint.new(layout_model, start_point, ci.persistent_id.to_s)

        z_offset = 1
        end_eps.each do |ep|
            puts "Adding dimension linear with: "
            puts "  start_point: #{start_point}"
            puts "  end_point: #{ep[:pt]}"
            puts "  z_offset: #{z_offset}"
            # end_cp = Layout::ConnectionPoint.new(layout_model, ep[:pt], ep[:pid])
            end_cp = Layout::ConnectionPoint.new(layout_model, ep[:pt])
    #        dim = model.active_entities.add_dimension_linear(start_point, ep, [0,0,z_offset])
            dim = Layout::LinearDimension.new(Geom::Point2d.new(1, 1), Geom::Point2d.new(2, 2), z_offset)
            dim.connect(start_cp, end_cp)
            z_offset += 0.25
        end

        puts "done adding dimensions to shop drawings"
    end

    # def CB_TF.auto_dimension_mortise(mortise)
    #     mm = Sketchup.active_model
    #     cd = mortise.definition
    #     puts "Auto-dimension mortise: #{cd.name}"
    #     td = mortise.parent
    #     ti = mm.active_path.first

    #     # are we looking "into" the mortise, or looking at a profile?
    #     # Find frontmost face of timber

    #     frontmost = 10000
    #     ff = nil
    #     ti.definition.entities.each do |face|
    #     next unless face.instance_of? Sketchup::Face
    #     ctr = face.bounds.center
    #     ctr.transform!ti.transformation
    #     if ctr.y < frontmost
    #         frontmost = ctr.y
    #         ff = face
    #     end
    #     end
    #     puts "frontmost face of timber is #{ff}"
    #     puts "    with y of #{ff.bounds.center.y}"

    #     jnv = Geom::Vector3d.new(0,0,1)   # joint normal vector
    #     jo = Geom::Point3d.new(0,0,0)  # joint origin
    #     jnv.transform!mortise.transformation
    #     jo.transform!mortise.transformation
    #     if (ff.normal == jnv) or (ff.normal == jnv.reverse)
    #     if ff.classify_point(jo) >= 1 and ff.classify_point(jo) <= 4
    #         puts("normals match and attached to front - this joint is facing us.")
    #         auto_dimension_mortise_facing(mortise, ti)
    #     else
    #         puts("normals match, but not attached to front - this joint is on the backside.")
    #     end
    #     else
    #     puts("normals dont match - this joint is not facing us.")
    #     auto_dimension_mortise_profile(mortise, ti)
    #     end
    # end

    # def CB_TF.auto_dimension_mortise_facing(mortise, ti)
    # end

    # def CB_TF.auto_dimension_mortise_profile(mortise, ti)
    # end

end #module