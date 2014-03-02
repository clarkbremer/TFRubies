##
##  Assign DoD Tool to quickly assign a degree of difficulty (DoD) to a tinber 
##
##  	1) Select the Assign DoD tool from the plugins menu. 
##  	2) double click on any component instance
## 	3) enther the new DoD
##
##   I borrowed heavily from TIGs addvertex+ tool, and from Rick Wilson's repaint script
##
##    5/1/2013  Clark Bremer  
##              Tested on PC, SU13
##

require 'sketchup.rb'

module CB_TF

class DoDTool

def getCursorID(filename, hotx, hoty)
	cursorPath = Sketchup.find_support_file(filename, "Plugins/CB_TimberFraming")
	if cursorPath
		id = UI.create_cursor(cursorPath, hotx, hoty)
	else
		id=0
	end
	return id
end



def initialize
	@status="Double-click a timber to assign it's DoD."
	@cursor_id=getCursorID("dod.png",0,0)
end 

def reset
	@ip=Sketchup::InputPoint.new
end

def activate
	self.reset
	@model=Sketchup.active_model
	Sketchup.set_status_text(@status)
end

def onSetCursor()
	cursor = UI::set_cursor(@cursor_id)
end

def onLButtonDown(flags,x,y,view)
	@model.start_operation("Assign DoD")
	ph=@model.active_view.pick_helper
	ph.do_pick(x,y)
	picked_element=ph.best_picked
	@ip.pick(view,x,y)
	if not @ip.valid?
		picked_element=nil
	end
	if(picked_element) 
		return if not picked_element.instance_of? Sketchup::ComponentInstance
		ci = picked_element
	else
		@model.selection.clear
		return
	end 
	
	if( (flags & MK_SHIFT) ==  0 )
		@model.selection.clear
	end	
	@model.selection.add(ci)
	
	Sketchup.set_status_text(@status)
	@model.commit_operation
end 

def onLButtonDoubleClick(flags,x,y,view)
	@model.start_operation("Assign DoD")
	ph=@model.active_view.pick_helper
	ph.do_pick(x,y)
	picked_element=ph.best_picked
	@ip.pick(view,x,y)
	if not @ip.valid?
		picked_element=nil
	end
	if(picked_element)
		return if not picked_element.instance_of? Sketchup::ComponentInstance
		ci = picked_element
	else
		UI.beep
		Sketchup.set_status_text(@status)
		return
	end 
	model = Sketchup.active_model
	sel = model.selection
	sel.clear
	sel.add(ci)
	prompts = ["New DoD:"]
	defaults = [ci.definition.get_attribute(JAD, "DoD", 0.0)]
	results = inputbox(prompts, defaults, "Assign DoD")
	return if !results
	ci.definition.set_attribute(JAD, "DoD", results[0])
	
	Sketchup.set_status_text(@status)
	@model.commit_operation

end 

end 	# class DoDTool
end 	# module CB_TF
