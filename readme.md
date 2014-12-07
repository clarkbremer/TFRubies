# TF Rubies #
## Sketchup Extensions for Timber Framers ##

*If you just want to install the extensions, you're in the wrong place.*  Choose `window | extension warehouse` from the Sketchup menu.  Search the warehouse for **Timber Framing Extensions**, and install like any other plugin.  This is just the location to store and share the source code.

---
I'd happily accept help from anyone who wants to contribute some code to this project.  Below is a list of features I'd like to add, but feel free to come up with your own.

## To Do: ##
* Write our own version of "cut face" so we can cut multiple faces.  
	- Need to mark the "cutting face" on joint components,
* Bug: if timber name has illegal characters (like forward slash), save shop drawings fails.  
	- Need to scrub the name first.
* Hide cosmetic pegs before shop drawings and timber lists
* For finding extreme faces for ref faces, break ties with face size (as we already do with direction labels)
* Feature to make ALL shop drawings all at once.

## Revision History ##
 Version 2.4.5 12/6/2014
   - Remove all extensions to Sketchup::ComponentInstance class (per SU standards)

 Version 2.4.4 11/4/2014
   - Add Rakefile
   - Updates for SU2015
   - Refactor into smaller files
 Version 2.4.3 1/1/2014
   - First commit to GitHub
   - Update for SU-14
       - no scenes in shop drawings (use new page.erase method)
 Version 2.3 5/5/13
   - Package for SU-13 Extension Warehouse
 Version 2.2 11/11/11
   - Cosmetic Pegs
    - Stretch Tool
   - Eliminate need for status bar plugin
   - eliminate need for reglue file
   - warning message for duplcated named timbers
  Version 2.0
 - Peg Tool
 - DoD for each timber
 - Timber Tally page in timber list
  - Improved Repaint Face Tool (works more like select tool)
    - Better Metric support in timber list (many thanks to Jonas Ekefjord for his contribution)
 Version 1.19
 - Use new "gofast" option for shop drawing operation (did not work for timber list)
 - Peg Tool 
 - Timber list in "tally" format
 Version 1.18
    - Detect duplicate named timbers during timber list
 - Directional Labels on their own layer
    - Driectional Labels incorrect (pos green is north)
   - Color-coded mortise depth.
 - Config option to "roll backwards" for shop drawings (just use -90 instead of 90)
 - Automate ref face marks
 - Angle between faces tool (dihedral)
 - paint face tool new cursor
 - direction labels on rafters (top and bottom)
 - Directional Lables should dig into sub-comps to find extreme faces. 
 
 Version 1.17
 - Add support for Native Excel Timber List
 
Version 1.16  
 - Only hide backside joinery in xray mode
 - Hide backside directional lables.  
Version 1.15 5/14/2008
 - Hide housing line on shop drawings
 - Hide joints on back side of shop drawings
 - Roundup Dimensions option for timber list
 - Companion script rotate 90 around Z now works on groups and rotates around the center.
 - Fixed bug in direction lables if there are no opposite faces.
Version 1.14 2/15/2008
  - Fix bug in rotation of timbers rotated along their long axis by other than 90 or 45 degrees.
Version 1.13 12/24/2007
 - Add cpoint at center of pegs on tenons,
   - During "TF Create Joint":
   - make sure that "glue to" and "cut opening" are set.
   - Find and erase any faces in the joint that are on the red/green (cutting) plane.
 - Project pegs in both directions for mortises
 - Use leaders when creating directional labels, so they don't show through from the back side.
Version 1.12 12/24/2007
  - Bug Fix:  During Make Shop Drawings, and error would sometimes be gnereated about being unable to determine parent entity.
 Problem was in the way the model was being cleared before displaying the shop drawings.  
Version 1.11 10/26/2007
 - Bug Fix:  SU would crash if you try to make shop drawings on timebr within a component.  Disallow that.
 
Version 1.10 10/23/2007
 - In timber list, don't include hidden timbers, or timbers on disabled layers
 - Add "count joints" feature to count timbers, joints and pegs.
Version 1.9 10/12/2007  (Distributed at TFG 2007 Eastern Conference in Montebello)
 - Added Board Feet to timber list
 - Fixed bug with company name in timber list
Version 1.8 10/5/2007
  - Fixed bug in saving perspective view
   - Removed calls to GetString (internationalization) and hard-coded in English Language
 - Added support for metric units
Version 1.7 9/14/2007
 - Improved performance of timber list by getting dimensions only once per comp instance
 - Better implementation of poin_on_face (don't need external file any more)
 - Fixed bug in directional labels for timbers with no faces (splines?)
 Version 1.6 8/31/2007
 - Fixed bug with dimensions of purlins and braces.  Purlins needed to be rolled plumb and level, braces needed to ignore CPs


 On windows, cut and paste into ruby console for debugging:
 load "C:/Users/Clark/Documents/TimberFraming/Sketchup/Rubies/CB_TimberFraming/CB_TimberFraming/tf.rb"