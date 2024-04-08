module CB_TF
  ##########################################################
  ##  Make Timber List
  ##
  ##  load "G:/My Drive/TF/Sketchup/Rubies/CB_TimberFraming/CB_TimberFraming/timber_list.rb"
  ##  Helper Classes:
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
        CB_TF.get_dimensions(timber, min_extra_timber_length, metric, roundup, @tdims)
          ct = CountedTimber.new(name, 1, @tdims[0], @tdims[1], @tdims[2], @tdims[3], dod)
        @list.push(ct)
      end
    end

    def each
      @list.each {|ct| yield ct}
    end

    def length
      @list.length
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

  # this just needs to be defined for the excel automation to work.
  class ExcelConst
  end


  def CB_TF.make_timber_list
    begin

      model = Sketchup.active_model
      file_format = Sketchup.read_default("TF", "list_file_format", "C")
      tally_by_tag = Sketchup.read_default("TF", "list_by_tag", 0) == 1
      case file_format
      when "X"
        require('win32ole')
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
      when "C", "T"
        case file_format
        when "C"
          tl_file_name = UI.savepanel("Save Timber List", "","timber_list.csv")
        when "T"
          tl_file_name = UI.savepanel("Save Timber List", "","timber_list.txt")
        end  
        if tl_file_name
          while tl_file_name.index("\\")
            tl_file_name["\\"]="/"
          end
        end
      end
      if tl_file_name
        print("saving timber list as:"+tl_file_name + "\n")
        puts "Using tally by tag" if tally_by_tag
        begin
          File.delete(tl_file_name)
        rescue
        end
      else
        UI.messagebox("Timber List NOT saved!")
        if file_format == "X"
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
      case file_format
      when "X"
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
      when "C", "T"
        tl_file = File.new(tl_file_name, "w")
        tl_file << "Timber Materials List - " + company_name + "\n"
        tl_file << "Project: " + project + "\n"
        tl_file << ts << "\n"
        row = 4
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
          # puts "adding unnamed timber: #{timber.definition.name}"
          ul.add(timber, min_extra_timber_length, metric, roundup)
        else
          # Named timbers.  Assume they're unique
          # puts "adding named timber: #{timber.name}"
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

      if tally_by_tag
        layer_lists = {}
        model.active_entities.each do |timber|
          next if not timber.instance_of? Sketchup::ComponentInstance
          next if timber.hidden?
          next if not timber.layer.visible?
          ll = timber.layer
          unless layer_lists.has_key? ll
            layer_lists[ll]=TimberList.new
          end
          layer_lists[ll].add(timber, min_extra_timber_length, metric, roundup)
          # print("Added timber to tag #{ll.name}\n");
        end

        print("condensing\n")
        layer_lists.each_value do |list|
          list.condense!
        end
      end

      print("exporting\n")
      case file_format
      when "X"
        worksheet.cells(row,1).value = "Timbers"
        worksheet.cells(row,1).font.bold = true
        worksheet.cells(row,1).font.italic = true
        worksheet.cells(row,1).font.size = 14
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
        worksheet.cells(row,1).value = "Scantlings"
        worksheet.cells(row,1).font.bold = true
        worksheet.cells(row,1).font.italic = true
        worksheet.cells(row,1).font.size = 14
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
        worksheet = workbook.Worksheets.add(after: worksheet) #create page 2
        worksheet.name = "Tally"
        worksheet.columns("a").columnwidth = 10   # blank
        worksheet.columns("b").columnwidth = 5    # W
        worksheet.columns("c").columnwidth = 5    # D
        worksheet.columns("d").columnwidth = 5    # Qty
        worksheet.columns("e").columnwidth = 7    # L (ft)
        if metric
          worksheet.columns("e").NumberFormat = "0.0"
        end
        worksheet.columns("f").columnwidth = 7    # Blank
        worksheet.columns("g").columnwidth = 10   # BF
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

        if tally_by_tag
          worksheet = workbook.Worksheets.add(after: worksheet) #create page 3
          worksheet.name = "Tally by Tag"
          worksheet.columns("a").columnwidth = 10   # blank
          worksheet.columns("b").columnwidth = 5    # W
          worksheet.columns("c").columnwidth = 5    # D
          worksheet.columns("d").columnwidth = 5    # Qty
          worksheet.columns("e").columnwidth = 7    # L (ft)
          if metric
            worksheet.columns("e").NumberFormat = "0.0"
          end
          worksheet.columns("f").columnwidth = 7    # Blank
          worksheet.columns("g").columnwidth = 10   # BF
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
          worksheet.cells(row,1).value = "Timber Tally by Tag"
          worksheet.cells(row,1).font.bold = true
          worksheet.cells(row,1).font.size = 14
          row+=2
          worksheet.cells(row,1).value = "Project: "
          worksheet.cells(row,2).value = project
          worksheet.cells(row,2).font.bold = true
          row+=1
          worksheet.cells(row,1).value = ts
          row+=2
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

          worksheet.rows(row).font.bold = true
          for col in 2..7
            worksheet.cells(row, col).HorizontalAlignment = ExcelConst::XlHAlignRight
            worksheet.cells(row, col).font.size = 14
          end
          row+=1
          layer_lists.each_pair do |layer, list|
            worksheet.cells(row,1).value = layer.name
            worksheet.cells(row,1).font.size = 14
            row+=1
            top = row
            list.each do |ct|
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
              row+=1
            end
            unless top == row
              worksheet.cells(row,1).value = "Total"
              worksheet.cells(row,4).formula = "=sum(D#{top}:D#{row-1})"
              worksheet.cells(row,7).formula = "=sum(G#{top}:G#{row-1})"
              worksheet.rows(row).font.italic = true
            end
            row+=2
          end
        end # tally_by_tag

        begin
          windows_filename = tl_file_name.gsub(/\//, '\\')
          puts "windows file name: #{windows_filename}"
          workbook.saveas(windows_filename)
        rescue
          UI.messagebox("Error saving Excel File (might be open in excel)")
        end
        workbook.worksheets(1).activate

      when "C"  # csv mode
        tl_file << "\nTimbers:\n"
        row+=2
        if metric
          then tl_file << "Name,,W,D,L(m),L(cm)\n"
          else tl_file << "Name,,W,D,L(ft),L(in),BF\n"
        end
        row+=1
        nl.each do |ct|
          if (ct.count > 1)
            print("warning: duplicate named timber:"+ct.name+"\n")
            UI.messagebox("TF Rubies: warning: Duplicate Named Timber: " + ct.name + "\nDimensions will not be correct in list.")
          end
          ct.count.times do
            if metric
              tl_file << ct.name  << ",," << ct.w << "," << ct.d << "," << ct.ft << "," << ct.l << "\n"
            else
              #                        A B      C               D               E                F
              tl_file << ct.name  << ",," << ct.w << "," << ct.d << "," << ct.ft << "," << ct.l << "," << "=(C#{row}*D#{row}*E#{row})/12" << "\n"
            end
            row+=1
          end
        end
        #            A B C D E F
        tl_file << ",,,,,,=SUM(G#{row-nl.length}:G#{row-1})\n"
        row+=1
        tl_file << "\n" << " Scantlings:\n"
        row+=2

        if metric
          then tl_file << "Name,Qty,W,D,L(m),L(cm)\n"
          else tl_file << "Name,Qty,W,D,L(ft),L(in),BF\n"
        end
        row+=1
        ul.each do |ct|
          if metric
            tl_file << ct.name << "," << ct.count << "," << ct.w << "," << ct.d << "," << ct.ft << "," << ct.l << "\n"
          else
            tl_file << ct.name << "," << ct.count << "," << ct.w << "," << ct.d << "," << ct.ft << "," << ct.l << "," << "=(B#{row}*C#{row}*D#{row}*E#{row})/12" << "\n"
          end
          row+=1
        end
        tl_file << ",,,,,,=SUM(G#{row-ul.length}:G#{row-1})\n"
        row+=1
        tl_file << "\n" << "Tally:\n"
        row+=2

        if metric
          then tl_file << "W,D,Qty,L(m)\n"
          else tl_file << "W,D,Qty,L(ft),BF\n"
        end
        row+=1
        cl.each do |ct|
          if metric
            tl_file << ct.w << "," << ct.d << "," << ct.count << "," << ct.ft << "\n"
          else
            tl_file << ct.w << "," << ct.d << "," << ct.count << "," << ct.ft << "," << "=(A#{row}*B#{row}*C#{row}*D#{row})/12" << "\n"
          end
          row+=1
        end
        tl_file << ",,,,=SUM(E#{row-cl.length}:E#{row-1})\n"
        row+=1
        if tally_by_tag
          tl_file << "\n" << "Tally by Tag:\n"
          row+=1
          if metric
            then tl_file << "W,D,Qty,L(m),V(m3)\n"
            else tl_file << "W,D,Qty,L(ft),BF\n"
          end
          row+=1
          layer_lists.each_pair do |layer, list|
            tl_file << "\n" << "<Tag: #{layer.name}>\n"
            list.each do |ct|
              if metric
                tl_file << ct.w << "," << ct.d << "," << ct.count << "," << ct.ft/100 << "," << (ct.w * ct.d * ct.ft * ct.count)/10000 << "\n"
              else
                bf = (ct.count * ct.w * ct.d * ct.ft)/12.0
                bf = ((bf*10).round)/10.0
                tl_file << ct.w << "," << ct.d << "," << ct.count << "," << ct.ft << "," << bf.to_s << "\n"
              end
              row+=1
            end
          end
        end
        tl_file.close

      when "T" # Text file
        tl_file << "Timbers:\n"
        row+=1
        if metric
          then tl_file << "Name\t\tW\tD\tL(m)\tL(cm)\n"
          else tl_file << "Name\t\tW\tD\tL(ft)\tL(in)\tBF\n"
        end
        row+=1
        total_bf = 0.0
        nl.each do |ct|
          if (ct.count > 1)
            print("warning: duplicate named timber:"+ct.name+"\n")
            UI.messagebox("TF Rubies: warning: Duplicate Named Timber: " + ct.name + "\nDimensions will not be correct in list.")
          end
          ct.count.times do
            if metric
              tl_file << ct.name  << "\t\t" << ct.w << "\t" << ct.d << "\t" << ct.ft << "\t" << ct.l << "\n"
            else
              bf = (ct.w * ct.d * ct.ft)/12.0
              total_bf += bf
              bf = ((bf*100).round)/100.0
              tl_file << ct.name  << "\t\t" << ct.w << "\t" << ct.d << "\t" << ct.ft << "\t" << ct.l << "\t" << bf.to_s << "\n"
            end
            row+=1
          end
        end
        total_bf = ((total_bf*100).round)/100.0
        #            A B C D E F
        tl_file << "\t\t\t\t\t\t" << total_bf.to_s << "\n"
        row+=1
        tl_file << "\n" << "Un-named components:\n"
        row+=2

        if metric
          then tl_file << "Name\tQty\tW\tD\tL(m)\tL(cm)\n"
          else tl_file << "Name\tQty\tW\tD\tL(ft)\tL(in)\tBF\n"
        end
        row+=1
        total_bf = 0.0
        ul.each do |ct|
          if metric
            tl_file << ct.name << "\t" << ct.count << "\t" << ct.w << "\t" << ct.d << "\t" << ct.ft << "\t" << ct.l << "\n"
          else
            bf = (ct.count * ct.w * ct.d * ct.ft)/12.0
            total_bf += bf
            bf = ((bf*100).round)/100.0
            tl_file << ct.name << "\t" << ct.count << "\t" << ct.w << "\t" << ct.d << "\t" << ct.ft << "\t" << ct.l << "\t" << bf.to_s << "\n"
          end
          row+=1
        end
        total_bf = ((total_bf*100).round)/100.0
        tl_file << "\t\t\t\t\t\t" << total_bf.to_s << "\n"
        row+=1
        tl_file << "\n" << "Tally:\n"
        row+=2

        if metric
          then tl_file << "W\tD\tQty\tL(m)\n"
          else tl_file << "W\tD\tQty\tL(ft)\tBF\n"
        end
        row+=1
        total_bf = 0.0
        cl.each do |ct|
          if metric
            tl_file << ct.w << "\t" << ct.d << "\t" << ct.count << "\t" << ct.ft << "\n"
          else
            bf = (ct.count * ct.w * ct.d * ct.ft)/12.0
            total_bf += bf
            bf = ((bf*100).round)/100.0
            tl_file << ct.w << "\t" << ct.d << "\t" << ct.count << "\t" << ct.ft << "\t" << bf.to_s << "\n"
          end
          row+=1
        end
        total_bf = ((total_bf*100).round)/100.0
        tl_file << "\t\t\t\t" << total_bf.to_s << "\n"
        row+=1
        if tally_by_tag
          tl_file << "\n" << "Tally by Tag:\n"
          row+=1
          if metric
            then tl_file << "W\tD\tQty\tL(m)\tV(m3)\n"
            else tl_file << "W\tD\tQty\tL(ft)\tBF\n"
          end
          row+=1
          layer_lists.each_pair do |layer, list|
            tl_file << "\n" << "  == Tag #{layer.name} ==\n"
            list.each do |ct|
              if metric
                tl_file << ct.w << "\t" << ct.d << "\t" << ct.count << "\t" << ct.ft/100 << "\t" << (ct.w * ct.d * ct.ft * ct.count)/10000 << "\n"
              else
                bf = (ct.count * ct.w * ct.d * ct.ft)/12.0
                bf = ((bf*10).round)/10.0
                tl_file << ct.w << "\t" << ct.d << "\t" << ct.count << "\t" << ct.ft << "\t" << bf.to_s << "\n"
              end
              row+=1
            end
          end
        end

        tl_file.close
      end  # file format case
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
      next if timber.layer.name == COSMETIC_PEG_LAYER_NAME
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
end # module CB_TF
