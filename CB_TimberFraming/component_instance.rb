# Extending SU base class.  Prepend all method names with tf_ to avoid namespace
# collisions with other plugins.  TODO:  Move to new source file.

class Sketchup::ComponentInstance 

  def tf_add_directional_lables  
    northmost = -10000
    southmost = 10000
    eastmost = -10000
    westmost = 10000
    highest = -10000
    lowest = 10000
    north = nil
    south = nil
    east = nil
    west = nil
    top = nil
    bottom = nil
    
    # find and mark the directional faces
    # break ties with face of larger area
    faces = Array.new
    self.definition.entities.each do |ent|
      if ent.instance_of? Sketchup::ComponentInstance
        ent.definition.entities.each do |subent|
          if subent.instance_of? Sketchup::Face 
            ctr = subent.bounds.center
            #print("ctr b4  xf:"+ctr.to_s + "\n")
            ctr.transform!ent.transformation
  #          ctr.transform!self.transformation
            #print("ctr aft xf:"+ctr.to_s + "\n")
            ef = CB_TF::ExtremeFace.new(subent, ctr)
            faces.push ef
          end
        end
      elsif ent.instance_of? Sketchup::Face
        ctr = ent.bounds.center
  #      ctr.transform!self.transformation
        ef = CB_TF::ExtremeFace.new(ent, ctr)
        faces.push ef
      end
    end
    faces.each do |ef|
      face = ef.face
      ctr = Geom::Point3d.new(ef.ctr)
      ctr.transform! self.transformation
      if (ctr.x-eastmost).abs < 0.0001
        if face.area > east.face.area 
          east = ef
        end
      elsif ctr.x > eastmost
        eastmost = ctr.x
        east = ef
      end
      
      if (ctr.x - westmost).abs < 0.0001
        if face.area > west.face.area
          west = ef
        end
      elsif ctr.x < westmost
        westmost = ctr.x
        west = ef
      end
      
      if (ctr.y-northmost).abs < 0.0001
        if face.area > north.face.area
          north = ef
        end  
      elsif ctr.y > northmost
        northmost = ctr.y
        north = ef
      end
      
      if (ctr.y-southmost).abs < 0.0001
        if face.area > south.face.area
          south = ef
        end  
      elsif ctr.y < southmost
        southmost = ctr.y
        south = ef
      end
      
      if (ctr.z-highest).abs < 0.0001
        if face.area > top.face.area
          top = ef
        end  
      elsif ctr.z > highest
        highest = ctr.z
        top = ef
      end
      
      if (ctr.z-lowest).abs < 0.0001
        if face.area > bottom.face.area
          bottom = ef
        end  
      elsif ctr.z < lowest
        lowest = ctr.z
        bottom = ef
      end
      
    end      
    return if north == nil  ## No Faces?  No Labels!

    dl_layer = Sketchup.active_model.layers.add "shop drawing direction lables"
    ov = Geom::Vector3d.new
    
    ov = north.ctr-south.ctr
    if ov.length != 0
      ov.length=3
      dl = self.definition.entities.add_text("N", north.ctr, ov)
      dl.layer = dl_layer
      ov.reverse!
      dl = self.definition.entities.add_text("S", south.ctr, ov)
      dl.layer = dl_layer
    end
    
    ov = east.ctr-west.ctr
    if ov.length != 0
      ov.length=3
      dl = self.definition.entities.add_text("E", east.ctr, ov)
      dl.layer = dl_layer
      ov.reverse!
      dl = self.definition.entities.add_text("W", west.ctr, ov)
      dl.layer = dl_layer
    end

    ov = top.ctr-bottom.ctr
    if ov.length != 0
      ov.length=3
      dl = self.definition.entities.add_text("T", top.ctr, ov)
      dl.layer = dl_layer
      ov.reverse!
      dl = self.definition.entities.add_text("B", bottom.ctr, ov)
      dl.layer = dl_layer
    end
  end  # add directional labels

  def tf_largest_face
    cd = definition
    largest = nil
    cd.entities.each do |e|
      next if not e.instance_of? Sketchup::Face
      if (largest == nil) or (e.area > largest.area)
        largest = e
      end
    end
    return largest
  end

  def tf_longest_edge
    cd = definition
    longest = nil
    cd.entities.each do |e|
      next if not e.instance_of? Sketchup::Edge
      if (longest == nil) or (e.length > longest.length)
        longest = e
      end
    end
    return longest
  end

  def tf_rotate_around_axis(rot_axis, target_axis)
    # rotate around rot_axis so that we lie in the plane of rot_axis and target_axis
    #print("rot_axis: "+rot_axis.to_s+"\n")
    #print("target_axis: "+target_axis.to_s+"\n")

    rp = Geom::Point3d.new(0,0,0)     #rotation point
       # translate this point to global coordinates    
    rp.transform!(self.transformation)        
    
    return nil if not (axis = self.tf_longest_edge)  #CI has no edges?
    lev = Geom::Vector3d.new(axis.line[1])  # longest edge vector
    # print("lev b4: " + lev.to_s + "\n")
    # translate this to global coordinates
    lev.transform!(self.transformation)
    #print("lev xfromed: " + lev.to_s + "\n")
    test_lev = Geom::Vector3d.new(lev)
    
    proj = Geom::Vector3d.new(0,0,0)  # projection of lev onto plane of rotation.  Used to compute the rotation angle
    
    #av.set!(lev.x, 0, lev.z)
    if rot_axis.x == 1 
      then proj.x=0 
      else proj.x=lev.x
    end  
    if rot_axis.y == 1 
      then proj.y = 0
      else proj.y = lev.y
    end
    if rot_axis.z == 1
      then proj.z = 0
      else proj.z = lev.z
    end  
    #print("proj: "+proj.to_s+"\n")
    return if proj.length.abs < 0.00001
    
    rot_ang = proj.angle_between(target_axis)
    #print("prelim rotation: " + rot_ang.radians.to_s + "\n")
    return if rot_ang.abs < 0.00001

    rt = Geom::Transformation.rotation(rp, rot_axis, rot_ang) # rotation transform
    proj.transform!(rt)   
    # proj should now be on top of the desination vector
    # if not, its becaue of a sketchup peculiarity with the angle_between function, which will not
    # return a negative value.  If not, reverse the angle
    #print("proj (after test rotate): "+proj.to_s+"\n")
    unless proj.angle_between(target_axis).abs < 0.00001
      rot_ang = -rot_ang
      #print("reversing rotation\n")
    end      

    # take the shortest rotation path to the target, so the top of a rafter stays on top
    if rot_ang.abs > 90.degrees then
      rot_ang -= 180.degrees
      if rot_ang < 180.degrees 
        rot_ang += 360.degrees
      end  
    end
    
    rt = Geom::Transformation.rotation(rp, rot_axis, rot_ang) 
    #print("rotation: " + rot_ang.radians.to_s + "\n")
    self.transform!(rt)
  end

  def tf_roll_plumb
    
    blue = Geom::Vector3d.new(0,0,1) 

    # is the largest face neither plumb nor level?
    return nil if not (lf = self.tf_largest_face) #CI has no faces?
    lfv = lf.normal
    lfv.transform!(self.transformation)
    ra = lfv.angle_between(blue)   #rotation angle
    #print("rotation angle: " + ra.radians.to_s + "\n")

    # if we're already plumb or level, then bail out
    return if (ra.abs <= 0.0001)
    return if (ra.abs - 180.degrees).abs <= 0.0001 
    return if (ra.abs - 90.degrees).abs <= 0.0001 
    
    #print("Cockeyed\n") 
    # roll to the nearest plumb or level plane
    if ra > 45.degrees and ra < 135.degrees
      ra-=90.degrees
    elsif ra > 135.degrees and ra < 225.degrees
      ra -= 180.degrees
    elsif ra > 225.degrees and ra < 315.degrees
      ra -= 270.degrees
    elsif ra > 315.degrees and ra < 360.degrees
      ra -= 360.degrees
    end
    
    return nil if not (axis = self.tf_longest_edge)  #CI has no edges?
    lev = Geom::Vector3d.new(axis.line[1])  # longest edge vector  
    lev.transform!(self.transformation)
    
    rv = Geom::Vector3d.new(lev) # rotation vector (rotate around lev)
    rp = Geom::Point3d.new(0,0,0)     #rotation point
    # translate this point to global coordinates    
    rp.transform!(self.transformation)        
    rt = Geom::Transformation.rotation(rp, rv, ra) 
    lfv.transform!(rt)   
    #print("lfv1:" + lfv.to_s + "\n")
    # lfv should now be plumb or level
    # if not, its becaue of a sketchup peculiarity with the angle_between function, which will not
    # return a negative value.  So the lfv z value should be 1 or zero.  If not, reverse the angle
    unless (lfv.z.abs >= 0.9999) or (lfv.z.abs <=0.00001)
      ra = -ra
      #print("reversing plumb rotation\n")
    end        

    #print("plumb rotation: " + ra.radians.to_s + "\n")
    rt = Geom::Transformation.rotation(rp, rv, ra) 
    self.transform!(rt)
  end

  def tf_lay_down_on_red(make_dir_lables = false)
    # fix the orientation so that its horizontal parallel with red
    # do this in two steps so that timbers at an angle don't "roll"
    
    red = Geom::Vector3d.new(1,0,0) 
    green = Geom::Vector3d.new(0,1,0) 
    blue = Geom::Vector3d.new(0,0,1) 
    
    # determine  the basic orientation
    return nil if not (axis = self.tf_longest_edge)  #CI has no edges?
    lev = Geom::Vector3d.new(axis.line[1])  # longest edge vector
    lev.transform!(self.transformation)
    
    # determine it's got a 'rafter' configuration, and if so, rotate "down" forst, then apply direction labels
    # z == 0 means horizontal (girt)  z==1 means vertical (post)  Anything else is "rafter-like"
    if lev.z.abs > 0.00001 and lev.z.abs < 0.999999 then
      #print("Rafter.  lev: \t"+lev.to_s+"\n")
      if lev.x.abs < 0.00001
        # rafter in the green-blue plane  
        #print("green-blue rafter\n")
        tf_rotate_around_axis(red, green)
        #UI.messagebox("pause after red rotatation toward green")
        if make_dir_lables then
          tf_add_directional_lables
        end      
        tf_rotate_around_axis(blue, red)
        #UI.messagebox("pause after blue rotatation toward red")
        tf_roll_plumb 
      elsif lev.y.abs < 0.00001 
        #rafter in the red-blue plane
        #print("red-blue rafter\n")
        tf_rotate_around_axis(green, red)
        if make_dir_lables then
          tf_add_directional_lables
        end      
        tf_rotate_around_axis(blue, red)  # redundnat?
        tf_roll_plumb 
      else
        # valley rafter? don't bother with direction labels.
        #print("valley rafter\n")
        tf_rotate_around_axis(green, red)
        tf_rotate_around_axis(blue, red)  
        tf_roll_plumb 
      end
    else # not a rafter
      #print("not a rafter\n")
      tf_roll_plumb 
      if make_dir_lables then
        tf_add_directional_lables
      end      
      tf_rotate_around_axis(green, red)
      tf_rotate_around_axis(blue, red)
      #UI.messagebox("pause3")
    end
  end  # lay down on red


  def tf_get_dimensions(min_len, metric, roundup, tdims)
    model = Sketchup.active_model
    grp = model.entities.add_group
    clone = grp.entities.add_instance(self.definition, self.transformation) 
    clone.make_unique
    clone.tf_lay_down_on_red
    subcomp = Array.new
    clone.definition.entities.each do |s|
      if s.instance_of? Sketchup::ComponentInstance then 
        subcomp.push(s)
      end
    end  
    subcomp.each do |sc|
      sc.explode
    end
    clone.explode
    cps = Array.new
    grp.entities.each do |cp|
      if cp.instance_of? Sketchup::ConstructionPoint
        #print("contruction point found, pushing\n")
        cps.push cp
      end  
    end
    cps.each do |cp|
      #print("erasing cp\n")
      cp.erase!
    end
    tdims.clear
    if metric then
      tdims.push grp.bounds.width.to_f.to_mm
      tdims.push grp.bounds.depth.to_f.to_mm
      tdims.push grp.bounds.height.to_f.to_mm
    else
      tdims.push grp.bounds.width.to_f
      tdims.push grp.bounds.depth.to_f
      tdims.push grp.bounds.height.to_f
    end  
    tdims.each_index do |i|
      tdims[i]=tdims[i]*1000
      tdims[i]=tdims[i].round
      tdims[i]=tdims[i]/1000.to_f
    end
    if roundup 
      tdims.each_index do |i|
        tdims[i]= tdims[i].ceil
      end
    end
    tdims.sort!
    #UI.messagebox("pause for dims")
    grp.erase!
    if metric
      then tdims[3] =  tdims[2] #((tdims[2] + min_len + 100)/100).floor
      else tdims[3] =  2*(((tdims[2] + min_len + 24)/24).floor)
    end
  end

  def tf_reglue
    co = Geom::Point3d.new(0,0,0)  #comp origin
    cv = Geom::Vector3d.new(0,0,1) #comp vector (set to Z axis)
    co.transform!(self.transformation)  #switch to our parent's coordinates
    cv.transform!(self.transformation)
    parent.entities.each do |face|
      next if not face.instance_of? Sketchup::Face
      if face.classify_point(co) >= 1 and face.classify_point(co) <= 4 and face.normal.parallel?(cv) then
  #    if co.on_face?(face) and face.normal.parallel?(cv)
        begin
          status = self.glued_to=face
        rescue
  #        UI.messagebox $!.message
        end
        if (status)
  #        UI.messagebox status
          return face
        else
  #        UI.messagebox "Failure"
          return nil
        end
      end
    end  
    return nil
  end

  def tf_vertex_at_origin
    self.definition.entities.each do |e|
      next unless e.instance_of? Sketchup::Edge
        return e.start if e.start.position == [0,0,0] 
        return e.end if e.end.position == [0,0,0] 
    end  
    puts "No vertex at origin"
    return nil
  end

end  # component_instance class extensions
