##
##  Ruby extensions to Sketchup for Timber Framers
##  Copyright (c) 2008 - 2024 Clark Bremer
##  clarkbremer@gmail.com
##
##  load "C:/Users/clark/Google Drive/TF/Sketchup/Rubies/CB_TimberFraming/CB_TimberFraming/tf.rb"
##  load "G:/My Drive/TF/Sketchup/Rubies/CB_TimberFraming/CB_TimberFraming/tf.rb"
##

require 'sketchup.rb'
require 'CB_TimberFraming/tf_peg_tool.rb'
require 'CB_TimberFraming/tf_stretch_tool.rb'
require 'CB_TimberFraming/assign_dod_tool.rb'
require "CB_TimberFraming/version.rb"
require "CB_TimberFraming/component_instance.rb"
require "CB_TimberFraming/timber_list.rb"
require "CB_TimberFraming/layout.rb"
require "CB_TimberFraming/peg_report.rb"
require "CB_TimberFraming/configure.rb"

# All our stuff goes in this module to avoid namespace collisions with other plugins
module CB_TF
  COSMETIC_PEG_LAYER_NAME = "Pegs for Presentation"
  JAD = "TF_Joinery"
  MODEL_OFFSET = 0
  TOL =  0.00001

  # helper method to make sure that one and only one component is selected
  def CB_TF.selected_component
    mm = Sketchup.active_model
    ss = mm.selection
    return nil if ss.count != 1
    cc = ss[0]
    return nil unless cc.instance_of? Sketchup::ComponentInstance
    cc
  end

  # helper method to make sure that one and only one face is selected
  def CB_TF.selected_face
    mm = Sketchup.active_model
    vv = mm.active_view
    ss = mm.selection
    return nil if ss.count != 1
    ff = ss[0]
    return nil unless ff.instance_of? Sketchup::Face
    ff
  end

  def CB_TF.has_attribute?(entity, attribute)
    entity.get_attribute(JAD, attribute, false) == true
  end

  # a couple of useful debugging tools
  def CB_TF.debug_id
    mm = Sketchup.active_model
    vv = mm.active_view
    ss = mm.selection
    print ss[0].to_s + "\n"
  end

  def CB_TF.print_bounds(c)
    print("Comp Bounds:  w:"+c.bounds.width.to_s+"\t d:"+c.bounds.depth.to_s+"\t h:"+c.bounds.height.to_s+"\n")
    for i in 0..7
      print "\t" + c.bounds.corner(i).to_s + "\n"
    end
  end

  # returns peg center projected onto timber face.  Result is a point in timber space
  def CB_TF.get_peg_center(mortise, timber, peg)
    model = Sketchup.active_model
    pc = Geom::Point3d.new(peg.bounds.center)  #peg center
    pv = Geom::Vector3d.new(peg.normal)      #peg vector
  #  print("pc1:" + pc.to_s + "\n")
  #  print("pv1:" + pv.to_s + "\n")
    pc.transform!(mortise.transformation)  #transform from joint space to timber space
    pv.transform!(mortise.transformation)
  #  print("pc2:" + pc.to_s + "\n")
  #  print("pv2:" + pv.to_s + "\n")
    pc.transform!(timber.transformation)  # now transform to global space
    pv.transform!(timber.transformation)
  #  print("pc3:" + pc.to_s + "\n")
  #  print("pv3:" + pv.to_s + "\n")
    ppoint_info = Array.new
    ppoint_info = model.raytest(pc, pv)
    if ppoint_info
      tpc = ppoint_info[0]  #peg center in timber space
      tpc.transform!(timber.transformation.inverse)  # transform from global space to timber space
      mpc = tpc.clone
      mpc.transform!(mortise.transformation.inverse) # transfrom from timber space to mortise space
    else
      printf("project_pegs: raytest failed (probably a tenon not inserted into a timber)\n")
      tpc = nil
    end

    # if the peg face was reversed, then we would project back through to the other face of the mortise,
    # rather than the outside face of the timebr.  In that case, we want to shoot in the other direction.

    # check all the faces of the mortise to see if the peg is on one of them
    on_mortise_face = false
    if tpc then  # don't bother if we hit empty space
      mortise.definition.entities.grep(Sketchup::Face) do |face|
        if face.classify_point(mpc) >= 1 and face.classify_point(mpc) <= 4 then
          on_mortise_face = true
        end
      end
    end

    # if the peg is on a mortise face, try shooting in the other direction
    if on_mortise_face then
      #print("peg on face of mortise - trying other side\n")
      pv.reverse!
      ppoint_info = model.raytest(pc, pv)
      if ppoint_info
        tpc = ppoint_info[0]  #new peg center
        tpc.transform!(timber.transformation.inverse)
        mpc = tpc.clone
        mpc.transform!(mortise.transformation.inverse) # transform from timber space to mortise space
      else
        #printf("project_pegs: raytest failed\n")
        tpc = nil
      end
    end

    return tpc
  end

  # Project a line the center of a peg on a mortise outward until it contacts
  # a face. Draw a cpoint at that point.
  def CB_TF.project_pegs(mortise, timber)
    model = Sketchup.active_model

    mortise.definition.entities.grep(Sketchup::Face) do |peg|
      next unless peg.get_attribute( JAD, "peg", false)
  #    print("found a peg: " + peg.to_s + "\n")
      cpt = get_peg_center(mortise, timber, peg)
      if cpt then
        timber.definition.entities.add_cpoint cpt
      end
    end
  end

  # Note that these are just cosmetic pegs for presentation purposes.
  # This method has nothing to do with the create_pegs or project_pegs method used in shop drawings.
  def CB_TF.show_pegs
    model = Sketchup.active_model
    model.start_operation("Add Pegs", true)
      peg_layer = Sketchup.active_model.layers.add COSMETIC_PEG_LAYER_NAME
      peg_count = 0
      o = Geom::Point3d.new(0,0,0)
      v = Geom::Vector3d.new(0,0,1)
      pd = model.definitions.add("pegette")
  #    pd.layer = peg_layer
      ents = pd.entities.add_circle(o, v, 0.5, 16)
      ents.each {|ent| ent.layer = "Layer0"}
      if f = pd.entities.add_face(ents) then
        f.layer = "Layer0"
        f.pushpull(-1)
      end
      model.active_entities.grep(Sketchup::ComponentInstance) do |timber|
        next if timber.hidden?
        next unless timber.layer.visible?
        timber.definition.entities.grep(Sketchup::ComponentInstance) do |tenon|
          if tenon.definition.get_attribute( JAD, "tenon", false) then
            tenon.definition.entities.grep(Sketchup::Face) do |peg_face|
              next unless peg_face.get_attribute( JAD, "peg", false)
              peg_ctr = get_peg_center(tenon, timber, peg_face)
              #print("Peg: " + peg_ctr.to_s + "\n")
              if peg_ctr then
                peg_count +=1
                peg_ctr.transform!(timber.transformation)  # peg is in timber coordinates.  We want global.
                pv = peg_face.normal            # peg_face is in tenon coordinates.  We want global
                pv.transform!(tenon.transformation)
                pv.transform!(timber.transformation)
                pt = Geom::Transformation.new(peg_ctr, pv)
                pi = model.active_entities.add_instance(pd, pt)

                pi.layer = peg_layer
              end
            end
          end
        end
      end
      print(peg_count.to_s + " Pegs drawn.\n")
    model.commit_operation
  end

  # Place ref face triangle marks on shop drawings
  def CB_TF.mark_reference_faces(shop_dwg, layer)
    for i in 0..3
      sd = shop_dwg[i]
      topmost = -10000
      bottommost = 10000
      frontmost = 10000
      backmost = -10000
      top = nil
      bottom = nil
      front = nil
      back = nil

      model = Sketchup.active_model
      sd.definition.entities.grep(Sketchup::Face) do |face|
        ctr = face.bounds.center
        ctr.transform!sd.transformation
        if ctr.z > topmost
          topmost = ctr.z
          top = face
        end
        if ctr.z < bottommost
          bottommost = ctr.z
          bottom = face
        end
        if ctr.y > backmost
          backmost = ctr.y
          back = face
        end
        if ctr.y < frontmost
          frontmost = ctr.y
          front = face
        end
      end #each face
      return if top == nil   ## no faces?  No marks!
      if top.material # is the top painted with something?
        # draw mark on top edge of front face
        #print("marking top edge of face: "+front.to_s+"\n")
        ctr = front.bounds.center
        ctr.transform!sd.transformation
        x = ctr.x
        y = frontmost - 0.01  # avoid z-fighting
        z = topmost
        #print("\tx="+x.to_s+" y="+y.to_s+" z="+z.to_s+"\n")
        pt1 = Geom::Point3d.new(x, y, z)
        pt2 = Geom::Point3d.new(x-2, y, z+2)
        pt3 = Geom::Point3d.new(x+2, y, z+2)
        grp = model.entities.add_group
        grp.layer = layer
        ref_mark = grp.entities.add_face(pt1, pt2, pt3)
        ref_mark.material = top.material # paint it same as refernce face
        ref_mark.back_material = top.material
        #print("ref_mark face:"+ref_mark.to_s+"\n")
      end
      if bottom.material # is the bottom painted with something?
        # draw mark on top edge of front face
        #print("marking bottom edge of face: "+front.to_s+"\n")
        ctr = front.bounds.center
        ctr.transform!sd.transformation
        x = ctr.x
        y = frontmost - 0.01  # avoid z-fighting
        z = bottommost
        #print("\tx="+x.to_s+" y="+y.to_s+" z="+z.to_s+"\n")
        pt1 = Geom::Point3d.new(x, y, z)
        pt2 = Geom::Point3d.new(x-2, y, z-2)
        pt3 = Geom::Point3d.new(x+2, y, z-2)
        grp = model.entities.add_group
        grp.layer = layer
        ref_mark = grp.entities.add_face(pt1, pt2, pt3)
        ref_mark.material = bottom.material # paint it same as reference face
        ref_mark.back_material = bottom.material
        #print("ref_mark face:"+ref_mark.to_s+"\n")
      end

    end # for each shop drawing
    #print("\n")
  end # mark_reference_faces

  class ExtremeFace
    def initialize(face, ctr)
      @face = face
      @ctr = ctr
    end
    attr_reader :face, :ctr
  end

  def CB_TF.has_leaks?(joint)
    joint.definition.entities.grep(Sketchup::Edge) do |edge|
      tv0 = edge.vertices[0].position
      tv1 = edge.vertices[1].position
      next if (tv0.z == 0) and (tv1.z == 0) # edges on the cutting face are exempt
      next if edge.curve # egdes that are part of a curve, like a peg hole, are exempt.
      if edge.faces.count <= 1
        puts "has_leaks? found bad edge: #{edge}"
        return true
      end
    end
    return false
  end

  ##########################################################
  ##  Make Shop Drawings
  ##
  ##  Copies tenon joinery from other timbers into this one as mortises.
  ##
  ##  Must have one and only one component selected.
  ##
  ##  Makes 4 copies of the selected timber, each rotated 90 deg
  ##  from each other to show all 4 faces, parralel perspective.
  ##
  ##  Makes a 3D view of the timber.
  ##
  ##  TODO:
  ##  - Have we lost the ability for user to customize shop drawing styles?

  def CB_TF.make_shop_drawings(original, batch = false)
    su_ver = Sketchup.version.split(".")[0].to_i
    puts "Sketchup Version: #{su_ver}"
    tm = Time.now
    side_spacing = Sketchup.read_default("TF", "side_spacing", "30").to_i

    if not original.instance_of? Sketchup::ComponentInstance
      UI.messagebox "Timber Framing: Must have one and only one timber selected"
      return
    end
    if not original.parent == Sketchup.active_model
      UI.messagebox "Timber Framing: Timber must not be part of a component or group"
      return
    end

    model = Sketchup.active_model
    if model.path == ''
      UI.messagebox("Current model must be saved before making shop drawings.")
      return
		end
    model.start_operation("Make shop drawings", true)

    # save this stuff so we can restore the view after
    view = model.active_view
    cam = view.camera
    save_cam = Sketchup::Camera.new(cam.eye, cam.target, cam.up, cam.perspective?, cam.fov)
    save_sky = model.rendering_options["DrawHorizon"]
    save_background = model.rendering_options["BackgroundColor"]
    save_back_edges = model.rendering_options["DrawBackEdges"]

    original_path = model.path

    sel = model.selection

    min_extra_timber_length = Sketchup.read_default("TF", "min_extra_timber_length", "24").to_i

    s = Sketchup.read_default("TF", "metric", 0).to_i
    if s == 1
      then metric = true
      else metric = false
    end
    s = Sketchup.read_default("TF", "roundup", 0).to_i
    if s == 1
      then roundup = true
      else roundup = false
    end
    s = Sketchup.read_default("TF", "roll", 0).to_i
    if s == 1
      then roll_angle = -90.degrees
      else roll_angle = 90.degrees
    end

    tdims = Array.new
    get_dimensions(original, min_extra_timber_length, metric, roundup, tdims)

    if original.name != ""
      shop_qty = 1
    else
      shop_qty = original.definition.count_instances
    end

    if original.name == ""
      timber_name = original.definition.name+"  (qty "+ original.definition.count_instances.to_s + ")"
      drawing_name = original.definition.name + ".skp"
    else
      timber_name = original.name
      drawing_name = original.name + ".skp"
    end
    project_name = model.title
   
    # make a copy of the original
    new_timber = model.entities.add_instance(original.definition, original.transformation)
    new_timber.make_unique  # don't mess up the original!

    # On any of our own tenons, do these tasks
    new_timber.definition.entities.grep(Sketchup::ComponentInstance) do |tenon|
      next unless has_attribute?(tenon.definition, "tenon")  # only tenons
      # add peg marks 
      tenon.definition.entities.grep(Sketchup::Face) do |peg|
        next unless has_attribute?(peg, "peg")
        # print("found a peg: " + peg.to_s + "\n")
        pc = Geom::Point3d.new(peg.bounds.center)  #peg center
        tenon.definition.entities.add_cpoint pc
      end

      # hide edges at the timber/joint interface
      lv0 = Geom::Point3d.new(0,0,0)  # local vertices
      lv1 = Geom::Point3d.new(0,0,0)
      tenon.definition.entities.grep(Sketchup::Edge) do |tedge|   # tenon edge
        tv0 = tedge.vertices[0].position
        v0 = tv0
        tv1 = tedge.vertices[1].position
        v1 = tv1
        if (tv0.z == 0) and (tv1.z == 0) then
          #print("found a tenon edge to hide - verts:", tv0.to_s, tv1.to_s, "\n")
          tedge.hidden = true
          tedge.set_attribute(JAD, "keep", true)
          v0.transform!tenon.transformation
          v1.transform!tenon.transformation
          #print("in local space:", v0.to_s, v1.to_s, "\n")
          # do any of our own edges match up to this one?
          new_timber.definition.entities.grep(Sketchup::Edge) do |ledge|  # local edge
            lv0 = ledge.vertices[0].position
            lv1 = ledge.vertices[1].position
            #print("testing local edge to hide - verts:", lv0.to_s, lv1.to_s, "\n")
            if ((lv0 == v0) and (lv1 == v1)) or ((lv0 == v1) and (lv1 == v0)) then
              #print("found a local edge to hide - verts:", lv0.to_s, lv1.to_s, "\n")
              ledge.hidden = true
            end
          end
        end
      end
    end

    # now collect and duplicate all the joinery from other components that protrudes into our space
    global_to = Geom::Point3d.new(0,0,0)    # global tenon origin
    local_to = Geom::Point3d.new(0,0,0)    # local tenon origin

    # every comp inst in the top level of the MODEL is a potential timber
    model.active_entities.grep(Sketchup::ComponentInstance) do |timber|
      next if timber == original  # not this
      next if timber == new_timber  # not these
      # print("Found potential timber:", timber, "\n")
      # every comp inst in the top level of the TIMBER is a potential tenon
      timber.definition.entities.grep(Sketchup::ComponentInstance) do |tenon|
        next unless  has_attribute?(tenon.definition, "tenon")  # only those marked as tenons
        # print "found a potential tenon:", tenon, "\n"
        global_to.set!(0,0,0)
        global_to.transform!tenon.transformation  # this in the position of the tenon within the context of the timber
        # print("global_to1: " +global_to.to_s + "\n")
        global_to.transform!timber.transformation  # now we've transformed it to global coordinates
        # print("global_to2: " +global_to.to_s + "\n")
        gto_transformation = Geom::Transformation.translation(global_to)
        local_to.set!(0,0,0)
        local_to.transform!(original.transformation.inverse * gto_transformation)
        # print("local_to: " +local_to.to_s + "\n")
        next unless original.bounds.contains?(global_to)  # for efficiency, narrow it down with this
        # but that can still produce false positives (e.g. rafters), so preform this face test also:
        # print("tenon within bounds:" + tenon.to_s + "\n")

        #original.definition.entities.add_cpoint(local_to) # debug

        face_test_passed = false
        original.definition.entities.grep(Sketchup::Face) do |face|
          if face.classify_point(local_to) >= 1 and face.classify_point(local_to) <= 4 then
            face_test_passed = true
            break
          end
        end

        if face_test_passed
          # found one!  Now create the mortise in the new timber
          if !batch && has_leaks?(tenon)
            UI.messagebox("Oops.  Looks like one of your joints (#{tenon.definition.name}) is not solid.  That could mess up the shop drawings.")
          end
          # start by creating a temporary copy of the mortise in the correct position, but in global space
          tmortise = model.entities.add_instance(tenon.definition, [0,0,0]) # starts at global origin
          tmortise.transform!tenon.transformation
          tmortise.transform!timber.transformation   # those two placed it where it belongs in glabal space
          # now create the actual mortise in the new timber.
          mortise = new_timber.definition.entities.add_instance(tmortise.definition,
                    new_timber.transformation.inverse * tmortise.transformation)
          # get rid of the temp
          tmortise.erase!
          if not reglue(mortise)
            print("reglue failed.\n")
          end
          project_pegs(mortise, new_timber)
        end
      end
    end
    # print ("joined.\n")

    # create styles, pages (scenes) and layers (tags) for 2d shops and 3s shops
    pages = model.pages
    tf_3d_shops_page = pages.add("3D Shops", PAGE_USE_ALL, 0)
    tf_3d_shops_page.transition_time = 0
    tf_shops_page = pages.add("2D Shops", PAGE_USE_ALL, 0)
    tf_shops_page.transition_time = 0
    
    layers = model.layers
    tf_shops_layer = layers.add "tf_shops_layer"
    tf_3d_shops_layer = layers.add "tf_3d_shops_layer"
    tf_shops_layer.visible = true
    tf_3d_shops_layer.visible = false
    
    styles = model.styles
    tf_shops_style = nil
    styles.each do |s|
      tf_shops_style = s if s.name == "tf_shops_style"
    end
    unless tf_shops_style
      puts "tf_shops_style not found.  Adding it."
      status = styles.add_style(Sketchup.find_support_file("00Default Style.style", "Styles/Default Styles"), false)
      tf_shops_style = styles["[Default Style]"]
      tf_shops_style.name = "tf_shops_style"
      tf_shops_style.description = "Auto-added by Timber Framing Extensions for Shop Drawings"
    end
    styles.selected_style = tf_shops_style

    # create the 3D view timber
    shop_3d_timber = model.entities.add_instance(new_timber.definition, new_timber.transformation)
    shop_3d_timber.make_unique
    shop_3d_timber.name = "shop_3d_timber"
    shop_3d_timber.layer = tf_3d_shops_layer
    shop_3d_timber.set_attribute(JAD, "project_name", project_name) # stash these here so we can find them in the shop drawings file
   
    shop_3d_timber.set_attribute(JAD, "qty", shop_qty.to_s)
    remove_stray_faces(shop_3d_timber)

    # add Direction labels if so configured
    s = Sketchup.read_default("TF", "dir_labels", 1).to_i
    lay_down_on_red(new_timber, s==1)
    
    # offset it away from the rest of the model, and place it on the ground plane
    bb = new_timber.bounds
    tv = Geom::Vector3d.new(0, MODEL_OFFSET, (-1)*bb.corner(0).z)
    tt = Geom::Transformation.translation(tv)
    new_timber.transform!(tt)
    new_timber.layer = tf_shops_layer

    # Now make the other sides
    rv = Geom::Vector3d.new(0,0,0)    #rotation vector
 
    # make an array of instances to hold the 4 copies of the original plus joinery
    shop_dwg = Array.new
    shop_dwg[0] = new_timber

    for i in 1..3
      ### Dupe It
      shop_dwg[i] = model.entities.add_instance(shop_dwg[i-1].definition, [0,0,0])
      shop_dwg[i].layer = tf_shops_layer

      # apply same transform to new comp.
      shop_dwg[i].transformation = shop_dwg[i-1].transformation

      ### Offset it from the previous one
      tv = Geom::Vector3d.new(0, 0, side_spacing)
      tt = Geom::Transformation.translation(tv)
      shop_dwg[i].transform!(tt)

      ### Rotate it 90 degrees around the center of the component, parallel to red
      rv.set!(1,0,0)
        ra = roll_angle
        rt = Geom::Transformation.rotation(shop_dwg[i].bounds.center, rv, ra)
        shop_dwg[i].transform!(rt)
      shop_dwg[i].make_unique
    end

    ## find and hide any joints and direction lables on the back side (facing away from the camera)
    puts("hiding backside joinery.")
    for i in 0..3
      shop_instance = shop_dwg[i]
      shop_definition = shop_instance.definition
      backmost = -10000
      frontmost = 10000
      bf = nil
      ff = nil
      shop_definition.entities.grep(Sketchup::Face) do |face|
        ctr = face.bounds.center
        ctr.transform!shop_dwg[i].transformation
        if ctr.y > backmost
          backmost = ctr.y
          bf = face
        end
        if ctr.y < frontmost
          frontmost = ctr.y
          ff = face
        end
      end
      next if bf == nil  ## No Faces?  Don't do anything!
      #print("backface: " + bf.to_s + "\n")
      #print("bf plane: " + bf.plane.to_s + "\n")
      shop_definition.entities.each do |joint|
        if joint.instance_of? Sketchup::Text
          if bf.classify_point(joint.point) >= 1 and bf.classify_point(joint.point) <= 4
            #print("found text on backside\n")
            joint.hidden = true
          end;
        end
        next unless joint.instance_of? Sketchup::ComponentInstance
        next if is_2d?(joint.definition)  # things like through tenon tips
        jnv = Geom::Vector3d.new(0,0,1)   # joint normal vector
        jo = Geom::Point3d.new(0,0,0)     # joint origin
        jnv.transform!joint.transformation
        jo.transform!joint.transformation
        if (bf.normal == jnv) or (bf.normal == jnv.reverse)
          #print("normals match\n")
          if bf.classify_point(jo) >= 1 and bf.classify_point(jo) <= 4
            #print("joint origin on face\n")
            joint.hidden = true
          end
        end
      end
      if dir_label = ff.get_attribute(JAD, "Direction")
        ctr = ff.bounds.center
        shop_definition.entities.add_text(dir_label, ctr)
      end
    end # for each shop drawing
    
    for i in 0..3
      remove_stray_faces(shop_dwg[i])  # this involves exploding components
    end

    # Undoing an explosion causes SU to crash.  See:
    # https://forums.sketchup.com/t/after-exploding-a-group-at-the-root-context-undo-causes-a-bugsplat/268302
    model.commit_operation 
    model.start_operation("Make Shop Drawings (will be undone)", true) # I only want to Undo up to this point, so I can't set the 4th argument to true

    puts("adjusting camera settings")
    camera = Sketchup::Camera.new
    camera.perspective = false
    up = camera.up
    up.set!(0, 0, 1)  # level
    target = camera.target
    target.set!(MODEL_OFFSET, 0, side_spacing * 1.5) # parallel to y axis
    eye = camera.eye
    eye.set!(MODEL_OFFSET, -1000, side_spacing * 1.5)
    camera.set(eye, target, up)
    view = model.active_view
    view.camera = camera

    model.rendering_options["DrawBackEdges"] = true
    model.rendering_options["DrawHorizon"] = false
    model.rendering_options["BackgroundColor"] = "white"

    ts = tm.strftime("Created on: %m/%d/%Y")
    company_name = Sketchup.read_default("TF", "company_name", "Company Name")
   
    tsize = tdims[0].to_s + " x " + tdims[1].to_s + " x " + tdims[3].to_s
    shop_3d_timber.set_attribute(JAD, "tsize", tsize)
    drawing_header = company_name + "  |  " + "Project: " + project_name + "  |  " + ts
    drawing_title = timber_name + "  -  " + tsize
    victims = Array.new
    model.entities.each do |e|
      next if shop_dwg.include? e 
      next if e == shop_3d_timber
      next if e.instance_of? Sketchup::SectionPlane # because undo does not fix this
      victims.push e
    end
    # I can't recall when or why I added the valid? check, 
    # but that's why I'm not using bulk delete (erase_entities)
    victims.each {|victim| victim.erase! if victim.valid?}  


    result = model.definitions.purge_unused
    if not result
      print("purge failed\n")
    end
    sel.clear
    shop_dwg.each {|dwg| sel.add(dwg)}
    view.zoom(sel)
    sel.clear
    mark_reference_faces(shop_dwg, tf_shops_layer)

    styles.update_selected_style
    tf_shops_page.use_style = tf_shops_style
    status = tf_shops_page.update
    pages.selected_page = tf_shops_page

    tf_3d_shops_style = nil
    styles.each do |s|
      tf_3d_shops_style = s if s.name == "tf_3d_shops_style"
    end
    unless tf_3d_shops_style
      puts "tf_3d_shops_style not found.  Adding it."
      status = styles.add_style(Sketchup.find_support_file("00Default Style.style", "Styles/Default Styles"), false)
      tf_3d_shops_style = styles["[Default Style]"]
      tf_3d_shops_style.name = "tf_3d_shops_style"
      tf_3d_shops_style.description = "Auto-added by Timber Framing Extensions for Shop Drawings"
    end
    styles.selected_style = tf_3d_shops_style

    tf_3d_shops_layer.visible = true
    tf_shops_layer.visible = false
    sel.clear
    sel.add shop_3d_timber
    view = model.active_view
    view.camera = save_cam
    view.zoom(sel)
    model.rendering_options["DrawHorizon"] = false
    model.rendering_options["BackgroundColor"] = "white"

    styles.update_selected_style
    tf_3d_shops_page.use_style = tf_3d_shops_style
    status = tf_3d_shops_page.update
    pages.selected_page = tf_shops_page

    puts("showing file save dialog.  Drawing name: #{drawing_name}")
    begin
      shop_drawings_path = Sketchup.read_default("TF", "shop_drawings_path", "")
      if batch
        sd_file = File.join(shop_drawings_path, drawing_name)
        puts "batch mode, sd_file: #{sd_file}"
        save_status = model.save_copy(sd_file)
        unless save_status
          UI.messagebox("Timber Framing: Error saving Shop Drawing: #{sd_file}")
        end #batch
      else
        sd_file = UI.savepanel("Save Shop Drawings", shop_drawings_path, drawing_name)  
        if sd_file
          print("File name returned from save dialog: "+ sd_file + "\n")
          while sd_file.index("\\")
            sd_file["\\"]="/"
          end
          print("saving shop drawings as:"+sd_file + "\n")
          save_status = model.save_copy(sd_file)
          unless save_status
            UI.messagebox("Timber Framing: Error saving Shop Drawings.")
          else
            Sketchup.write_default("TF", "shop_drawings_path", File.dirname(sd_file))
          end
        end
      end # not batch
    rescue
      print("Timber Framing: Error creating shop drawings: " + $!.message + "\n")
      UI.messagebox("Timber Framing: Error creating shop drawings: " + $!.message)
    ensure
      # now put everyting back the way we found it!
      puts "putting it back"
      model.commit_operation
      Sketchup.undo
      puts "undo complete"
      model.start_operation("Cleanup after Make Shop Drawings", true, false, true)
      pages.erase(tf_3d_shops_page)
      pages.erase(tf_shops_page)
      layers.remove(tf_3d_shops_layer, true)
      layers.remove(tf_shops_layer, true)
      view = model.active_view
      view.camera = save_cam
      model.rendering_options["DrawHorizon"] = save_sky
      model.rendering_options["BackgroundColor"] = save_background
      model.rendering_options["DrawBackEdges"] = save_back_edges
      model.definitions.purge_unused      
      model.commit_operation
      Sketchup.undo
      puts "view restored"
    end
  end  # make shop drawings

  def CB_TF.batch_make_shop_drawings
    shop_drawings_path = Sketchup.read_default("TF", "shop_drawings_path", "")

    message = <<~MSG
    **** CAUTION *****

    Shop drawings will be created for ALL visible components in this 
    model.  Make sure only timbers are visible.  The naming rules are 
    the same as for the the timber list:

    * Component Instances with a name are considered unique timbers.
    * Component Instances without a name are considered scantlings.
    * Scantlings will use the component defintion name.
    * Duplicate names will cause problems!
    * The order will be the same as in the timber list.

    Shop drawings will be saved to the folder you are about to select.
    * Any existing shop drawings with the same name will be overwitten!
    
    This can take a while.
   
    Proceed?
    MSG
    
    result = UI.messagebox(message, MB_YESNO)
    return unless result == IDYES

    Sketchup.status_text = "Select Shop Drawing Folder"
    shop_drawings_path = UI.select_directory(title: "Select Shop Drawing Folder", directory: shop_drawings_path)
    return unless shop_drawings_path
    Sketchup.write_default("TF", "shop_drawings_path", shop_drawings_path)

    Sketchup.status_text = "Selecting Timbers for Batch Shop Drawings"
    model = Sketchup.active_model
    min_extra_timber_length = Sketchup.read_default("TF", "min_extra_timber_length", "24").to_i
    s = Sketchup.read_default("TF", "metric", 0).to_i
    if s == 1
      then metric = true
      else metric = false
    end
    s = Sketchup.read_default("TF", "roundup", 0).to_i
    if s == 1
      then roundup = true
      else roundup = false
    end

    cl, scantlings, timbers = collect_timber_lists(min_extra_timber_length, metric, roundup)

    count = 0
    timbers.each do |timber|
      Sketchup.status_text = "Making shop drawing for #{timber.name}"
      t = model.entities.grep(Sketchup::ComponentInstance).find {|ci| ci.persistent_id == timber.id}
      make_shop_drawings(t, true)
      count += 1
    end
    scantlings.each do |timber|
      Sketchup.status_text = "Making shop drawing for #{timber.name}"
      t = model.entities.grep(Sketchup::ComponentInstance).find {|ci| ci.persistent_id == timber.id}
      make_shop_drawings(t, true)
      count += 1
    end
    UI.messagebox("#{count} shop drawings created.")
  end  # batch_make_shop_drawings 

  def CB_TF.is_2d?(dd)
    bounds = dd.bounds
    return (bounds.depth <= TOL || bounds.height <= TOL || bounds.width <= TOL)
  end

  def CB_TF.remove_stray_faces(shop_instance)
    shop_definition = shop_instance.definition

    # mark existing 1-face edges
    shop_definition.entities.grep(Sketchup::Edge) do |edge|
      if edge.faces.count <= 1
        edge.set_attribute(JAD, "keep", true)
      end
    end

    victims = []
    shop_definition.entities.grep(Sketchup::ComponentInstance) do |joint|
      if (!joint.hidden? && !is_2d?(joint.definition))
        victims << joint
      end
    end
    # puts "exploding #{victims.count} joints"
    victims.each do |joint|
      # puts "exploding joint: #{joint.definition.name}"
      joint.explode
    end  

    2.times do
      victims = []
      shop_definition.entities.grep(Sketchup::Edge) do |edge|
        if (!has_attribute?(edge, "keep") && (edge.faces.count <= 1))
          victims.push edge
        end
      end
      break if victims.empty?
      # puts "Remove stray faces erasing #{victims.count} edges"
      shop_definition.entities.erase_entities(victims)
    end
  end

  # debug method
  def CB_TF.test_bounds
    ci = selected_component
    print("Comp Bounds:  w:"+ci.bounds.width.to_s+"\t d:"+ci.bounds.depth.to_s+"\t h:"+ci.bounds.height.to_s+"\n")
    dfn = ci.definition
    dfn.entities.grep(Sketchup::Face) do |face|
      print("face: " + face.to_s+"\n")
      w = face.bounds.width
      h = face.bounds.height
      d = face.bounds.depth
      print("w:"+w.to_s + "\th:"+ h.to_s+"\td:"+d.to_s+"\n")
    end
  end

  def CB_TF.dod_report
    timber_count = 0
    no_dod_count = 0
    dod = 0
    message = ""
    no_dod_names = Array.new
    model = Sketchup.active_model
    model.active_entities.grep(Sketchup::ComponentInstance) do |timber|
      next if timber.hidden?
      next unless timber.layer.visible?
      next if timber.layer.name == COSMETIC_PEG_LAYER_NAME
      timber_count = timber_count + 1
      dod += timber.definition.get_attribute( JAD, "DoD", 0.0)
      if timber.definition.get_attribute( JAD, "DoD", 0.0) == 0.0 then
        no_dod_count += 1
        no_dod_names.push timber.definition.name
      end
    end
    dod = ((dod * 10000).round)/10000.0
    message = "Total DoD: " + dod.to_s + "\n\n"
    message += no_dod_count.to_s + "  out of " + timber_count.to_s + " total timbers have no DoD.\n"
    no_dod_count = 0
    no_dod_names.each do |name|
      no_dod_count +=1
      message += name+"\n"
      if no_dod_count > 10
        message += "..."
        break
      end
    end
    UI.messagebox(message)
  end

  # verify that the selected component is already a tenon
  def CB_TF.sel_is_tenon
    return false unless sel=selected_component
    return has_attribute?(sel.definition, "tenon")
  end

  # verify that the selected face is already a peg
  def CB_TF.sel_is_peg
    return false unless sel = selected_face
    return has_attribute?(sel, "peg")
  end

  ###################################################
  ##
  ##  create_joint
  ##
  ##  - Marks a component with an attribute dictionary entry
  ##  - Sets glue to and cutting behaviors if needed
  ##  - Deletes face on surface of mortised face if needed
  ##  - shades inside faces of joint to indicate mortise depth
  ##
  def CB_TF.create_joint
    return nil unless sel=selected_component
    if has_leaks?(sel)
      puts "create_joint aborted due to leaks"
      UI.messagebox("The component must be solid (except for the cutting face)")
      return
    end
    dfn = sel.definition
    unless dfn.behavior.is2d?
      #print ("was not set to glue - setting it now.\n")
      dfn.behavior.is2d=true
    end
    unless dfn.behavior.cuts_opening?
      #print ("was not set to cut - setting it now.\n")
      dfn.behavior.cuts_opening=true
    end
    dfn.set_attribute(JAD, "tenon", true)
    #print "tenon made:", sel, "\n"

    bfs = Array.new
    dfn.entities.grep(Sketchup::Face) do |face|
      p = face.plane
      x = p[0]
      y = p[1]
      z = p[2]
      o = p[3]
      #print ("face in tenon: " + face.to_s + "\n")
      #if o.abs < tol then print("\t0\n") else print("\t"+ o.to_s+"\n") end
      #if x.abs < tol then print("\t0\n") else print("\t"+ x.to_s+"\n") end
      #if y.abs < tol then print("\t0\n") else print("\t"+ y.to_s+"\n") end

      if z.abs < TOL
        #print("\t0\n")
      else
        # note that Z axis could be either into or out of the mortise.
        ctr = face.bounds.center
        if (z > 0 and ctr.z > 0) or (z < 0 and ctr.z <0) then
          #print("\tReversing face\n")
          face.reverse!
        end
        #print("\tz:"+ z.to_s+"\tctr.z:"+ctr.z.to_s+" (color me)")
        h = face.vertices[0].position[2].abs
        g = 160-(h*12).to_i
        if g<0 then g=0 end
        #print("\theight: " + h.to_s + "\t g: " + g.to_s + "\n")
        face.material = [g,g,g]
        face.back_material = [g,g,g]
      end

      if x.abs < TOL and y.abs < TOL and o.abs < TOL
        #print("Found and removing a base face: " + face.to_s + "\n")
        bfs.push face
      end
    end
    bfs.each {|base| base.erase! if base.valid?}
  end

  def CB_TF.unroll_joint
    return nil unless sel_is_tenon
    sel = selected_component
    dfn = sel.definition
    dfn.delete_attribute(JAD, "tenon")
    #print "tenon cleared:", sel, "\n"
  end

  ##
  ##  Marks a component with an attribute dictionary entry.
  ##  Not to be confused with #project_pegs (which places cpoint on shop drawings)
  ##  or #show_pegs, which creates cosmetic pegs.
  ##
  def CB_TF.make_peg
    return nil unless sel=selected_face
    sel.set_attribute(JAD, "peg", true)
    print "peg made:", sel, "\n"
  end

  def CB_TF.set_dod(sel)
    prompts = ["Degree of Difficulty:"]
    defaults = [sel.definition.get_attribute(JAD, "DoD", 0.0)]
    results = inputbox(prompts, defaults, "Set New DoD")
    return if !results
    dod = results[0]
    sel.definition.set_attribute(JAD, "DoD", dod)
    #print ("DoD set to "+ dod.to_s+"\n")
  end

  # Report the version
  def self.tf_version
    vv = CB_TF::CB_TimberFraming_VERSION
    dd = CB_TF::CB_TimberFraming_DATE
    UI.messagebox(%Q[
      Timber Framing Extensions Version #{vv} - #{dd}
      Copyright (c) Clark Bremer
      clark@tenon.technology
  ])
  end

  def CB_TF.tf_contribute
    UI.messagebox("To show your appreciation, and\nsupport further development of the Timber Framing Extensions,\nfeel free to leave a contribution in my\npaypal account: clarkbremer@gmail.com\n")
  end

  ##
  ##  Splice our juju into the menus
  ##

  # Menu Validation Procs: Determine if a particular menu item should be enabled or not

  def CB_TF.peg_valid_proc
    if sel_is_peg
      return MF_GRAYED
    end
    face = selected_face
    if not face
      return MF_GRAYED
    end
    return MF_ENABLED
  end

  def CB_TF.tenon_valid_proc(sel)
    if sel_is_tenon
      return MF_GRAYED
    end
    if sel.parent == Sketchup.active_model
      return MF_GRAYED
    end
    return MF_ENABLED
  end

  def CB_TF.shop_dwg_valid_proc(sel)
    if sel_is_tenon
      return MF_GRAYED
    elsif sel.parent == Sketchup.active_model
      return MF_ENABLED
    end
    return MF_GRAYED
  end

  def CB_TF.auto_dimensions_valid_proc(sel)
    if sel_is_tenon
      return MF_ENABLED
    elsif sel.parent == Sketchup.active_model
      return MF_ENABLED
    end
    return MF_GRAYED
  end

  def CB_TF.peg_tool_valid_proc
    return MF_ENABLED if sel_is_tenon
    return MF_GRAYED
  end

  def CB_TF.stretch_tool_valid_proc
    return MF_ENABLED if selected_component
    return MF_ENABLED if Sketchup.active_model.selection.empty?
    return MF_GRAYED
  end
end # module CB_TF

# main program - runs when the script gets loaded
unless file_loaded?("tf.rb")

  UI.add_context_menu_handler do |menu|
    if menu == nil
      UI.messagebox("Error settting context menu handler")
    end
    if CB_TF.sel_is_tenon
      menu.add_separator
      menu.add_item("Timber Framing ID: Joint") {UI.beep}
    elsif CB_TF.sel_is_peg
      menu.add_separator
      menu.add_item("Timber Framing ID: Peg") {UI.beep}
    end

    if (sel = CB_TF.selected_component)
      menu.add_separator
      tenon_menu_item = menu.add_item("Create Joint") {CB_TF.create_joint}
      menu.set_validation_proc(tenon_menu_item) {CB_TF.tenon_valid_proc(sel)}
      shop_dwg_menu_item = menu.add_item("Make Shop Drawings") {CB_TF.make_shop_drawings(sel)}
      menu.set_validation_proc(shop_dwg_menu_item) {CB_TF.shop_dwg_valid_proc(sel)}
      # auto_dimensions_menu_item = menu.add_item("Timber Framing Add Dimensions") {CB_TF.auto_dimensions(sel)} ## Experimental
      # menu.set_validation_proc(auto_dimensions_menu_item) {CB_TF.auto_dimensions_valid_proc(sel)}
      dod = 0.0
      if sel.parent == Sketchup.active_model
        dod = sel.definition.get_attribute(CB_TF::JAD, "DoD", 0.0)
      end
      set_dod_menu_item = menu.add_item("Set DoD (currently " + dod.to_s + ")") {CB_TF.set_dod(sel)}
      menu.set_validation_proc(set_dod_menu_item) {CB_TF.shop_dwg_valid_proc(sel)}  # same rules as shop dwg
    end

    if CB_TF.selected_face
      menu.add_separator
      peg_menu_item = menu.add_item("Create Peg") {CB_TF.make_peg}
      menu.set_validation_proc(peg_menu_item) {CB_TF.peg_valid_proc}
    end
  end # context (right click) menu

  tf_menu = UI.menu("Extensions").add_submenu("Timber Framing")
  if tf_menu == nil
    UI.messagebox("Timber Framing: Error adding plugins menu")
  end
  tf_menu.add_item("Timber List") {CB_TF.make_timber_list}
  tf_menu.add_item("Count Joints and Timbers") {CB_TF.count_joints}
  tf_menu.add_item("Show Pegs") {CB_TF.show_pegs}
  tf_menu.add_item("Peg Report") {CB_TF.peg_report}
  tf_menu.add_item("DoD Report") {CB_TF.dod_report}
  tf_menu.add_item("Send Shops to Layout") {CB_TF.send_shops_to_layout}
  tf_menu.add_item("Send Shops to Layout (Batch)") {CB_TF.batch_shops_to_layout}
  tf_menu.add_item("Make Shop Drawings (Batch)") {CB_TF.batch_make_shop_drawings}
  peg_tool_item = tf_menu.add_item("Peg Tool"){Sketchup.active_model.select_tool(CB_TF::TFPegTool.new)}
  tf_menu.set_validation_proc(peg_tool_item) {CB_TF.peg_tool_valid_proc}
  stretch_tool_item = tf_menu.add_item("Stretch Tool"){Sketchup.active_model.select_tool(CB_TF::TFStretchTool.new)}
  tf_menu.set_validation_proc(stretch_tool_item) {CB_TF.stretch_tool_valid_proc}
  tf_menu.add_item("Assign DoD Tool"){Sketchup.active_model.select_tool(CB_TF::DoDTool.new)}
  tf_menu.add_item("Configure") {CB_TF.configure}
  tf_menu.add_item("About") {CB_TF.tf_version}
  tf_menu.add_item("Contribute") {CB_TF.tf_contribute}
end

file_loaded("tf.rb")
