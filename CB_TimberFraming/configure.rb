# load "G:/My Drive/TF/Sketchup/Rubies/CB_TimberFraming/CB_TimberFraming/configure.rb"


module CB_TF
  def CB_TF.configure

    dialog = UI::HtmlDialog.new(
      {
        :dialog_title => "Timber Framing Extensions Configuration",
        :scrollable => true,
        :resizable => false,
        :width => 700,
        :height => 600,
        :left => 200,
        :top => 200,
        :style => UI::HtmlDialog::STYLE_DIALOG
      })

    config = {
      company_name: Sketchup.read_default("TF", "company_name", ""),
      qty: Sketchup.read_default("TF", "qty", true),
      side_spacing: Sketchup.read_default("TF", "side_spacing", "30"),
      dir_labels: Sketchup.read_default("TF", "dir_labels", true),
      roundup: Sketchup.read_default("TF", "roundup", true),
      list_file_format: Sketchup.read_default("TF", "list_file_format", "C"),
      list_by_tag: Sketchup.read_default("TF", "list_by_tag", false),
      metric: Sketchup.read_default("TF", "metric", false),
      roll: Sketchup.read_default("TF", "roll", false),
      min_extra_timber_length: Sketchup.read_default("TF", "min_extra_timber_length", "24")      
    }
puts "config: #{config}"

    html = %Q[
      <!DOCTYPE html>
      <html>
        <head>
          <title>Timber Framing Extensions Configuration</title>
          <style>
            h1 {
              font-family: arial, sans-serif;
              text-align: center;
            }
            p.center {
              text-align: center;
            } 
            button.pad {
              margin-left: 16px;
            }
            div.pad_left {
              margin-left: 16px;
            }           
            div.settings {
              font-family: arial, sans-serif;
              margin-left: 16px;
              display:grid;
              grid-template-columns: max-content max-content;
              grid-gap:5px;
            }
            div.settings label       { text-align:right; }
            </style>
        </head>
        <script>
          var data = JSON.parse('#{config.to_json}');
          document.onreadystatechange = function () {
            if (document.readyState === 'complete') {
              var ci = document.getElementById('company_name');
              ci.value = data.company_name;
              
              ci = document.getElementById('side_spacing');
              ci.value = data.side_spacing;

              if (data.qty == true){
                ci = document.getElementById('qtyY');
                ci.checked = true;
              } else {
                ci = document.getElementById('qtyN');
                ci.checked = true;
              }

              if (data.dir_labels == true){
                ci = document.getElementById('dir_labelsY');
                ci.checked = true;
              } else {
                ci = document.getElementById('dir_labelsN');
                ci.checked = true;
              }

              if (data.roundup == true){
                ci = document.getElementById('roundupY');
                ci.checked = true;
              } else {
                ci = document.getElementById('roundupN');
                ci.checked = true;
              }

              if (data.list_by_tag == true){
                ci = document.getElementById('list_by_tagY');
                ci.checked = true;
              } else {
                ci = document.getElementById('list_by_tagN');
                ci.checked = true;
              }
              
              if (data.metric == true){
                ci = document.getElementById('metric');
                ci.checked = true;
              } else {
                ci = document.getElementById('english');
                ci.checked = true;
              }
              
              if (data.list_file_format == "C"){
                ci = document.getElementById('lff_csv');
                ci.checked = true;
              } else if (data.list_file_format == "T") {
                ci = document.getElementById('lff_txt');
                ci.checked = true;
              } else {
                ci = document.getElementById('lff_xls');
                ci.checked = true;
              }

              if (data.roll == true){
                ci = document.getElementById('roll');
                ci.checked = true;
              } else {
                ci = document.getElementById('unwrap');
                ci.checked = true;
              }      

              ci = document.getElementById('min_extra_timber_length');
              ci.value = data.min_extra_timber_length;
            }
          }

          function save_data() {
            var ci = document.getElementById('company_name');
            data.company_name = ci.value;

            ci = document.getElementById('side_spacing');
            data.side_spacing = ci.value;

            ci = document.getElementById('qtyY');
            data.qty = ci.checked;

            ci = document.getElementById('dir_labelsY');
            data.dir_labels = ci.checked;

            ci = document.getElementById('roundupY');
            data.roundup = ci.checked;

            ci = document.getElementById('list_by_tagY');
            data.list_by_tag = ci.checked;            
            
            ci = document.getElementById('metric');
            data.metric = ci.checked;            
            
            ci = document.getElementById('lff_csv');
            if (ci.checked){
              data.list_file_format = "C";
            };
            ci = document.getElementById('lff_txt');
            if (ci.checked){
              data.list_file_format = "T";
            };
            ci = document.getElementById('lff_xls');
            if (ci.checked){
              data.list_file_format = "X";
            };

            ci = document.getElementById('roll');
            data.roll = ci.checked;            

            ci = document.getElementById('min_extra_timber_length');
            data.min_extra_timber_length = ci.value;

            sketchup.tf_save_config(data);
          }
        </script>


        <body>
          <h1>TF Rubies Config</h1>
          
          <div class="settings">
            <label>Company Name:</label>
            <input id='company_name'; type="text" />

            <label>Side Spacing:</label>
            <input id='side_spacing'; type="number" />            

            <label>Show QTY and Size on Shops?</label>
            <div>
              <input id="qtyY"; type="radio" name="qty"/>
              <label for="qtyY">Yes</label><br>
              <input id="qtyN"; type="radio" name="qty"/>
              <label for="qtyN">No</label>
            </div>

            <label>Show NSEWTB Labels on Shops?</label>
            <div>
              <input id="dir_labelsY"; type="radio" name="dir_labels"/>
              <label for="dir_labelsY">Yes</label><br>
              <input id="dir_labelsN"; type="radio" name="dir_labels"/>
              <label for="dir_labelsN">No</label>
            </div>

            <label>Round Up Dimensions on Timber list?</label>
            <div>
              <input id="roundupY"; type="radio" name="roundup"/>
              <label for="roundupY">Yes</label><br>
              <input id="roundupN"; type="radio" name="roundup"/>
              <label for="roundupN">No</label>
            </div>
 
            <label>Timber List Tally by Tag?</label>
            <div>
              <input id="list_by_tagY"; type="radio" name="list_by_tag"/>
              <label for="list_by_tagY">Yes</label><br>
              <input id="list_by_tagN"; type="radio" name="list_by_tag"/>
              <label for="list_by_tagN">No</label>
            </div>
 
            <label>English or Metric?</label>
            <div>
              <input id="english"; type="radio" name="metric"/>
              <label for="english">English</label>
              <input id="metric"; type="radio" name="metric"/>
              <label for="metric">Metric</label><br>
            </div>
            
            <label>Timber List File Format:</label>
            <div>
              <input id="lff_csv"; type="radio" name="lff"/>
              <label for="lff_csv">CSV</label><br>
              <input id="lff_txt"; type="radio" name="lff"/>
              <label for="lff_txt">Text</label>
              <input id="lff_xls"; type="radio" name="lff"/>
              <label for="lff_xls">Excel</label>
            </div>

            <label>Unwrap or Roll Shop Drawings?</label>
            <div>
              <input id="unwrap"; type="radio" name="roll"/>
              <label for="unwrap">Unwrap</label>
              <input id="roll"; type="radio" name="roll"/>
              <label for="roll">Roll</label><br>
            </div>
                        
            <label>Minimum Extra Timber Length:</label>
            <input id='min_extra_timber_length'; type="number" />               
          </div>

          <p class="center"><button onclick='save_data()'>Save</button><button class="pad"; onclick='sketchup.tf_cancel()'>Cancel</button></p>
        </body>
      </html>
    ]

    dialog.set_html(html)
    dialog.add_action_callback("tf_save_config") { |action_context, data|
      puts "data: #{data}"
      dialog.close()

      Sketchup.write_default("TF", "company_name", data["company_name"])      
      data["qty"] ? Sketchup.write_default("TF", "qty", 1) : Sketchup.write_default("TF", "qty", 0)
      data["dir_labels"] ? Sketchup.write_default("TF", "dir_labels", 1) : Sketchup.write_default("TF", "dir_labels", 0)
      data["roundup"] ? Sketchup.write_default("TF", "roundup", 1) : Sketchup.write_default("TF", "roundup", 0)
      Sketchup.write_default("TF", "list_file_format", data["list_file_format"])
      data["list_by_tag"] ? Sketchup.write_default("TF", "list_by_tag", 1) : Sketchup.write_default("TF", "list_by_tag", 0)
      data["metric"] ? Sketchup.write_default("TF", "metric", 1) : Sketchup.write_default("TF", "metric", 0)
      data["roll"] ? Sketchup.write_default("TF", "roll", 1) : Sketchup.write_default("TF", "roll", 0)
      Sketchup.write_default("TF", "side_spacing", data["side_spacing"].to_i )
      Sketchup.write_default("TF", "min_extra_timber_length", data["min_extra_timber_length"].to_i )
    }
    dialog.add_action_callback("tf_cancel") { |action_context|
      puts "User canceled"
      dialog.close()
    }
    dialog.show_modal

  end
end