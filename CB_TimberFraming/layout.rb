def send_shops_to_layout
    project_name = "The Hub"

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
        UI.messagebox("This does not look like a shop drawing model")
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
    template_file_name = "#{Sketchup.find_support_file("../LayOut/templates/Paper")}\\Plain Paper\\Tabloid Landscape.layout"
    puts "template_file_name: #{template_file_name}"
    if File.exists?(layout_file_name)
        doc =  Layout::Document.open(layout_file_name)
    else
        puts "doc not found, creating new"
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
        result = UI.messagebox('Page already exists.  Overwrite?', MB_YESNO)
        if result == IDYES
            result = pages.remove(existing_page)
        else
            return
        end
    end

    page = pages.add(model.title)
    layer = doc.layers.add(model.title)
    layer.set_nonshared(page, Layout::Layer::UNSHARELAYERACTION_CLEAR)
    page.set_layer_visibility(layer, true)
    pi = doc.page_info

    # Add items in draw order (back to front)

    # add large rectangle
    bounds =  Geom::Bounds2d.new(
        pi.left_margin, 
        pi.top_margin, 
        pi.width - pi.left_margin - pi.right_margin, 
        pi.height - pi.top_margin - pi.bottom_margin
    )
    rect = Layout::Rectangle.new(bounds)
    doc.add_entity(rect, layer, page)

    # add iso viewport
    view_bounds = Geom::Bounds2d.new(
      pi.left_margin + (pi.width * 3 / 4),  
      pi.top_margin + 0.1,
      (pi.width / 4) - (pi.left_margin + pi.right_margin),
      pi.height - (pi.top_margin + pi.bottom_margin) - 0.2
    )
    viewport = Layout::SketchUpModel.new(model.path, view_bounds)
    viewport.current_scene = tf_iso_scene + 1
    doc.add_entity( viewport, layer, page )
    viewport.render_mode= Layout::SketchUpModel::RASTER_RENDER
    viewport.render if viewport.render_needed?

    # add shops viewport
    view_bounds = Geom::Bounds2d.new(
      pi.left_margin + 0.1,  
      pi.top_margin + 0.1,
      (pi.width * 3 / 4) - (pi.left_margin + pi.right_margin),
      ( pi.height - (pi.top_margin + pi.bottom_margin) ) * 0.75
    )
    viewport = Layout::SketchUpModel.new(model.path, view_bounds)
    viewport.current_scene = tf_shops_scene + 1
    doc.add_entity( viewport, layer, page )
    viewport.render_mode= Layout::SketchUpModel::RASTER_RENDER
    viewport.render if viewport.render_needed?

    # add project name rectangle
    bounds =  Geom::Bounds2d.new(
        pi.width - pi.right_margin - 0.5, 
        pi.top_margin, 
        0.5, 
        (pi.height - pi.top_margin - pi.left_margin)/2
    )
    puts ("rect bounds: #{bounds}")
    rect = Layout::Rectangle.new(bounds)
    doc.add_entity(rect, layer, page)

    # add piece name rectangle
    bounds =  Geom::Bounds2d.new(
        pi.width - pi.right_margin - 0.5, 
        pi.height / 2, 
        0.5, 
        (pi.height - pi.top_margin - pi.left_margin)/2
    )
    puts ("rect bounds: #{bounds}")
    rect = Layout::Rectangle.new(bounds)
    doc.add_entity(rect, layer, page)

    # add project name 
    cx = pi.width - pi.right_margin - 0.25
    cy =  pi.height / 4
    anchor = Geom::Point2d.new(cx, cy)
    text = Layout::FormattedText.new("#{project_name}", anchor, Layout::FormattedText::ANCHOR_TYPE_CENTER_CENTER)
    style = text.style
    style.font_size = 16.0
    text.style = style
    point = Geom::Point2d.new(cx, cy)
    angle = -90.degrees
    transformation = Geom::Transformation2d.rotation(point, angle)
    text.transform! transformation
    doc.add_entity(text, layer, page)

    # Add piece name
    cx = pi.width - pi.right_margin - 0.25
    cy =  pi.height * 3 / 4
    anchor = Geom::Point2d.new(cx, cy)
    text = Layout::FormattedText.new("#{model.title}", anchor, Layout::FormattedText::ANCHOR_TYPE_CENTER_CENTER)
    style = text.style
    style.font_size = 16.0
    text.style = style
    point = Geom::Point2d.new(cx, cy)
    angle = -90.degrees
    transformation = Geom::Transformation2d.rotation(point, angle)
    text.transform! transformation
    doc.add_entity(text, layer, page)

    begin
        doc.save
    rescue ArgumentError  => err
        UI.messagebox("Error saving layout file (#{err}).  Is it open in Layout?")
        return
    end
end