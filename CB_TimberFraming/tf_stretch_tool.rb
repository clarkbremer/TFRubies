##  Ruby extensions to Sketchup for Timber Framers
##  Copyright (c) 2013 Clark Bremer
##  DIY Timber Framing
##  clark@diytf.com
##
##	TF StretchTool (v 1.1)   5/5/2013
##
##	This tool will stretch a component the "long" way.
##	The difference between this and the scale tool is that this tool does not distort 
##  the geometry at the ends of the component.
##

#-----------------------------------------------------------------------------

require 'sketchup.rb'

#-----------------------------------------------------------------------------
module CB_TF

class TFStretchTool

# This is the standard Ruby initialize method that is called when the tool is created
def initialize
    @ip1 = nil
    @ip2 = nil
	@cursor_id=getCursorID("stretch_tool.png",16,16)
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

# The activate method is called by SketchUp each time the tool is selected.
def activate
    # The Sketchup::InputPoint class is used to get 3D points from screen
    # positions.  It uses the SketchUp inferencing code.
    # In this tool, we will have two points - the start and stop points.
    @ip1 = Sketchup::InputPoint.new	 #inupt point for first mouse click
    @ip2 = Sketchup::InputPoint.new  # input point for second mouse click
	@gp1 = Geom::Point3d.new(0,0,0)  # global values for the input point positions
	@gp2 = Geom::Point3d.new(0,0,0)  
	@gv = Geom::Vector3d.new(0,0,0) # global vector - this is the direction we are stretching, in global space
	@tp = Geom::Point3d.new(0,0,0)	#stretch target point in global space
    @ip = Sketchup::InputPoint.new	# the current input point while moving the mouse
    @drawn = false
	@ents_to_move = Array.new		# this is the "half" of the component that we move as we stretch
	@prev_pos = Geom::Point3d.new(0,0,0)	# used to compute how far to move with each mouse event
	@length = 0.0						# how far we have moved so far, negative meaning getting smaller
	@min_length = 0						# kind of a kludge - we don't want the user turning the component "insiude out", so we enforce a minimum length of 1/4 the original size.
	@ci = selected_component()			# this is the compnent being streteched
	@initial_comp_selected = false		# if there was nothing selected when we start, then we 'select' any comp that the mouse hovers over
	if @ci
		@initial_comp_selected = true
	end	
	@last_comp_moved = nil				# if using the vcb to move after second click, we need to know what was moved before, if anything, so we can move it by number.

    # This sets the label for the VCB
    Sketchup.vcb_label = ""
    
    self.reset(nil)
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
        # We are getting the first end of the line.  Call the pick method
        # on the InputPoint to get a 3D position from the 2D screen position
        # that is bassed as an argument to this method.
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
            if @ci == nil
				# there was no component selected when we started the tool
				# highlight whatever ci is under the mouse cursor
				mm = Sketchup.active_model
				ss = mm.selection
				ph = view.pick_helper
				ph.do_pick(x,y)
				bp = ph.best_picked
				if bp.instance_of? Sketchup::ComponentInstance
					ss.clear
					ss.add(bp)
				else 
					ss.clear
				end
			end
			
            # set the tooltip that should be displayed to this point
            view.tooltip = @ip1.tooltip
        end
    else
        # Getting the second end of the line
        # If you pass in another InputPoint on the pick method of InputPoint
        # it uses that second point to do additional inferencing such as
        # parallel to an axis.
        @ip2.pick view, x, y, @ip1
        view.tooltip = @ip2.tooltip if( @ip2.valid? )
        view.invalidate
	
        if( @ip2.valid? )
			@gp2 = @ip2.position							#global p2
						
			tplane = [@gp2, @gv]						# target plane
			@tp = @gp1.project_to_plane(tplane)			#target point (in global space)
			ltp = @tp.clone								# local target point
			ltp.transform!(@ci.transformation.inverse)
			
			# Update the length displayed in the VCB
			@length = @gp1.distance_to_plane(tplane)
			@length = @gp1.distance(@tp)
			if @length != 0 
				vv = @tp.vector_to(@gp1)
				if vv.samedirection? @gv
					@length = @length * -1
				end
			end
			return if @length < @min_length
            Sketchup.vcb_value = @length.to_l.to_s
			
			offs_vector = @prev_pos.vector_to(ltp)
			#puts "offset vector " << offs_vector.to_s
			move_it(offs_vector)
			
			@prev_pos = ltp
        end
    end
end

# The onLButtonDOwn method is called when the user presses the left mouse button.
def onLButtonDown(flags, x, y, view)
    # When the user clicks the first time, we colelct all the elements in this half of the component. 
    #  When they click a second time we stop
    if( @state == 0 )
		# first click
        @ip1.pick view, x, y
        if( @ip1.valid? )
			# user picked first point.  
			@gp1 = @ip1.position  # global position
			model = Sketchup.active_model
						
			if @ci == nil
				# there was no ci selected when we started to tool, but perhps the user was hovering over one when they clicked the mouse
				@ci = selected_component
				return if @ci == nil
			end
			cd = @ci.definition		# the definition for the component
			#print("gp1: "+@gp1.to_s + "\n")
			
 			lp1 = @ip1.position # local position
			lp1.transform!(@ci.transformation.inverse)
			le = @ci.tf_longest_edge
			#puts "longest edge: " << le.start.position.to_s << "  " << le.end.position.to_s
			lv = Geom::Vector3d.new(le.line[1])	#local vector
			#puts "local vector: " << lv.to_s
			# We need to locate all gemoetry at "this" end of the componenet.  We divide it in half the "long" way
			# Lets start by finding the plane that bisects the component - the midplane
			midplane = [cd.bounds.center, lv]   					# plane is just a point and a vector - both local
			pp1 = lp1.project_to_plane(midplane)		# pp1 = lp1 projected onto the midplane
			vec1 = pp1.vector_to(lp1)					# vec1 = vector from pp1 to lp1.  
			#puts "vec1: " << vec1.to_s
			#We do the same for all other points - those whose vector is the same direction as vec1 are on the same side
			@ents_to_move.clear
			cd.entities.each do |e|
				case e
					when Sketchup::Edge
						# For edges, both vertices must lie on this side
						ep1 = e.start.position
						pep1 = ep1.project_to_plane(midplane)
						next if ep1 == pep1
						ep2 = e.end.position
						pep2 = ep2.project_to_plane(midplane)
						next if ep2 == pep2
						if pep1.vector_to(ep1).samedirection?(vec1) and pep2.vector_to(ep2).samedirection?(vec1) then
							@ents_to_move.push(e)
						end
					
					when Sketchup::ComponentInstance
						# for comps, we'll just test the center point
						cp = e.bounds.center
						#puts "cp: " << cp.to_s
						pcp = cp.project_to_plane(midplane)
						#puts "pcp: " << pcp.to_s
						next if pcp == cp	# component center is on the midplane.  Can't take a vector of that.  Just skip it.
						if pcp.vector_to(cp).samedirection?(vec1) then
							@ents_to_move.push(e)
						end	
					# seems that all we need are edges and sub-cmps
				end
			end
			
			#puts "ents to move:"
			#@ents_to_move.each do |e|
			#	puts e.to_s
			#end
			
			@gv = lv.clone							# global vector
			@gv.transform!(@ci.transformation)		# transform to global space
			if not lv.samedirection?(vec1) 		# we want @gv to point in the "growing" direction, not the "shrinking" direction
				#puts "reversing @gv"
				@gv.reverse!	
			end
			#puts "global vector: " << @gv.to_s
			@min_length = -1.5 * (vec1.length)
			#puts "min_length: " << @min_length.to_s
			@prev_pos = lp1	
			#puts "@prev_pos: " << @prev_pos.to_s
            Sketchup::set_status_text "Select Stretch Destination", SB_PROMPT
            Sketchup.vcb_label = "Stretch Distance"
            @state = 1
			Sketchup.active_model.start_operation("TF Stretch")			

       end
	   
    else  # second mouse click - we're done, just clean up
        if( @ip2.valid? )
            self.reset(view)
        end
    end
    
    # Clear any inference lock
    view.lock_inference
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
def onUserText(text, view)
    return if @last_comp_moved == nil
    
    # The user may type in something that we can't parse as a length
    # so we set up some exception handling to trap that
    begin
        distance = text.to_l
    rescue
        # Error parsing the text
        UI.beep
        puts "Cannot convert #{text} to a Length"
        distance = nil
        Sketchup::set_status_text "", SB_VCB_VALUE
    end
    return if !distance
	
#	puts "moving via VCB: " << distance.to_s
	
	# put everything bakc the way we started
	if @state == 1 
		self.reset(view)
	end	
	Sketchup.undo	
	
	if @length < 0 
		distance = distance * -1
	end
	
	@ci = @last_comp_moved
#	puts "@gv: " << @gv.to_s
	mov_vec = @gv.clone
	mov_vec.transform!(@ci.transformation.inverse)
	mov_vec.length = distance
#	puts "mov_vec: " << mov_vec.to_s
	move_it(mov_vec)
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
            
            # The set_color_from_line method determines what color
            # to use to draw a line based on its direction.  For example
            # red, green or blue.
            view.set_color_from_line(@ip1, @ip2)
			view.line_stipple = "."
			view.draw_line(@gp1, @gp2)
			view.line_stipple = ""
			 
            @drawn = true
        end
    end
end

# onCancel is called when the user hits the escape key
def onCancel(flag, view)
    self.reset(view)
	Sketchup.undo
end


# The following methods are not directly called from SketchUp.  They are
# internal methods that are used to support the other methods in this class.
def move_it(offs_vector)
	xlat = Geom::Transformation.new(offs_vector)
	
	cd = @ci.definition
	cd.entities.transform_entities(xlat, @ents_to_move)
	
	@last_comp_moved = @ci
end		


# Reset the tool back to its initial state
def reset(view)
    # This variable keeps track of which point we are currently getting
    @state = 0
    
    # Display a prompt on the status bar
    Sketchup::set_status_text("Select Stretch Start Point", SB_PROMPT)
    
    # clear the InputPoints
    @ip1.clear
    @ip2.clear
    
    if( view )
        view.tooltip = nil
        view.invalidate if @drawn
    end
    
    @drawn = false
    @dragging = false
	Sketchup.active_model.commit_operation
	if @initial_comp_selected == false 
		Sketchup.active_model.selection.clear()
		@ci = nil
	end	
end


def selected_component
    mm = Sketchup.active_model
    ss = mm.selection
    return nil if ss.count != 1 
    cc = ss[0]
    return nil if not cc.instance_of? Sketchup::ComponentInstance
    cc
end



end # class TFStretchTool
end # module CB_TF