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
        page.name = "Title Page"
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
    viewport.render_mode= Layout::SketchUpModel::RASTER_RENDER
    viewport.render if viewport.render_needed?

    begin
        doc.save
    rescue ArgumentError  => err
        UI.messagebox("Error saving layout file (#{err}).  Is it open in Layout?")
        return
    end
    UI.messagebox("Page #{model.title} added to #{project_name}")
end
end #module