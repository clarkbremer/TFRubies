##  load "G:/My Drive/TF/Sketchup/Rubies/CB_TimberFraming/CB_TimberFraming/layout.rb"
require 'date'
module CB_TF
    def CB_TF.batch_shops_to_layout
        model = Sketchup.active_model
        unless shop_drawing_model?(model)
            UI.messagebox("This does not look like a shop drawing model (missing special scenes)")
            return
        end
        first_file_name = model.path
        directory = File.dirname(first_file_name)
        project_name = get_project_name(model)

        message = <<~MSG
        **** CAUTION *****

        All *.skp files in the folder
        #{directory}
        will be added to the layout doc
        #{project_name}.layout 

        This can take a while.
       
        Proceed?
        MSG
        
        result = UI.messagebox(message, MB_YESNO)
        if result != IDYES
            return
        end

        doc = open_or_create_layout_doc(project_name, File.dirname(first_file_name))
        return unless doc

        count = 0

        result = append_page_to_layout(model, doc, true)
        if result == true
            count +=1
        elsif result == IDCANCEL
            return
        end

        directory = directory.gsub("\\", "/")
        first_file_name = first_file_name.gsub("\\", "/")
        filenames = Dir.glob("#{directory}/*.skp")
        filenames.each do |filename|
            puts "filename: #{filename}"
            next if filename == first_file_name
            status = Sketchup.open_file(filename, with_status: true)
            unless (status == Sketchup::Model::LOAD_STATUS_SUCCESS || status ==  Sketchup::Model::LOAD_STATUS_SUCCESS_MORE_RECENT)
                UI.messagebox("Error load SU file #{filename}.  Aborting batch shops to layout.")
                return
            end
            model = Sketchup.active_model
            result = append_page_to_layout(model, doc, true)
            if result == true
                count +=1
            elsif result == IDCANCEL
                break
            end
        end
        puts "#{count} pages added to #{project_name}"
        UI.messagebox "#{count} pages added to Layout Doc #{project_name}"
    end

    def CB_TF.send_shops_to_layout
        model = Sketchup.active_model
        unless shop_drawing_model?(model)
            UI.messagebox("This does not look like a shop drawing model (missing special scenes)")
            return
        end
        project_name = get_project_name(model)

        doc = open_or_create_layout_doc(project_name, File.dirname(model.path))

        append_page_to_layout(model, doc)
        
        puts "#{model.title} added to #{project_name}"
        Sketchup.status_text = ""
        UI.messagebox("Page #{model.title} added to \"#{project_name}.layout\"")
    end

    def CB_TF.get_project_name(model)
        # find the shop_3d_timber, which is where we stashed the project name
        project_name = nil
        model.entities.grep(Sketchup::ComponentInstance) do |ci|
            if ci.name == "shop_3d_timber"
                project_name = ci.get_attribute(JAD, "project_name")
                break
            end
        end
        puts "project_name: #{project_name}"
        unless project_name
            UI.messagebox("This does not look like a shop drawing model (missing 3D Timber)")
            return
        end        
        return project_name
    end

    def CB_TF.shop_drawing_model?(model)
        scenes = model.pages
        tf_3d_shops_scene = nil
        tf_shops_scene = nil
        scenes.each_with_index do |scene, i|
            if scene.name == "2D Shops"
                tf_shops_scene = i
            end
            if scene.name == "3D Shops"
                tf_3d_shops_scene = i
            end
        end        
        return tf_3d_shops_scene != nil && tf_shops_scene != nil
    end

    def CB_TF.open_or_create_layout_doc(project_name, path)
        layout_file_name = File.join(path, "#{project_name}.layout")
        puts "layout_file_name: #{layout_file_name}"
        if layout_file_name && File.exist?(layout_file_name)
            Sketchup.status_text = "Opening the Layout Doc (this can take a while)..."
            puts "#{DateTime.now.strftime("%H:%M:%S:%L")} - Before  Layout::Document.open()"
            doc =  Layout::Document.open(layout_file_name)
            puts "#{DateTime.now.strftime("%H:%M:%S:%L")} - After  Layout::Document.open()"
            begin
                doc.save
            rescue ArgumentError  => err
                UI.messagebox("Error saving layout file (#{err}).  Is it open in Layout?")
                return nil
            end
        else
            Sketchup.status_text = "Creating a new Layout Doc"
            puts "doc not found, creating new"
            layout_template_path =  Sketchup.read_default("TF", "layout_template_path", "")
            template_file_name = UI.openpanel("Choose a Layout Template", layout_template_path, "Layout|*.layout||")
            puts "template_file_name: #{template_file_name}"
            return unless template_file_name
            doc = Layout::Document.new(template_file_name)
            page = doc.pages.first
            page.name = "Cover Page"
            pi = doc.page_info
            # layer = doc.layers.add(model.title)
            # layer.set_nonshared(page, Layout::Layer::UNSHARELAYERACTION_CLEAR)
            default_layer = nil
            layers = doc.layers
            layers.each { |layer| default_layer = layer if layer.name == "Default" }
    
            anchor = Geom::Point2d.new(pi.width / 2, pi.height / 2)
            text = Layout::FormattedText.new("#{project_name} Shop Drawings", anchor, Layout::FormattedText::ANCHOR_TYPE_CENTER_CENTER)
            style = text.style
            style.font_size = 36.0
            text.style = style
            doc.add_entity(text, default_layer, page)
            doc.save(layout_file_name)
            layout_template_path = File.dirname(template_file_name)
            while layout_template_path.index("\\")
                layout_template_path["\\"]="/"
            end
            puts "saving layout_template_path: #{layout_template_path}"
            Sketchup.write_default("TF", "layout_template_path", layout_template_path)
        end
       
        return doc        
    end
    
    def CB_TF.append_page_to_layout(model, doc, batch = false)
        Sketchup.status_text = "Adding page #{model.title} to Layout Doc"
        scenes = model.pages
        tf_3d_shops_scene = nil
        tf_shops_scene = nil
        qty = ""
        tsize = ""
        scenes.each_with_index do |scene, i|
            if scene.name == "2D Shops"
                tf_shops_scene = i
            end
            if scene.name == "3D Shops"
                tf_3d_shops_scene = i
            end
        end

        if tf_3d_shops_scene == nil || tf_shops_scene == nil
            if batch
                puts "Skipping file #{model.title}.  It does not appear to be a shop drawing (special scenes not found):"
                puts "\ttf_3d_shops_scene: #{tf_3d_shops_scene}, tf_shops_scene: #{tf_shops_scene}"
            else
                UI.messagebox("This does not look like a shop drawing model (missing special scenes)")
            end
            return
        end

        # find the shop_3d_timber, which is where we stashed the qty and size
        model.entities.grep(Sketchup::ComponentInstance) do |ci|
            if ci.name == "shop_3d_timber"
                qty = ci.get_attribute(JAD, "qty")
                tsize = ci.get_attribute(JAD, "tsize")
                puts ("send_shops_to_layout qty= #{qty}, size= #{tsize}")
                break
            end
        end

        unless model.modified?
            save_status = model.save()
            unless save_status
                UI.messagebox("Shop drawing model must be saved before sending to layout")
                return
            end
        end

        default_layer = nil
        layers = doc.layers
        layers.each { |layer| default_layer = layer if layer.name == "Default" }

        pages = doc.pages
        existing_page = nil
        pages.each { |page| existing_page = page if page.name == model.title }
        if existing_page
            result = UI.messagebox("Page '#{model.title}' already exists.  Overwrite?", MB_YESNOCANCEL )
            if result == IDYES
                pages.remove(existing_page)
            else
                if batch
                    if result == IDCANCEL
                        return IDCANCEL
                    end
                else
                    UI.messagebox("Page not saved to layout")
                end
                return false
            end
        end

        puts "#{DateTime.now.strftime("%H:%M:%S:%L")} - Before  adding views"
        page = pages.add(model.title)
        # layer = doc.layers.add(model.title)
        # layer.set_nonshared(page, Layout::Layer::UNSHARELAYERACTION_CLEAR)
        # page.set_layer_visibility(layer, true)
        pi = doc.page_info

        # add 3D viewport
        vp3dx = Sketchup.read_default("TF", "vp3dx", 14.125).to_f
        vp3dy = Sketchup.read_default("TF", "vp3dy", 0.375).to_f
        vp3dw = Sketchup.read_default("TF", "vp3dw", 2.0).to_f
        vp3dh = Sketchup.read_default("TF", "vp3dh", 10.0).to_f
        view_bounds = Geom::Bounds2d.new(vp3dx, vp3dy, vp3dw, vp3dh)
        viewport = Layout::SketchUpModel.new(model.path, view_bounds)
        viewport.current_scene = tf_3d_shops_scene + 1
        doc.add_entity( viewport, default_layer, page )
        viewport.render_mode= Layout::SketchUpModel::HYBRID_RENDER
        viewport.render if viewport.render_needed?

        # add 2D viewport
        vp2dx = Sketchup.read_default("TF", "vp2dx", 1.125).to_f
        vp2dy = Sketchup.read_default("TF", "vp2dy", 0.375).to_f
        vp2dw = Sketchup.read_default("TF", "vp2dw", 13.0).to_f
        vp2dh = Sketchup.read_default("TF", "vp2dh", 8.0).to_f
        view_bounds = Geom::Bounds2d.new(vp2dx, vp2dy, vp2dw, vp2dh)
        viewport = Layout::SketchUpModel.new(model.path, view_bounds)
        viewport.current_scene = tf_shops_scene + 1
        doc.add_entity( viewport, default_layer, page )
        viewport.render_mode= Layout::SketchUpModel::RASTER_RENDER
        viewport.render if viewport.render_needed?
        puts "#{DateTime.now.strftime("%H:%M:%S:%L")} - After  adding views"

        # set qty if present and so configured
        show_qty_and_size = Sketchup.read_default("TF", "qty", 1).to_i
        if show_qty_and_size==1 then
            unless tsize == ""
                sq_x_pos = Sketchup.read_default("TF", "sq_x_pos", 1).to_f
                sq_y_pos = Sketchup.read_default("TF", "sq_y_pos", 1).to_f
                sq_font_size = Sketchup.read_default("TF", "sq_font_size", 1).to_i
                sq_rotate = Sketchup.read_default("TF", "sq_rotate", 0).to_i
                sq_bold = Sketchup.read_default("TF", "sq_bold", true)

                anchor = Geom::Point2d.new(sq_x_pos, sq_y_pos)
                if qty == "" || qty == "1"
                    text = Layout::FormattedText.new("#{tsize}", anchor, Layout::FormattedText::ANCHOR_TYPE_CENTER_CENTER)
                else
                    text = Layout::FormattedText.new("#{tsize} (#{qty})", anchor, Layout::FormattedText::ANCHOR_TYPE_CENTER_CENTER)
                end
                style = text.style
                style.font_size = sq_font_size
                style.text_bold = sq_bold
                text.style = style
                doc.add_entity( text, default_layer, page )
                transformation = Geom::Transformation2d.rotation(anchor, sq_rotate.degrees)
                text.transform! transformation
            end
        end

        # add_auto_dimensions(viewport)

        begin
            doc.save
        rescue ArgumentError  => err
            UI.messagebox("Error saving layout file (#{err}).  Is it open in Layout?")
            return
        end
        return true
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