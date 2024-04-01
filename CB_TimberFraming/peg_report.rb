# load "G:/My Drive/TF/Sketchup/Rubies/CB_TimberFraming/CB_TimberFraming/peg_report.rb"
# CB_TF.reg_report
# Everything goes in our module 
module CB_TF

  # uses raytest to find the next face (not necessarily parallel, but...)
  # p and v must be in global coordinates
  def CB_TF.face_and_distance(p, v)
    model = Sketchup.active_model
    target, path = model.raytest([p, v])
    return nil, nil unless target
    distance = p.distance(target)
    face = path.last
    puts "f&d did not find a face" unless face.instance_of?(Sketchup::Face) 
    return face, distance
  end

  # we assume the faces are parallel, so we can use the center of the peg 
  def CB_TF.distance_between_faces(peg, face)
    c = peg.bounds.center
    p = face.plane
    return c.distance_to_plane(p)
  end

  def CB_TF.deep_id(timber, tenon, peg)
    [timber.entityID, tenon.entityID, peg.entityID]
  end

  def CB_TF.peg_report
    puts "Starting Peg Report"
    # for every CI in model
    report = {}
    done = []
    mm = Sketchup.active_model
    mm.entities.grep(Sketchup::ComponentInstance) do |timber|
      # for every sub-component that's a tenon
      next if timber.hidden?
      next unless timber.layer.visible?      
      timber.definition.entities.grep(Sketchup::ComponentInstance) do |tenon|
        next unless has_attribute?(tenon.definition, "tenon")
        # for every peg in the tenon that's not marked as "done"
        tenon.definition.entities.grep(Sketchup::Face) do |peg|
          next unless has_attribute?(peg, "peg")
          if done.include?(deep_id(timber, tenon, peg))
            # puts "skipping peg #{peg} (#{peg.entityID}) because marked done"
            next
          end
          length = 0
          # mark it as "done"
          done << deep_id(timber, tenon, peg)
          # cast a ray in one direction.  
          v = Geom::Vector3d.new(peg.normal)
          p =  Geom::Point3d.new(peg.bounds.center)
          # move these to global space
          p.transform!(tenon.transformation)
          p.transform!(timber.transformation)
          v.transform!(tenon.transformation)
          v.transform!(timber.transformation)
          f, d = face_and_distance(p, v)
          next unless f
          # If we hit another peg face, 
          if has_attribute?(f, "peg")
            # cast a ray in the opposite direction instead
            # puts ("(next face was a peg, so reversing and trying again)")
            v.reverse!
            f, d, path = face_and_distance(p, v)
          end
          # It should be a face (the near side of the timber)
          # But I guess it could be the edge of another mortise if the 
          # peg is placed there, like for a ridge?
          next unless f
          # puts "Near face: #{f} (#{f.entityID})"
          # puts "\tdistance: #{d}"
          length += d
          # cast a ray in the opposite direction - should be a peg face
          v.reverse!
          peg2, d = face_and_distance(p, v) 
          if has_attribute?(peg2, "peg")
            # If it's alreay marked "done", abort and move on. 
            if done.include?(deep_id(timber, tenon, peg2))
              break
            else 
              # mark it as "done"
              done << deep_id(timber, tenon, peg2)
              # puts "companion peg face #{peg2} (#{peg.entityID})"
              # puts "\tdistance: #{d}"  #<-  getting wrong answer here.  Should be 2 (tenon thickness)
              # add it to the length.
              length += d
              # cast from that face in the same direction 
              p2 = peg2.bounds.center
              v2 = peg2.normal
              p2.transform!(tenon.transformation)
              p2.transform!(timber.transformation)
              v2.transform!(tenon.transformation)
              v2.transform!(timber.transformation)
              v2.reverse! unless v2.samedirection?(v)
              f2, d = face_and_distance(p2, v2)
              # should be a face (the far face of the timber)
              next unless f2
              # puts "far face #{f2} (#{f2.entityID})"
              # puts "\tdistance: #{d}"
              # add it to the length.
              length += d
            end
          else
            puts "** Aborting, companion peg not found."
            break
          end


          # merge peg to report
          length = (length + 0.1).round # if timbers are 1/2" under, we want to make sure we round up
          if report[length] 
            report[length] += 1
          else
            report[length] = 1
          end
        end
      end
    end
    # display the report
    report = report.sort_by{|k,v| k}
    display_peg_report(report)
    puts "peg report complete"
  end # peg_report

  def CB_TF.display_peg_report(report)
    table_html = ""
    report.each do |size, count| 
      table_html += "<tr><td>#{size}</td><td>#{count}</td></tr>"
    end
    
    dialog = UI::HtmlDialog.new(
      {
        :dialog_title => "Peg Report",
        :scrollable => true,
        :resizable => false,
        :width => 300,
        :height => 500,
        :left => 200,
        :top => 200,
        :style => UI::HtmlDialog::STYLE_DIALOG
      })

    html = %Q[
      <!DOCTYPE html>
      <html>
        <head>
          <title>Peg Report</title>
          <style>
            h1 {
              font-family: arial, sans-serif;
              text-align: center;
            }
            table {
              font-family: arial, sans-serif;
              border-collapse: collapse;
              width: 100%;
            }
            td, th {
              border: 1px solid #dddddd;
              text-align: left;
              padding: 8px;
            }
            tr:nth-child(even) {
              background-color: #dddddd;
            }
            p.center {
              text-align: center;
            }
          }
          </style>
        </head>

        <body>
          <h1>Peg Report</h1>
          <table>
            <tr>
              <th>Length</th>
              <th>Count</th>
            </tr>
            #{table_html}
          </table>
          <p class="center"><button onclick="sketchup.close_peg_report()">Close</button></p>
        </body>
      </html>
    ]
    dialog.set_html(html)
    dialog.add_action_callback("close_peg_report") { |action_context|
      dialog.close()
    }
    dialog.show_modal
  end #display_peg_report
end # module