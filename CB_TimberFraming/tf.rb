##
##  Ruby extensions to Sketchup for Timber Framers
##  Copyright (c) 2008 - 2014 Clark Bremer
##  clarkbremer@gmail.com
##
##  load "C:/Users/Clark/Documents/TimberFraming/Sketchup/Rubies/CB_TimberFraming/CB_TimberFraming/tf.rb"
##
##  To Do:
##     - Bug: if timber name has illegal characters (like forward slash), save shop drawings fails.
##     - Hide pegettes before shop drawings and timebr lists
##     - For finding extreme faces for ref faces, break ties with face size (as done with dir lables)
##     - make ALL shop drawings
##
##  Version 2.4 1/1/2014
##    - Update for SU-14
##        - no scenes in shop drawings (use new page.erase method)
##
##  Version 2.3 5/5/13
##    - Package for SU-13 Extension Warehouse
##
##  Version 2.2 11/11/11
##    - Cosmetic Pegs
##     - Stretch Tool
##    - Eliminate need for status bar plugin
##    - eliminate need for reglue file
##    - warning message for duplcated named timbers
##
##   Version 2.0
##  - Peg Tool
##  - DoD for each timber
##  - Timber Tally page in timber list
##   - Improved Repaint Face Tool (works more like select tool)
##     - Better Metric support in timber list (many thanks to Jonas Ekefjord for his contribution)
##
##  Version 1.19
##  - Use new "gofast" option for shop drawing operation (did not work for timber list)
##  - Peg Tool 
#   - Timber list in "tally" format
##
##  Version 1.18
##     - Detect duplicate named timbers during timber list
##  - Directional Labels on their own layer
##     - Driectional Labels incorrect (pos green is north)
##    - Color-coded mortise depth.
##  - Config option to "roll backwards" for shop drawings (just use -90 instead of 90)
##  - Automate ref face marks
##  - Angle between faces tool (dihedral)
##  - paint face tool new cursor
##  - direction labels on rafters (top and bottom)
##  - Directional Lables should dig into sub-comps to find extreme faces. 
##  
##  Version 1.17
##  - Add support for Native Excel Timber List
##  
## Version 1.16  
##  - Only hide backside joinery in xray mode
##  - Hide backside directional lables.  
##
## Version 1.15 5/14/2008
##  - Hide housing line on shop drawings
##  - Hide joints on back side of shop drawings
##  - Roundup Dimensions option for timber list
##  - Companion script rotate 90 around Z now works on groups and rotates around the center.
##  - Fixed bug in direction lables if there are no opposite faces.
##
## Version 1.14 2/15/2008
##   - Fix bug in rotation of timbers rotated along their long axis by other than 90 or 45 degrees.
##
## Version 1.13 12/24/2007
##  - Add cpoint at center of pegs on tenons,
##    - During "TF Create Joint":
##    - make sure that "glue to" and "cut opening" are set.
##    - Find and erase any faces in the joint that are on the red/green (cutting) plane.
##  - Project pegs in both directions for mortises
##  - Use leaders when creating directional labels, so they don't show through from the back side.
##
## Version 1.12 12/24/2007
##   - Bug Fix:  During Make Shop Drawings, and error would sometimes be gnereated about being unable to determine parent entity.
##  Problem was in the way the model was being cleared before displaying the shop drawings.  
##
## Version 1.11 10/26/2007
##  - Bug Fix:  SU would crash if you try to make shop drawings on timebr within a component.  Disallow that.
##  
## Version 1.10 10/23/2007
##  - In timber list, don't include hidden timbers, or timbers on disabled layers
##  - Add "count joints" feature to count timbers, joints and pegs.
##
## Version 1.9 10/12/2007  (Distributed at TFG 2007 Eastern Conference in Montebello)
##  - Added Board Feet to timber list
##  - Fixed bug with company name in timber list
##
## Version 1.8 10/5/2007
##   - Fixed bug in saving perspective view
##    - Removed calls to GetString (internationalization) and hard-coded in English Language
##  - Added support for metric units
##
## Version 1.7 9/14/2007
##   - Improved performance of timber list by getting dimensions on;ly once per comp instance
##  - Better implementation of poin_on_face (don't need external file any more)
##  - Fixed bug in directional labels for timbers with no faces (splines?)
##
##  Version 1.6 8/31/2007
##  - Fixed bug with dimensions of purlins and braces.  Purlins needed to be rolled plumb and level, braces needed to ignore CPs
##

require 'sketchup.rb'
require 'CB_TimberFraming/tf_peg_tool.rb'
require 'CB_TimberFraming/tf_stretch_tool.rb'
require 'CB_TimberFraming/assign_dod_tool.rb'
require "CB_TimberFraming/version.rb"

module CB_TF

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


def CB_TF.get_peg_center(mortise, timber, peg)  # returns peg center projected onto timber face.  Result is in timber space
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
    peg_layer = Sketchup.active_model.layers.add "Pegs for Presentation"
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
          ef = ExtremeFace.new(subent, ctr)
          faces.push ef
        end
      end
    elsif ent.instance_of? Sketchup::Face
      ctr = ent.bounds.center
#      ctr.transform!self.transformation
      ef = ExtremeFace.new(ent, ctr)
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
    print("reversing plumb rotation\n")
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

def tf_joint_count
  count = 0
  self.definition.entities.each do |tenon|
    next if not tenon.instance_of? Sketchup::ComponentInstance 
    if tenon.definition.get_attribute( JAD, "tenon", false) then
      count = count + 1
    end  
  end  
  return count
end #tf_joint_count

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

##############################################
##  
##  Add auto-dimensions to shop drawings
##
## load "C:/Users/Clark/Documents/TimberFraming/Sketchup/Rubies/CB_TimberFraming/CB_TimberFraming/tf.rb"
##
def CB_TF.auto_dimensions(sel)
  puts "adding dimensions to shop drawings"
    model = Sketchup.active_model
  model.start_operation("add dimensions to shop drawings", true) 
  ci = sel
  cd = ci.definition
  z_offset = -12
  start_vertex = ci.tf_vertex_at_origin
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
    end_vertex = joint.tf_vertex_at_origin
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
## Copies tenon joinery from other timbers into this one as mortises.
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

  original.tf_get_dimensions(min_extra_timber_length, metric, roundup, tdims)
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
          if not mortise.tf_reglue
              print("reglue failed.\n")
          end
          project_pegs(mortise, shop_dwg[0])
        end
      end
    end
    # print ("joined.\n")
    
    # add Direction labels if so configured
    s = Sketchup.read_default("TF", "dir_labels", 1).to_i
    shop_dwg[0].tf_lay_down_on_red(s==1)
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
##########################################################
##  Make Timber List
##
## Timber Materials List.
##
class CountedTimber
  def initialize(name, count, w, d, l, ft, dod)
    @name = name
    @count = count
    @w = w
    @d = d
    @l = l
    @ft = ft
    @dod = dod
  end
  attr_reader :name, :count, :w, :d, :l, :ft, :dod
  attr_writer :name, :count, :w, :d, :l, :ft, :dod
end  

class TimberList
  def initialize
    @list = Array.new
    @tdims = Array.new #Timber dimenions
  end
  
  def add(timber, min_extra_timber_length, metric, roundup)
    if timber.name == "" then 
      name = timber.definition.name
    else
      name = timber.name
    end
    dod = timber.definition.get_attribute(JAD, "DoD", 0.0)
    found = false
    @list.each do |ct|  
        if ct.name == name
        ct.count = ct.count + 1
        found = true
        break
      end
    end
    if not found
      timber.tf_get_dimensions(min_extra_timber_length, metric, roundup, @tdims)
        ct = CountedTimber.new(name, 1, @tdims[0], @tdims[1], @tdims[2], @tdims[3], dod)
      @list.push(ct)
    end
  end
  
  def each
    @list.each {|ct| yield ct}
  end  
  
  def sort!
    print("sorting\n");
      @list.sort! do |a,b| 
      if a.w != b.w then 
        b.w <=> a.w
      elsif a.d != b.d then 
        b.d <=> a.d
      elsif a.l != b.l then 
        b.l <=> a.l
      elsif a.name != b.name then 
        a.name <=> b.name
      else 
        a.count <=> b.count
      end
    end
  end  
  
  def condense!
    self.sort!
    victims = Array.new
    p = nil    # previous item
    @list.each do |t|
      if p
        if (t.w == p.w) and (t.d == p.d) and (t.ft == p.ft)
          p.count += t.count
          victims.push(t)
        else
          p = t
        end
      else # first time through
        p = t
      end
    end
    victims.each { |v| @list.delete(v)}
    
#    @list.each do |t|
#      print(t.count.to_s + " " +t.w.to_s + " " +t.d.to_s + " " +t.ft.to_s + "\n")
#    end
    
  end
end

class ExcelConst
end

def CB_TF.make_timber_list
  begin
      model = Sketchup.active_model
    s = Sketchup.read_default("TF", "excel", 0).to_i
    if s == 1 
      then excel_mode = true
      else excel_mode = false
    end  
    if excel_mode
      if RUBY_VERSION.to_f == 1.8
        require('CB_TimberFraming/win32ole')      
      else
        require('win32ole')      
      end
      excel = WIN32OLE::new('excel.Application')
      print( "excel version: " + excel.version.to_s + "\n")
      unless file_loaded?("excel_constants")
        WIN32OLE.const_load(excel, ExcelConst)
        file_loaded("excel_constants")
      end
      excel.visible = false
      if excel.version.to_f >= 12 
        then tl_file_name = UI.savepanel("Save Timber List", "","timber_list.xlsx")
        else tl_file_name = UI.savepanel("Save Timber List", "","timber_list.xls")
      end  
    else 
      tl_file_name = UI.savepanel("Save Timber List", "","timber_list.txt")
      if tl_file_name 
        while tl_file_name.index("\\")
          tl_file_name["\\"]="/"
        end
      end  
    end  
    if tl_file_name
      print("saving timber list as:"+tl_file_name + "\n")
      begin
        File.delete(tl_file_name)
      rescue
      end  
    else
      UI.messagebox("Timber List NOT saved!")
      if excel_mode
        excel.Quit
      end
      return
    end  
    
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

    company_name = Sketchup.read_default("TF", "company_name", "Company Name")
    project = model.title
      tm = Time.now
    ts = tm.strftime("Created on: %m/%d/%Y")    
   
    # write the title block
    if excel_mode 
      excel.visible = true
      workbook = excel.Workbooks.add
      worksheet = workbook.Worksheets(1) #get hold of the first worksheet
      worksheet.name = "Details"
      worksheet.columns("a").columnwidth = 20    # name
      worksheet.columns("b").columnwidth = 5    # qty
      worksheet.columns("c").columnwidth = 5    # W
      worksheet.columns("d").columnwidth = 5    # D
      worksheet.columns("e").columnwidth = 7    # L (in)
      if metric
        worksheet.columns("e").NumberFormat = "0"
      end      
      worksheet.columns("f").columnwidth = 7    # L (ft)
      if metric
        worksheet.columns("f").NumberFormat = "0.0"
      end
      worksheet.columns("g").columnwidth = 10    # BF
      if metric
        worksheet.columns("g").NumberFormat = "0.000"
      else
        worksheet.columns("g").NumberFormat = "0.00"
      end  
      worksheet.columns("h").columnwidth = 10    # DoD
      worksheet.columns("h").NumberFormat = "0.0"
      row=1
      worksheet.cells(row,1).value = company_name
      worksheet.cells(row,1).font.italic = true
      worksheet.cells(row,1).font.size = 14
      row+=1      
      worksheet.cells(row,1).value = "Timber Materials List"
      worksheet.cells(row,1).font.bold = true
      worksheet.cells(row,1).font.size = 14
      row+=2
      worksheet.cells(row,1).value = "Project: "
      worksheet.cells(row,2).value = project
      worksheet.cells(row,2).font.bold = true
      row+=1
      worksheet.cells(row,1).value = ts
      row+=2
    else
      tl_file = File.new(tl_file_name, "w")
      tl_file << "Timber Materials List - " + company_name + "\n"
      tl_file << "Project: " + project + "\n"
      tl_file << ts << "\n"
    end

    # Collect all the info from the model  
    cl = TimberList.new    # all timbers for condensed list
    ul = TimberList.new  # unnamed timbers
    nl = TimberList.new  # named timbers
    timber_total=0
    model.entities.each do |timber|
      next if not timber.instance_of? Sketchup::ComponentInstance 
      timber_total = timber_total+1
    end
    
    timber_count=0
    model.active_entities.each do |timber|
      next if not timber.instance_of? Sketchup::ComponentInstance 
      next if timber.hidden?
      next if not timber.layer.visible?
      if timber.name == ""
        # Unnamed Timbers 
        ul.add(timber, min_extra_timber_length, metric, roundup)
      else
        # Named timbers.  Assume they're unique
        nl.add(timber, min_extra_timber_length, metric, roundup)
      end  
      cl.add(timber, min_extra_timber_length, metric, roundup)   # all timbers
      timber_count = timber_count+1
      #print(timber_count.to_s + " timbers added\n");
      Sketchup.status_text = "Creating Timber List: " + timber_count.to_s + " / " + timber_total.to_s
    end
    
    print("sorting\n")
    nl.sort!
    ul.sort!
    print("condensing\n")
    cl.condense!
    
    print("exporting\n")
    if excel_mode
      worksheet.cells(row,1).value = "Named Timbers"
      worksheet.cells(row,1).font.bold = true
      worksheet.cells(row,1).font.italic = true
      row+=1
      worksheet.cells(row,1).value = "Name"
      worksheet.cells(row,3).value = "W"
      worksheet.cells(row,4).value = "D"
      if metric
        worksheet.cells(row,5).value = "L(mm)"
        worksheet.cells(row,6).value = "L(m)"
        worksheet.cells(row,7).value = "V(m3)"
      else 
        worksheet.cells(row,5).value = "L(ft)"
        worksheet.cells(row,6).value = "L(in)"
        worksheet.cells(row,7).value = "BF"
      end  
      worksheet.cells(row,8).value = "DoD"
    
      worksheet.rows(row).font.bold = true
      for col in 3..8
        worksheet.cells(row, col).HorizontalAlignment = ExcelConst::XlHAlignRight
      end
      row+=1 
      top=row
      nl.each do |ct|
        if (ct.count > 1) 
          print("warning: duplicate named timber:"+ct.name+"\n") 
          UI.messagebox("TF Rubies: warning: Duplicate Named Timber: " + ct.name + "\nDimensions will not be correct in list.")
        end
        ct.count.times do
          worksheet.cells(row,1).value = ct.name  #A
          worksheet.cells(row,3).value = ct.w    #C  
          worksheet.cells(row,4).value = ct.d    #D
          worksheet.cells(row,5).value = ct.ft  #E
          if metric
            worksheet.cells(row,6).value = ct.l/100  #F
          else
            worksheet.cells(row,6).value = ct.l #F
          end
          if metric
            worksheet.cells(row,7).formula = "=(C#{row} * D#{row} * E#{row})/1000000" #G
          else
            worksheet.cells(row,7).formula = "=(C#{row} * D#{row} * E#{row})/12" #G
          end
          worksheet.cells(row,8).value = ct.dod   #H
          row+=1
        end
      end  
      unless top == row
        worksheet.cells(row,1).value = "Total"
        worksheet.cells(row,2).formula = "=counta(A#{top}:A#{row-1})"
        worksheet.cells(row,7).formula = "=sum(G#{top}:G#{row-1})"
        worksheet.cells(row,8).formula = "=sum(H#{top}:H#{row-1})"
        worksheet.rows(row).font.italic = true
      end
      total_section1_row = row
      
      row+=2
      worksheet.cells(row,1).value = "Unnamed Timbers"
      worksheet.cells(row,1).font.bold = true
      worksheet.cells(row,1).font.italic = true
      row+=1
      worksheet.cells(row,1).value = "Name"
      worksheet.cells(row,2).value = "Qty"
      worksheet.cells(row,3).value = "W"
      worksheet.cells(row,4).value = "D"
      if metric
        worksheet.cells(row,5).value = "L(mm)"
        worksheet.cells(row,6).value = "L(m)"
        worksheet.cells(row,7).value = "V(m3)"
      else 
        worksheet.cells(row,5).value = "L(ft)"
        worksheet.cells(row,6).value = "L(in)"
        worksheet.cells(row,7).value = "BF"
      end  
      worksheet.cells(row,8).value = "DoD"
      worksheet.rows(row).font.bold = true
      for col in 2..8
        worksheet.cells(row, col).HorizontalAlignment = ExcelConst::XlHAlignRight
      end      
      row+=1
      top=row
      ul.each do |ct|
        worksheet.cells(row,1).value = ct.name  #A
        worksheet.cells(row,2).value = ct.count  #B  
        worksheet.cells(row,3).value = ct.w    #C  
        worksheet.cells(row,4).value = ct.d    #D
        worksheet.cells(row,5).value = ct.ft  #E
        worksheet.cells(row,6).value = ct.l    #F
        if metric
          worksheet.cells(row,6).value = ct.l/100  #F
        else
          worksheet.cells(row,6).value = ct.l
        end          
        if metric
          worksheet.cells(row,7).formula = "=(B#{row} * C#{row} * D#{row} * E#{row})/1000000" #G
        else
          worksheet.cells(row,7).formula = "=(B#{row} * C#{row} * D#{row} * E#{row})/12" #G
        end        

        worksheet.cells(row,8).value = ct.dod * ct.count  #H  
        row+=1
      end  
      unless top == row
        worksheet.cells(row,1).value = "Total"
        worksheet.cells(row,2).formula = "=sum(B#{top}:B#{row-1})"
        worksheet.cells(row,7).formula = "=sum(G#{top}:G#{row-1})"
        worksheet.cells(row,8).formula = "=sum(H#{top}:H#{row-1})"
        worksheet.rows(row).font.italic = true
      end
      total_section2_row = row
  
      row +=2
      worksheet.cells(row,1).value = "GrandTotal"
      worksheet.cells(row,2).formula = "=sum(B#{total_section1_row} + B#{total_section2_row})"
      worksheet.cells(row,7).formula = "=sum(G#{total_section1_row} + G#{total_section2_row})"
      worksheet.cells(row,8).formula = "=sum(H#{total_section1_row} + H#{total_section2_row})"
      worksheet.rows(row).font.italic = true
      
      
      #### Tally Section
      #
      #
      worksheet = workbook.Worksheets(2) #page 2
      worksheet.name = "Tally"
      worksheet.columns("a").columnwidth = 10    # blank
      worksheet.columns("b").columnwidth = 5    # W
      worksheet.columns("c").columnwidth = 5    # D
      worksheet.columns("d").columnwidth = 5    # Qty
      worksheet.columns("e").columnwidth = 7    # L (ft)
      if metric
        worksheet.columns("e").NumberFormat = "0.0"
      end
      worksheet.columns("f").columnwidth = 7    # Blank
      worksheet.columns("g").columnwidth = 10    # BF
      if metric
        worksheet.columns("g").NumberFormat = "0.000"
      else
        worksheet.columns("g").NumberFormat = "0.00"
      end

      row=1
      worksheet.cells(row,1).value = company_name
      worksheet.cells(row,1).font.italic = true
      worksheet.cells(row,1).font.size = 14
      row+=1      
      worksheet.cells(row,1).value = "Timber Tally"
      worksheet.cells(row,1).font.bold = true
      worksheet.cells(row,1).font.size = 14
      row+=2
      worksheet.cells(row,1).value = "Project: "
      worksheet.cells(row,2).value = project
      worksheet.cells(row,2).font.bold = true
      row+=1
      worksheet.cells(row,1).value = ts
      row+=1
      worksheet.cells(row,9).value = "Spares:"      
      worksheet.cells(row,10).value = "0.20"
      worksheet.cells(row,10).NumberFormat = "0%"
      sparerow = row
      row+=2
      worksheet.cells(row,2).value = "NEEDED"
      worksheet.cells(row,2).font.size = 16
      worksheet.cells(row,12).value = "ORDERED"
      worksheet.cells(row,12).font.size = 16
      row+=1
      worksheet.cells(row,2).value = "W"
      worksheet.cells(row,3).value = "D"
      worksheet.cells(row,4).value = "Qty"
      if metric
        worksheet.cells(row,5).value = "L(m)"
        worksheet.cells(row,7).value = "V(m3)"
      else 
        worksheet.cells(row,5).value = "L(ft)"
        worksheet.cells(row,7).value = "BF"
      end  
      worksheet.cells(row,9).value = "Suggested"
      worksheet.cells(row,10).value = "Actual"
      worksheet.cells(row,12).value = "W"
      worksheet.cells(row,13).value = "D"
      worksheet.cells(row,14).value = "Qty"
      worksheet.cells(row,15).value = "L(ft)"
      worksheet.cells(row,17).value = "BF"
      
      worksheet.rows(row).font.bold = true
      for col in 2..17
        worksheet.cells(row, col).HorizontalAlignment = ExcelConst::XlHAlignRight
      end            
      row+=1
      top = row
      cl.each do |ct|
        worksheet.cells(row,2).value = ct.w    #B  
        worksheet.cells(row,3).value = ct.d    #C  
        worksheet.cells(row,4).value = ct.count  #D
        if metric
          worksheet.cells(row,5).value = ct.ft/100  #E
        else
          worksheet.cells(row,5).value = ct.ft
        end

        if metric
          worksheet.cells(row,7).formula = "=(B#{row} * C#{row} * D#{row} * E#{row})/10000" #G
        else
          worksheet.cells(row,7).formula = "=(B#{row} * C#{row} * D#{row} * E#{row})/12" #G
        end  
        worksheet.cells(row,9).formula = "=ROUND(D#{row} * $J$#{sparerow},0)"  #I
        worksheet.cells(row,10).value = worksheet.cells(row,9).value  #J
        worksheet.cells(row,12).value = worksheet.cells(row,2).value  #L
        worksheet.cells(row,13).value = worksheet.cells(row,3).value  #M
        worksheet.cells(row,14).formula = "=D#{row}+J#{row}"      #N
        worksheet.cells(row,15).value = worksheet.cells(row,5).value  #O
        worksheet.cells(row,17).formula = "=(L#{row} * M#{row} * N#{row} * O#{row})/12"  #Q
        row+=1
      end
      unless top == row
        worksheet.cells(row,1).value = "Total"
        worksheet.cells(row,4).formula = "=sum(D#{top}:D#{row-1})"
        worksheet.cells(row,7).formula = "=sum(G#{top}:G#{row-1})"
        worksheet.cells(row,9).formula = "=sum(I#{top}:I#{row-1})"
        worksheet.cells(row,10).formula = "=sum(J#{top}:J#{row-1})"
        worksheet.cells(row,14).formula = "=sum(N#{top}:N#{row-1})"
        worksheet.cells(row,17).formula = "=sum(Q#{top}:Q#{row-1})"
        worksheet.rows(row).font.italic = true
      end
      row+=1
      worksheet.cells(row,17).formula = "=G#{row-1} * ( 1 + $J$#{sparerow})"
      row+=1
      worksheet.cells(row,17).formula = "=Q#{row-1} - Q#{row-2}"
      worksheet.cells(row,17).NumberFormat = "0.0;[red]0.0"
      # end tally section
      
      begin
        workbook.saveas(tl_file_name)
      rescue
        UI.messagebox("Error saving Excel File (might be open in excel)")
      end  

      workbook.Close(1)
      excel.Quit
    else  # csv mode
      tl_file << "=== Timbers:\n"
      if metric
        then tl_file << "Name\t\tW\tD\tL(m)\tL(cm)\n"
        else tl_file << "Name\t\tW\tD\tL(ft)\tL(in)\tBF\n"
      end
      nl.each do |ct|
        if (ct.count > 1) 
          print("warning: duplicate named timber:"+ct.name+"\n") 
          UI.messagebox("TF Rubies: warning: Duplicate Named Timber: " + ct.name + "\nDimensions will not be correct in list.")
        end
        ct.count.times do
          if metric
            tl_file << ct.name  << "\t\t" << ct.w << "\t" << ct.d << "\t" << ct.ft << "\t" << ct.l << "\n"
          else  
            bf = (ct.w * ct.d * ct.ft)/12
            bf = ((bf*10).round)/10.0
            tl_file << ct.name  << "\t\t" << ct.w << "\t" << ct.d << "\t" << ct.ft << "\t" << ct.l << "\t" << bf.to_s << "\n"
          end  
        end
      end  
      tl_file << "\n" << "=== Un-named components:\n"

      if metric
        then tl_file << "Name\tQty\tW\tD\tL(m)\tL(cm)\n"
        else tl_file << "Name\tQty\tW\tD\tL(ft)\tL(in)\tBF\n"
      end
      ul.each do |ct|
        if metric 
          tl_file << ct.name << "\t" << ct.count << "\t" << ct.w << "\t" << ct.d << "\t" << ct.ft << "\t" << ct.l << "\n"
        else  
          bf = (ct.count * ct.w * ct.d * ct.ft)/12
          bf = ((bf*10).round)/10.0
          tl_file << ct.name << "\t" << ct.count << "\t" << ct.w << "\t" << ct.d << "\t" << ct.ft << "\t" << ct.l << "\t" << bf.to_s << "\n"
        end  
      end
      tl_file << "\n" << "=== Tally:\n"

      if metric
        then tl_file << "W\tD\tQty\tL(m)\n"
        else tl_file << "W\tD\tQty\tL(ft)\tBF\n"
      end
      cl.each do |ct|
        if metric 
          tl_file << ct.w << "\t" << ct.d << "\t" << ct.count << "\t" << ct.ft << "\n"
        else  
          bf = (ct.count * ct.w * ct.d * ct.ft)/12
          bf = ((bf*10).round)/10.0
          tl_file << ct.w << "\t" << ct.d << "\t" << ct.count << "\t" << ct.ft << "\t" << bf.to_s << "\n"
        end  
      end
      tl_file.close
    end  
    print("timber list saved\n")
    begin    
 			rescue
    		print("TF Rubies: Error creating timber list: " + $!.message + "\n")
    		UI.messagebox("TF Rubies: Error creating timber list: " + $!.message)
  		ensure
		end    
  	model.definitions.purge_unused    
  end  
end

def CB_TF.count_joints
  joint_count = 0
  timber_count = 0
  peg_count = 0
  no_dod_count = 0
  dod = 0
  model = Sketchup.active_model
  model.active_entities.each do |timber|
    next if not timber.instance_of? Sketchup::ComponentInstance 
    next if timber.hidden?
    next if not timber.layer.visible?
    timber_count = timber_count + 1    
    dod += timber.definition.get_attribute( JAD, "DoD", 0.0)
    if timber.definition.get_attribute( JAD, "DoD", 0.0) == 0.0 then
      no_dod_count += 1
    end
    timber.definition.entities.each do |tenon|
      next if not tenon.instance_of? Sketchup::ComponentInstance 
      if tenon.definition.get_attribute( JAD, "tenon", false) then
        joint_count = joint_count + 1
        tenon.definition.entities.each do |peg|
          next if not peg.instance_of? Sketchup::Face
          next if not peg.get_attribute( JAD, "peg", false)
          # note that it takes two peg 'faces' to make one peg.
          peg_count = peg_count + 0.5
        end  
      end  
    end
  end  
  dod = ((dod * 10000).round)/10000.0
  UI.messagebox(joint_count.to_s + " Joints in " + timber_count.to_s + " Timbers.\n" + peg_count.round.to_s + " Pegs.\n" + dod.to_s + " total DoD\n" + no_dod_count.to_s + " Timbers have no DoD", MB_OK, "Frame Stats")
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
##  make_peg merely marks a component with an attribute dictionary entry
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


# Report the version
def CB_TF.tf_version
	vv = CbPluginInfo::CB_TimberFraming_VERSION
	dd = CbPluginInfo::CB_TimberFraming_DATE
  UI.messagebox("TF Extensions Version #{vv} - #{dd} - Copyright (c) Clark Bremer.")
end


def CB_TF.tf_contribute
  UI.messagebox("To show your appreciation, and\nsupport further development of the TF Extensions,\nfeel free to leave a contribution in my\npaypal account: clarkbremer@gmail.com\n")
end


end # module CB_TF
# main program - runs when the script gets loaded

if( not file_loaded?("tf.rb") )
    JAD = "TF_Joinery"
    MODEL_OFFSET = 0
    SIDE_SPACING = 30
    UI.add_context_menu_handler do |menu|
    if menu == nil then 
      UI.messagebox("Error settting context menu handler")
    end
        menu.add_separator
    if CB_TF.sel_is_tenon
      menu.add_item("TF ID: Joint") {UI.beep}
#      menu.add_item("Reroll Joint") {create_joint}
    elsif CB_TF.sel_is_peg
      menu.add_item("TF ID: Peg") {UI.beep}
#    else
#      menu.add_item("TF ID: None") {UI.beep}    
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
  end
  tf_menu = UI.menu("Plugins").add_submenu("TF Rubies")
  if tf_menu == nil then
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
