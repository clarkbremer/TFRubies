##
##  Ruby extensions to Sketchup for Timber Framers
##  Copyright (c) 2008 - 2014 Clark Bremer
##  clarkbremer@gmail.com
##  

require 'sketchup.rb'
require 'CB_TimberFraming/tf_peg_tool.rb'
require 'CB_TimberFraming/tf_stretch_tool.rb'
require 'CB_TimberFraming/assign_dod_tool.rb'
require "CB_TimberFraming/version.rb"
require "CB_TimberFraming/component_instance.rb"
require "CB_TimberFraming/timber_list.rb"

# All our stuff goes in this module to avoid namespace collisions with other plugins
module CB_TF
  COSMETIC_PEG_LAYER_NAME = "Pegs for Presentation"

  # helper method to make sure that one and only one component is selected
  def CB_TF.selected_component
      mm = Sketchup.active_model
      ss = mm.selection
      return nil if ss.count != 1 
      cc = ss[0]
      return nil if not cc.instance_of? Sketchup::ComponentInstance
      cc
  end

  # helper method to make sure that one and only one face is selected
  def CB_TF.selected_face
      mm = Sketchup.active_model
      vv = mm.active_view
      ss = mm.selection
      return nil if ss.count != 1 
      ff = ss[0]
      return nil if not ff.instance_of? Sketchup::Face
      ff
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

  # returns peg center projected onto timber face.  Result is in timber space
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
      printf("project_pegs: raytest failed\n")
      tpc = nil
    end  
    
    # if the peg face was reversed, then we would project back through to the other face of the mortise, 
    # rather than the outside face of the timebr.  In that case, we want to shoot in the other direction.
    
    # check all the faces of the mortise to see if the peg is on one of them
    on_mortise_face = false
    if tpc then  # don't bother if we hit empty space
      mortise.definition.entities.each do |face|
        next if not face.instance_of? Sketchup::Face
        
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
    
    mortise.definition.entities.each do |peg|
      next if not peg.instance_of? Sketchup::Face
      next if not peg.get_attribute( JAD, "peg", false)
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
      model.active_entities.each do |timber|
        next if not timber.instance_of? Sketchup::ComponentInstance 
        next if timber.hidden?
        next if not timber.layer.visible?
        timber.definition.entities.each do |tenon|
          next if not tenon.instance_of? Sketchup::ComponentInstance 
          if tenon.definition.get_attribute( JAD, "tenon", false) then
            tenon.definition.entities.each do |peg_face|
              next if not peg_face.instance_of? Sketchup::Face
              next if not peg_face.get_attribute( JAD, "peg", false)
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
  def CB_TF.mark_reference_faces(shop_dwg)
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
      sd.definition.entities.each do |face|
        next if not face.instance_of? Sketchup::Face
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
        pt2 = Geom::Point3d.new(x-1, y, z+2)
        pt3 = Geom::Point3d.new(x+1, y, z+2)
        grp = model.entities.add_group
        ref_mark = grp.entities.add_face(pt1, pt2, pt3)
        ref_mark.material = [0,0,0] # paint it black
        ref_mark.back_material = [0,0,0]
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
        pt2 = Geom::Point3d.new(x-1, y, z-2)
        pt3 = Geom::Point3d.new(x+1, y, z-2)
        grp = model.entities.add_group
        ref_mark = grp.entities.add_face(pt1, pt2, pt3)
        ref_mark.material = [0,0,0] # paint it black
        ref_mark.back_material = [0,0,0]
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


  ##############################################
  ##  
  ##  *** EXPERIMENTAL ***
  ##
  ##  Add auto-dimensions to shop drawings
  ##  
  def CB_TF.auto_dimensions(sel)
    puts "adding dimensions to shop drawings"
      model = Sketchup.active_model
    model.start_operation("add dimensions to shop drawings", true) 
    ci = sel
    cd = ci.definition
    z_offset = -12
    start_vertex = vertex_at_origin(ci)
    puts "start_vertex: #{start_vertex.position.inspect}"
    dim_end_points = []
    start_point = Geom::Point3d.new(0,0,0)
    start_point.transform!ci.transformation  # origin of timber is global space
    #dim_start = [start_vertex, start_point]
    dim_start = start_point
    puts "Origin of timber in global coordinates: #{dim_start.to_s}"
    cd.entities.each do |joint|
        next unless joint.instance_of? Sketchup::ComponentInstance 
      next unless joint.definition.get_attribute( JAD, "tenon", false)    
      puts "Joint found: #{joint.definition.name}"
      end_point = Geom::Point3d.new(0,0,0)
      end_point.transform!joint.transformation  # origin of joint in timber space
      puts "Origin of joint in timber coordinates: #{end_point.to_s}"
      end_point.transform!ci.transformation  # origin of joint in timber space
      puts "Origin of joint in global coordinates: #{end_point.to_s}"
      end_vertex = vertex_at_origin(joint)
      #dim_end_points << [end_vertex, end_point]
      dim_end_points << end_point
      puts "end_vertex: #{end_vertex.position.inspect}"

    end

    # sort by X distance
    dim_end_points.sort! { |a, b|  (a.x - dim_start.x).abs <=> (b.x - dim_start.x).abs }

    dim_end_points.each do |dim_end|
        dim = model.entities.add_dimension_linear(dim_start, dim_end, [0,0,z_offset])
        z_offset -= 2
      end  

    model.commit_operation
    puts "done adding dimensions to shop drawings"
  end


  ##########################################################
  ##  Make Shop Drawings
  ##
  ##  Copies tenon joinery from other timbers into this one as mortises.
  ##
  ##  Make 4 copies of the selected timber, each rotated 90 deg 
  ##  from each other to show all 4 faces, in xray mode, parralel perspective.  
  ##  Must have one and only one component selected.
  ##
  ##  load "C:/Users/Clark/Documents/TimberFraming/Sketchup/Rubies/CB_TimberFraming/CB_TimberFraming/tf.rb"
  ##
  def CB_TF.make_shop_drawings(original)
    su_ver = Sketchup.version.split(".")[0].to_i
    # puts "Sketchup Version: #{su_ver}"
    tm = Time.now  
    if not original.instance_of? Sketchup::ComponentInstance
      UI.messagebox "TF Rubies: Must have one and only one timber selected"
      return
    end
    if not original.parent == Sketchup.active_model
      UI.messagebox "TF Rubies: Timber must not be part of a component or group"
      return
    end

    model = Sketchup.active_model
    if su_ver >= 14
  		if model.path == ''
  		  UI.messagebox("Current model must be saved before making shop drawings.")
  		  return
  		end
  	end
    model.start_operation("make shop drawings", true) 
    view = model.active_view

    # so we can put it all back the way we found it.
    cam = view.camera
    save_cam_eye = cam.eye
    save_cam_target = cam.target
    save_cam_up = cam.up
    save_cam_persp = cam.perspective?
    save_cam_fov = cam.fov
    save_xray = model.rendering_options["ModelTransparency"]
    save_sky = model.rendering_options["DrawHorizon"]

    sel = model.selection

  	# crashes second time through      
    #   pgs = Array.new
    #   model.pages.each {|pg| pgs.push pg}
    #   pgs.each {|pg| model.pages.erase pg}
      
    tdims = Array.new
    min_extra_timber_length = Sketchup.read_default("TF", "min_extra_timber_length", "24").to_i
    s = Sketchup.read_default("TF", "xray", 1).to_i
    if s==1 then
      xray_mode=true 
    else 
      xray_mode=false
    end  

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

    get_dimensions(original, min_extra_timber_length, metric, roundup, tdims)
    begin
      $SmustardSelectionMemory ? $SmustardSelectionMemory.inactive=true : nil
      # make an array of instances to hold the 4 copies of the original plus joinery
      shop_dwg = Array.new
      # make a copy of the original
        shop_dwg[0] = model.entities.add_instance(original.definition, original.transformation)   
      shop_dwg[0].make_unique  # don't mess up the original!
      
      
      # On any of our own tenons. do these tasks
      shop_dwg[0].definition.entities.each do |tenon|
        # find the tenons
        next if not tenon.instance_of? Sketchup::ComponentInstance 
        
        # put peg marks on our own tenons
        next if not tenon.definition.get_attribute( JAD, "tenon", false)
        tenon.definition.entities.each do |peg|
          next if not peg.instance_of? Sketchup::Face
          next if not peg.get_attribute( JAD, "peg", false)
          # print("found a peg: " + peg.to_s + "\n")
          pc = Geom::Point3d.new(peg.bounds.center)  #peg center
          tenon.definition.entities.add_cpoint pc
        end
        
        # hide edges at the timber/joint interface
        lv0 = Geom::Point3d.new(0,0,0)  # local vertices
        lv1 = Geom::Point3d.new(0,0,0)
        tenon.definition.entities.each do |tedge|   # tenon edge
          next if not tedge.instance_of? Sketchup::Edge
          tv0 = tedge.vertices[0].position
          v0 = tv0
          tv1 = tedge.vertices[1].position
          v1 = tv1
          if (tv0.z == 0) and (tv1.z == 0) then
            #print("found a tenon edge to hide - verts:", tv0.to_s, tv1.to_s, "\n")
            tedge.hidden = true
            v0.transform!tenon.transformation 
            v1.transform!tenon.transformation 
            #print("in local space:", v0.to_s, v1.to_s, "\n")
            # do any of our own edges match up to this one?
            shop_dwg[0].definition.entities.each do |ledge|  # local edge
              next if not ledge.instance_of? Sketchup::Edge
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
      

      # every comp inst in the top level of the model is a potential timber
      model.active_entities.each do |timber|
        next unless timber.instance_of? Sketchup::ComponentInstance
        next if timber == original
        next if timber == shop_dwg[0]
        # print("Found potential timber:", timber, "\n")
        # every comp inst in the top level of the timber is a potential tenon
        timber.definition.entities.each do |tenon|
          next if not tenon.instance_of? Sketchup::ComponentInstance 
          next if not tenon.definition.get_attribute( JAD, "tenon", false)
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
          next if not original.bounds.contains?(global_to)  # for efficiency, narrow it down with this
          # but that can still produce false positives (e.g. rafters), so preform this face test also:
          # print("tenon within bounds:" + tenon.to_s + "\n")
           
          #original.definition.entities.add_cpoint(local_to)
          # UI.messagebox("pause1")

          face_test = false
          original.definition.entities.each do |face|
            next if not face.instance_of? Sketchup::Face
            if face.classify_point(local_to) >= 1 and face.classify_point(local_to) <= 4 then
              face_test = true
              break
            end          
          end  
          
          if face_test
            # found one!  Now create the mortise in the new timber
            # start by creating a temporary copy of the mortise in the correct position, but in global space
            tmortise = model.entities.add_instance(tenon.definition, [0,0,0]) # starts at global origin
            tmortise.transform!tenon.transformation 
            tmortise.transform!timber.transformation   # those two placed it where it belongs in glabal space
            # now create the actual mortise in the new timber.
            mortise = shop_dwg[0].definition.entities.add_instance(tmortise.definition, 
                      shop_dwg[0].transformation.inverse * tmortise.transformation) 
            # get rid of the temp
            tmortise.erase!
            if not reglue(mortise)
              print("reglue failed.\n")
            end
            project_pegs(mortise, shop_dwg[0])
          end
        end
      end
      # print ("joined.\n")
      
      # add Direction labels if so configured
      s = Sketchup.read_default("TF", "dir_labels", 1).to_i
      lay_down_on_red(shop_dwg[0], s==1)
        # offset it away from the rest of the model, and place it on the ground plane
      bb = shop_dwg[0].bounds
      tv = Geom::Vector3d.new(0, MODEL_OFFSET, (-1)*bb.corner(0).z)
      tt = Geom::Transformation.translation(tv)
      shop_dwg[0].transform!(tt)

      # Now make the other sides
      rv = Geom::Vector3d.new(0,0,0)    #rotation vector
      
      for i in 1..3 
        ### Dupe It
        shop_dwg[i] = model.entities.add_instance(shop_dwg[i-1].definition, [0,0,0])    
        # apply same transform to new comp.
        shop_dwg[i].transformation = shop_dwg[i-1].transformation;                 
          
        ### Offset it from the previous one  
        tv = Geom::Vector3d.new(0, 0, SIDE_SPACING)
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
      if xray_mode
        for i in 0..3 
          backmost = -10000
          bf = nil
          shop_dwg[i].definition.entities.each do |face|
            next if not face.instance_of? Sketchup::Face
            ctr = face.bounds.center
            ctr.transform!shop_dwg[i].transformation
            if ctr.y > backmost
              backmost = ctr.y
              bf = face
            end
          end
          next if bf == nil  ## No Faces?  Don't do anything!
          #print("backface: " + bf.to_s + "\n")
          #print("bf plane: " + bf.plane.to_s + "\n")
          shop_dwg[i].definition.entities.each do |joint|
            if joint.instance_of? Sketchup::Text
              if bf.classify_point(joint.point) >= 1 and bf.classify_point(joint.point) <= 4
                #print("found text on backside\n")
                joint.hidden = true
              end;
            end
            next if not joint.instance_of? Sketchup::ComponentInstance
            jnv = Geom::Vector3d.new(0,0,1)   # joint normal vector
            jo = Geom::Point3d.new(0,0,0)
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
        end # for each shop drawing
      end  # if xray mode
    
      camera = Sketchup::Camera.new
      camera.perspective = false
      up = camera.up
      up.set!(0, 0, 1)  # level
      target = camera.target
      target.set!(MODEL_OFFSET, 0, SIDE_SPACING * 1.5) # parallel to y axis
      eye = camera.eye
      eye.set!(MODEL_OFFSET, -1000, SIDE_SPACING * 1.5)
      camera.set(eye, target, up)
      view.camera = camera

      if xray_mode then
        model.rendering_options["ModelTransparency"]=true 
      end  
      model.rendering_options["DrawHorizon"]= false

      ts = tm.strftime("Created on: %m/%d/%Y")  
      company_name = Sketchup.read_default("TF", "company_name", "Company Name")
      if original.name == ""
        timber_name = original.definition.name+"  (qty "+ original.definition.count_instances.to_s + ")"
        drawing_name = original.definition.name + ".skp"
      else
        timber_name = original.name
        drawing_name = original.name + ".skp"
      end
      tsize = tdims[0].to_s + " x " + tdims[1].to_s + " x " + tdims[3].to_s 
      drawing_title = company_name + "\nProject: " + model.title + "\nTimber: " + timber_name + " - " + tsize + "\n" + ts + "\n"

      victims = Array.new
      model.entities.each do |e|
        next if shop_dwg.include? e
        victims.push e
      end
      victims.each {|victim| victim.erase! if victim.valid?}
      
      result = model.definitions.purge_unused
      if not result
        print("purge failed\n")
      end
      sel.clear
      shop_dwg.each {|dwg| sel.add(dwg)}
      view.zoom sel 
      sel.clear    
      mark_reference_faces(shop_dwg)
      model.add_note(drawing_title, 0.01, 0.02)
      begin    
        sd_file = UI.savepanel("Save Shop Drawings", "",drawing_name)
        if sd_file 
          while sd_file.index("\\")
            sd_file["\\"]="/"
          end
          print("saving shop drawings as:"+sd_file + "\n")
          if su_ver >= 14
            save_status = model.save_copy(sd_file)
          else
            save_status = model.save(sd_file)
          end
          if not save_status
            UI.messagebox("TF Rubies: Error saving Shop Drawings!")
          end
        else      
          UI.messagebox("Shop Drawings NOT saved!")
        end
      rescue
        print("TF Rubies: Error creating shop drawings: " + $!.message + "\n")
        UI.messagebox("TF Rubies: Error creating shop drawings: " + $!.message)
      ensure
        # now put everyting back the way we found it!
        # puts "putting it back"
        model.commit_operation
        Sketchup.undo      
        model = Sketchup.active_model
        view = model.active_view
        cam = view.camera
        cam.set(save_cam_eye, save_cam_target, save_cam_up)
        cam.perspective = save_cam_persp
        cam.fov = save_cam_fov
        model.rendering_options["ModelTransparency"]= save_xray
        model.rendering_options["DrawHorizon"]= save_sky
        model.definitions.purge_unused
      	$SmustardSelectionMemory ? $SmustardSelectionMemory.inactive=false : nil
      end  
    
    end  
  end  # make shop drawings

  # debug method
  def test_bounds
    ci = selected_component
    print("Comp Bounds:  w:"+ci.bounds.width.to_s+"\t d:"+ci.bounds.depth.to_s+"\t h:"+ci.bounds.height.to_s+"\n")
    dfn = ci.definition
    dfn.entities.each do |face|
      next if not face.instance_of? Sketchup::Face
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
    model.active_entities.each do |timber|
      next if not timber.instance_of? Sketchup::ComponentInstance 
      next if timber.hidden?
      next if not timber.layer.visible?
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
    return false if not sel=selected_component
    return sel.definition.get_attribute( JAD, "tenon", false)
  end

  # verify that the selected face is already a peg
  def CB_TF.sel_is_peg
    return false if not sel = selected_face
    return sel.get_attribute( JAD, "peg", false)
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
    return nil if not sel=selected_component
    dfn = sel.definition
    if not dfn.behavior.is2d?
      #print ("was not set to glue - setting it now.\n") 
      dfn.behavior.is2d=true
    end
    if not dfn.behavior.cuts_opening?  
      #print ("was not set to cut - setting it now.\n") 
      dfn.behavior.cuts_opening=true
    end  
    dfn.set_attribute(JAD, "tenon", true)
    #print "tenon made:", sel, "\n"
    
    tol = 0.00001
    bfs = Array.new
    dfn.entities.each do |face|
      next if not face.instance_of? Sketchup::Face 
      p = face.plane
      x = p[0]
      y = p[1]
      z = p[2]
      o = p[3]
      #print ("face in tenon: " + face.to_s + "\n")
      #if o.abs < tol then print("\t0\n") else print("\t"+ o.to_s+"\n") end
      #if x.abs < tol then print("\t0\n") else print("\t"+ x.to_s+"\n") end
      #if y.abs < tol then print("\t0\n") else print("\t"+ y.to_s+"\n") end
    
      if z.abs < tol 
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
      end

      if x.abs < tol and y.abs < tol and o.abs < tol
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
    return nil if not sel=selected_face
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

  #
  # Display configuration dialog.  TODO:  Use webdialog
  #
  def CB_TF.tf_configure
    p0 = "Shop drawings in XRay Mode?"
    p1 = "Directional labels on shop drawings?"
    p2 = "Round up dimensions on timber list?"
    p3 = "Timber list as Text or Xcel?"
    p4 = "English or Metric?"
    p5 = "Unwrap or Roll shop drawings?"
    p6 = "Minimum extra timber length for timber list:"
    p7 = "Company Name:"
    
    ny = ["N", "Y"]
    em = ["E", "M"]
    tx = ["T", "X"]
    ru = ["U", "R"]
    dd0 = %w[Y N].join("|")
    dd1 = %w[Y N].join("|")
    dd2 = %w[Y N].join("|")
    dd3 = %w[T X].join("|")
    dd4 = %w[E M].join("|")
    dd5 = %w[U R].join("|")
    dds = [dd0, dd1, dd2, dd3, dd4, dd5]

    d0 = ny[Sketchup.read_default("TF", "xray", 1)]
    d1 = ny[Sketchup.read_default("TF", "dir_labels", 1)]
    d2 = ny[Sketchup.read_default("TF", "roundup", 1)]
    d3 = tx[Sketchup.read_default("TF", "excel", 0)]
    d4 = em[Sketchup.read_default("TF", "metric", 0)]
    d5 = ru[Sketchup.read_default("TF", "roll", 0)]
    d6 = Sketchup.read_default("TF", "min_extra_timber_length", "24")
    d7 = Sketchup.read_default("TF", "company_name", "")
    prompts = [p0, p1, p2, p3, p4, p5, p6, p7]
    defaults = [d0, d1, d2, d3, d4, d5, d6, d7]
    title = "TF Rubies Configuration"
      results = inputbox(prompts, defaults, dds, title)
    return nil if not results 
    if results[0] == "Y" then 
      Sketchup.write_default("TF", "xray", 1)
    else 
        Sketchup.write_default("TF", "xray", 0)
    end
    if results[1] == "Y" then 
      Sketchup.write_default("TF", "dir_labels", 1)
    else 
        Sketchup.write_default("TF", "dir_labels", 0)
    end
    if results[2] == "Y" then 
      Sketchup.write_default("TF", "roundup", 1)
    else 
        Sketchup.write_default("TF", "roundup", 0)
    end
    if results[3] == "X" then 
      Sketchup.write_default("TF", "excel", 1)
    else 
        Sketchup.write_default("TF", "excel", 0)
    end
    if results[4] == "M" then 
      Sketchup.write_default("TF", "metric", 1)
    else 
        Sketchup.write_default("TF", "metric", 0)
    end
    if results[5] == "R" then 
      Sketchup.write_default("TF", "roll", 1)
    else 
        Sketchup.write_default("TF", "roll", 0)
    end

    Sketchup.write_default("TF", "min_extra_timber_length", results[6].to_i )
    Sketchup.write_default("TF", "company_name", results[7])
  end
  
  # Report the version
  def self.tf_version
    vv = CbPluginInfo::CB_TimberFraming_VERSION
    dd = CbPluginInfo::CB_TimberFraming_DATE
    UI.messagebox("TF Extensions Version #{vv} - #{dd} - Copyright (c) Clark Bremer.")
  end

  def CB_TF.tf_contribute
    UI.messagebox("To show your appreciation, and\nsupport further development of the TF Extensions,\nfeel free to leave a contribution in my\npaypal account: clarkbremer@gmail.com\n")
  end

  ##
  ##  Splice our juju into the menus
  ##

  # Menu Validation Procs: Determine if a particular menu itme should be enabled or not

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
      return MF_GRAYED
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
  JAD = "TF_Joinery"
  MODEL_OFFSET = 0
  SIDE_SPACING = 30

  UI.add_context_menu_handler do |menu|
    if menu == nil 
      UI.messagebox("Error settting context menu handler")
    end
    menu.add_separator
    if CB_TF.sel_is_tenon
      menu.add_item("TF ID: Joint") {UI.beep}
    elsif CB_TF.sel_is_peg
      menu.add_item("TF ID: Peg") {UI.beep}
    end

    if (sel = CB_TF.selected_component)
      tenon_menu_item = menu.add_item("TF Create Joint") {CB_TF.create_joint}
      menu.set_validation_proc(tenon_menu_item) {CB_TF.tenon_valid_proc(sel)}
      shop_dwg_menu_item = menu.add_item("TF Make Shop Drawings") {CB_TF.make_shop_drawings(sel)}
      menu.set_validation_proc(shop_dwg_menu_item) {CB_TF.shop_dwg_valid_proc(sel)}
      # auto_dimensions_menu_item = menu.add_item("TF Add Dimensions") {CB_TF.auto_dimensions(sel)}
      # menu.set_validation_proc(auto_dimensions_menu_item) {CB_TF.auto_dimensions_valid_proc(sel)}
      dod = 0.0
      if sel.parent == Sketchup.active_model
        dod = sel.definition.get_attribute(JAD, "DoD", 0.0)
      end
      set_dod_menu_item = menu.add_item("TF Set DoD (currently " + dod.to_s + ")") {CB_TF.set_dod(sel)}
      menu.set_validation_proc(set_dod_menu_item) {CB_TF.shop_dwg_valid_proc(sel)}  # same rules as shop dwg
    end

    if CB_TF.selected_face
      peg_menu_item = menu.add_item("TF Create Peg") {CB_TF.make_peg}
      menu.set_validation_proc(peg_menu_item) {CB_TF.peg_valid_proc}
    end
  end # context (right click) menu

  tf_menu = UI.menu("Plugins").add_submenu("TF Rubies")
  if tf_menu == nil
    UI.messagebox("TF Rubies: Error adding plugins menu")
  end
  tf_menu.add_item("Timber List") {CB_TF.make_timber_list}
  tf_menu.add_item("Count Joints and Timbers") {CB_TF.count_joints}
  tf_menu.add_item("Show Pegs") {CB_TF.show_pegs}
  tf_menu.add_item("DoD Report") {CB_TF.dod_report}
  peg_tool_item = tf_menu.add_item("TF Peg Tool"){Sketchup.active_model.select_tool(CB_TF::TFPegTool.new)}
  tf_menu.set_validation_proc(peg_tool_item) {CB_TF.peg_tool_valid_proc}
  stretch_tool_item = tf_menu.add_item("TF Stretch Tool"){Sketchup.active_model.select_tool(CB_TF::TFStretchTool.new)}
  tf_menu.set_validation_proc(stretch_tool_item) {CB_TF.stretch_tool_valid_proc}
  tf_menu.add_item("Assign DoD Tool"){Sketchup.active_model.select_tool(CB_TF::DoDTool.new)}
  tf_menu.add_item("Configure") {CB_TF.tf_configure}
  tf_menu.add_item("About") {CB_TF.tf_version}
  tf_menu.add_item("Contribute") {CB_TF.tf_contribute}
  
end

file_loaded("tf.rb")
