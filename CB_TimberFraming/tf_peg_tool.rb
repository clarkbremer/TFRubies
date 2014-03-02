##  Ruby extensions to Sketchup for Timber Framers
##  Copyright (c) 2013 Clark Bremer
##  
##  clark@diytf.com
##
##	TF Peg Tool (v 1.0)   5/8/2013
##	Borrowed heavily from linetool example
##	User must have a joint component selected to use the tool.
##

module CB_TF

class TFPegTool

# This is the standard Ruby initialize method that is called when you create
# a new object.
def initialize 
    @ip1 = nil
    @ip2 = nil
    @xdown = 0
    @ydown = 0
	@cursor_id=getCursorID("peg_tool.png",16,16)
end

def getCursorID(filename, hotx, hoty)
	cursorPath = Sketchup.find_support_file(filename, "Plugins/CB_TimberFraming")
	if cursorPath
		id = UI.create_cursor(cursorPath, hotx, hoty)
	else
		id=0
	end
	return id
end


# The activate method is called by SketchUp when the tool is first selected. 
# it is a good place to put most of your initialization
def activate
    # The Sketchup::InputPoint class is used to get 3D points from screen
    # positions.  It uses the SketchUp inferencing code.
    # In this tool, we will collect two points 
    @ip1 = Sketchup::InputPoint.new
    @ip2 = Sketchup::InputPoint.new
    @ip = Sketchup::InputPoint.new
    @drawn = false
	@num_pegs = 0 
	@prev_pt1 = nil
	@prev_pt2 = nil
	@lp1 = Geom::Point3d.new	# input points in local coordinates
	@lp2 = Geom::Point3d.new

    # This sets the label for the VCB
    Sketchup::set_status_text "Offsets (x,y)", SB_VCB_LABEL
    
    self.reset(nil)
		
	unless sel_is_tenon? 
		return
	end	

end

# deactivate is called when the tool is deactivated because
# a different tool was selected
def deactivate(view)
    view.invalidate if @drawn
end

def onSetCursor()
	cursor = UI::set_cursor(@cursor_id)
end

# The onMouseMove method is called whenever the user moves the mouse.
# because it is called so often, it is important to try to make it efficient.
# In a lot of tools, your main interaction will occur in this method.
def onMouseMove(flags, x, y, view)

    if( @state == 0 )
        # We are getting the reference point.  Call the pick method
        # on the InputPoint to get a 3D position from the 2D screen position
        # that is based as an argument to this method.
        @ip.pick view, x, y
        if( @ip != @ip1 )
            # if the point has changed from the last one we got, then
            # see if we need to display the point.  We need to display it
            # if it has a display representation or if the previous point
            # was displayed.  The invalidate method on the view is used
            # to tell the view that something has changed so that you need
            # to refresh the view.
            view.invalidate if( @ip.display? or @ip1.display? )
            @ip1.copy! @ip
            
            # set the tooltip that should be displayed to this point
            view.tooltip = @ip1.tooltip
        end
    else
        # Getting the actual peg position
        # If you pass in another InputPoint on the pick method of rInputPoint
        # it uses that second point to do additional inferencing such as
        # parallel to an axis.
        @ip2.pick view, x, y, @ip1
        view.tooltip = @ip2.tooltip if( @ip2.valid? )
        view.invalidate
        
        # Update the coords displayed in the VCB
        if( @ip2.valid? )
			# ip1 and ip2 are in global coordinates.  We need locals.
			gp1 = @ip1.position
			gp2 = @ip2.position
			
			model = Sketchup.active_model

#			print("gp1: "+gp1.to_s + "\n")
			gxfrm = Geom::Transformation.translation(gp1)
	 		@lp1.set!(0,0,0)
			@lp1.transform!(selected_component.transformation.inverse * gxfrm)
#			print("lp1: "+@lp1.to_s+"\n")
			gxfrm = Geom::Transformation.translation(gp2)
			@lp2.set!(0,0,0)
			@lp2.transform!(selected_component.transformation.inverse * gxfrm)

			
			deltax = (@lp2.x-@lp1.x).abs.to_l
			deltay = (@lp2.y-@lp1.y).abs.to_l
			deltaz = (@lp2.z-@lp1.z).abs.to_l
			if deltax == 0
				Sketchup::set_status_text deltay.to_s+", "+deltaz.to_s, SB_VCB_VALUE
			elsif deltay == 0
			    Sketchup::set_status_text deltax.to_s+", "+deltaz.to_s, SB_VCB_VALUE
			else
			    Sketchup::set_status_text deltax.to_s+", "+deltay.to_s, SB_VCB_VALUE
			end
         end
        
        # Check to see if the mouse was moved far enough to create a line.
        # This is used so that you can create a line by either draggin
        # or doing click-move-click
        if( (x-@xdown).abs > 10 || (y-@ydown).abs > 10 )
            @dragging = true
        end
    end
end

# The onLButtonDOwn method is called when the user presses the left mouse button.
def onLButtonDown(flags, x, y, view)
    # When the user clicks the first time, we switch to getting the
    # second point.  When they click a second time we create the peg
	unless sel_is_tenon? 
		return
	end	

    if( @state == 0 )
        @ip1.pick view, x, y
        if( @ip1.valid? )
            @state = 1
            Sketchup::set_status_text "Select peg position", SB_PROMPT
            @xdown = x
            @ydown = y
        end
    else
        # create the peg on the second click
        if( @ip2.valid? )
            self.create_geometry(@lp1, @lp2,view)
            self.reset(view)
        end
    end
    
    # Clear any inference lock
    view.lock_inference
end

# The onLButtonUp method is called when the user releases the left mouse button.
def onLButtonUp(flags, x, y, view)
    # If we are doing a drag, then create the line on the mouse up event
    if( @dragging && @ip2.valid? )
        self.create_geometry(@ip1.position, @ip2.position,view)
        self.reset(view)
    end
end

# onKeyDown is called when the user presses a key on the keyboard.
# We are checking it here to see if the user pressed the shift key
# so that we can do inference locking
def onKeyDown(key, repeat, flags, view)
    if( key == CONSTRAIN_MODIFIER_KEY && repeat == 1 )
        @shift_down_time = Time.now
        
        # if we already have an inference lock, then unlock it
        if( view.inference_locked? )
            # calling lock_inference with no arguments actually unlocks
            view.lock_inference
        elsif( @state == 0 && @ip1.valid? )
            view.lock_inference @ip1
        elsif( @state == 1 && @ip2.valid? )
            view.lock_inference @ip2, @ip1
        end
    end
end

# onKeyUp is called when the user releases the key
# We use this to unlock the interence
# If the user holds down the shift key for more than 1/2 second, then we
# unlock the inference on the release.  Otherwise, the user presses shift
# once to lock and a second time to unlock.
def onKeyUp(key, repeat, flags, view)
    if( key == CONSTRAIN_MODIFIER_KEY &&
        view.inference_locked? &&
        (Time.now - @shift_down_time) > 0.5 )
        view.lock_inference
    end
end

# onUserText is called when the user enters something into the VCB
# We collect two offset values: x,y, and place the peg at that point.
def onUserText(text, view)    
    # The user may type in something that we can't parse as a length
    # so we set up some exception handling to trap that
    begin
		o1s, o2s = text.split(',')
        off1 = o1s.to_l
		off2= o2s.to_l
    rescue
        # Error parsing the text
        UI.beep
        puts "#{text} is not in X,Y format"
        off1 = nil
		off2 = nil
        Sketchup::set_status_text "", SB_VCB_VALUE
    end
    return if !off1

	if @state == 1 and @ip2.valid?
		# the user entered values in the VCB before the second click, so we just use the current cursor values, and offset from there
	    pt1 = @ip1.position
		pt2 = @ip2.position
	elsif @num_pegs > 0
		# the user entered values after placing a peg.  We need to retrieve the cursor values they used when placing that peg so 
		# that we can offset from them.  Also erase that peg.
		pt1 = @prev_pt1
		pt2 = @prev_pt2
		Sketchup.undo # clear the last peg holes
	else
		return	#invalid state for taking VCB input
	end
	
#	print("VCB pt1: "+pt1.to_s+"\n")
	# which plane are we operating in?
	if pt1.x == pt2.x
#		print("x plane\n")
		if pt1.y > pt2.y then 
			off1 = -off1 
		end
		if pt1.z > pt2.z then 
			off2 = -off2
		end	
		ctr = Geom::Point3d.new(pt1.x, pt1.y+off1, pt1.z+off2)
		
	elsif pt1.y == pt2.y
#		print("y plane\n")
		if pt1.x > pt2.x then 
			off1 = -off1 
		end
		if pt1.z > pt2.z then 
			off2 = -off2
		end	
		ctr = Geom::Point3d.new(pt1.x+off1, pt1.y, pt1.z+off2)
	elsif pt1.z == pt2.z
# 		print("z plane\n")
		if pt1.x > pt2.x then 
			off1 = -off1 
		end
		if pt1.y > pt2.y then 
			off2 = -off2
		end	
		ctr = Geom::Point3d.new(pt1.x+off1, pt1.y+off2, pt1.z)
	else
		print("no common plane?")
	end
		
    # Create a peg
#	print("using VCB to create peg at :"+ ctr.to_s + "\n")
    self.create_geometry(pt1, ctr, view)
    self.reset(view)
end

# The draw method is called whenever the view is refreshed.  It lets the
# tool draw any temporary geometry that it needs to.
def draw(view)
    if( @ip1.valid? )
        if( @ip1.display? )
            @ip1.draw(view)
            @drawn = true
        end
        
        if( @ip2.valid? )
            @ip2.draw(view) if( @ip2.display? )
			view.line_stipple="-"
			p1 = @ip1.position
			p2 = @ip2.position
			view.draw_line(p1,p2)
			if p1.x == p2.x
				p3 = Geom::Point3d.new(p1.x,p2.y,p1.z)
				p4 = Geom::Point3d.new(p1.x,p1.y,p2.z)
			elsif p1.y == p2.y
				p3 = Geom::Point3d.new(p1.x,p1.y,p2.z)
				p4 = Geom::Point3d.new(p2.x,p1.y,p1.z)
			else 
				p3 = Geom::Point3d.new(p1.x,p2.y,p1.z)
				p4 = Geom::Point3d.new(p2.x,p1.y,p1.z)
			end
		    view.draw_polyline(p1, p3, p2, p4, p1)
            @drawn = true
        end
    end
end

# onCancel is called when the user hits the escape key
def onCancel(flag, view)
    self.reset(view)
end


# The following methods are not directly called from SketchUp.  They are
# internal methods that are used to support the other methods in this class.

# make sure that what is selected is a component instance, and return it
def selected_component
    mm = Sketchup.active_model
    ss = mm.selection
    return nil if ss.count != 1 
    cc = ss[0]
    return nil if not cc.instance_of? Sketchup::ComponentInstance
    cc
end

# make sure the selected component is a joint
def sel_is_tenon?
	unless sel=selected_component
		UI.beep
		Sketchup::set_status_text "Must have joint component selected", SB_PROMPT
		return false
	end	
	unless sel.definition.get_attribute( JAD, "tenon", false)
		UI.beep
		Sketchup::set_status_text "Must have joint component selected", SB_PROMPT
		return false
	end
	return true
end

# Reset the tool back to its initial state
def reset(view)
    # This variable keeps track of which point we are currently getting
    @state = 0
    
    # Display a prompt on the status bar
    Sketchup::set_status_text "Select reference point", SB_PROMPT
    
    # clear the InputPoints
    @ip1.clear
    @ip2.clear
    
    if( view )
        view.tooltip = nil
        view.invalidate if @drawn
    end
    
    @drawn = false
    @dragging = false
end

def create_peg(ctr, comp_def)
	# find the face we just added and mark it as a peg
	peg_face = nil
	comp_def.entities.each do |face|
		next if not face.instance_of? Sketchup::Face
		if face.classify_point(ctr) >= 1 and face.classify_point(ctr) <= 4 then
			peg_face = face
			break
		end
	end

	if peg_face == nil
		UI.beep
	else
		ad = peg_face.attribute_dictionary(JAD, true)  
		peg_face.set_attribute(JAD, "peg", true)
#		print "peg made:", peg_face, "\n"
	end
	return peg_face
end

# Create a pair of pegs at these coordinates.  p1 and p2 are local coordiantes
def create_geometry(p1, p2, view)
#	print("p1: "+p1.to_s+"\n")
#	print("p2: "+p2.to_s+"\n")
	model = Sketchup.active_model
	
	ci = selected_component 
#	print("Current Inst: "+ ci.to_s+"\n")
	cd = ci.definition
#	print("Current Def: "+ cd.to_s+"\n")
	
	
	# find the face the peg should be on, se we can set the vector.
	ten_face = nil
	cd.entities.each do |face|
		next if not face.instance_of? Sketchup::Face
		if face.classify_point(p2) >= 1 and face.classify_point(p2) <= 4 then
			ten_face = face
			break
		end
	end
	if ten_face == nil
		UI.messagebox("Pegs must be added to face inside of joint component **")
	else
		model.start_operation("tf_peg_tool")
#		print("adding frontside peg at :"+p2.to_s+"\n")
		cd.entities.add_circle(p2, ten_face.normal, 0.5)	
		peg_face = create_peg(p2,cd)
		unless peg_face == nil
			# now make it on the other side
			#raytest works in global coorediante space    
			#rtp: raytest point; rtv: raytest vector - Start in local space
			rtp = Geom::Point3d.new(p2)
			rtv = Geom::Vector3d.new(peg_face.normal.reverse)
			# now transform to global space
			rtp.transform!ci.transformation
			rtv.transform!ci.transformation
			ppoint_info = model.raytest(rtp, rtv)

			if ppoint_info
				raypoint = ppoint_info[0]    # this will be in global coordinates
#				print("raypoint: "+raypoint.to_s+"\n")
				# create a new poitn and transform it back to local coordinates
				ctr = Geom::Point3d.new(0,0,0)
				gxfrm = Geom::Transformation.translation(raypoint)	 		
				ctr.transform!(selected_component.transformation.inverse * gxfrm)
#				print("adding backside peg at: "+ctr.to_s+"\n")
				cd.entities.add_circle(ctr, peg_face.normal, 0.5)	
				create_peg(ctr, cd)
			else 
				print("raytest failed (tenon cheek face is probably reversed)\n")
			end
		end
		model.commit_operation
		@num_pegs+=1
		@prev_pt1 = p1.clone
		@prev_pt2 = p2.clone
	end
end


end # class TFPegTool

end # module CB_TF




