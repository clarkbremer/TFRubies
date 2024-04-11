# load "G:/My Drive/TF/Sketchup/Rubies/CB_TimberFraming/CB_TimberFraming/configure.rb"


module CB_TF
  def CB_TF.configure
    dialog = UI::HtmlDialog.new(
      {
        :dialog_title => "Timber Framing Extensions Configuration",
        :scrollable => true,
        :resizable => false,
        :width => 700,
        :height => 700,
        :left => 200,
        :top => 200,
        :style => UI::HtmlDialog::STYLE_DIALOG
      })

    path = File.dirname(__FILE__)

    replacements = {  
      config_json: {
        company_name: Sketchup.read_default("TF", "company_name", ""),
        side_spacing: Sketchup.read_default("TF", "side_spacing", "30"),
        dir_labels: Sketchup.read_default("TF", "dir_labels", true),
        roundup: Sketchup.read_default("TF", "roundup", true),
        list_file_format: Sketchup.read_default("TF", "list_file_format", "C"),
        list_by_tag: Sketchup.read_default("TF", "list_by_tag", false),
        metric: Sketchup.read_default("TF", "metric", false),
        roll: Sketchup.read_default("TF", "roll", false),
        min_extra_timber_length: Sketchup.read_default("TF", "min_extra_timber_length", "24"),
        qty: Sketchup.read_default("TF", "qty", true),
        sq_x_pos: Sketchup.read_default("TF", "sq_x_pos", "1.5").to_f,
        sq_y_pos: Sketchup.read_default("TF", "sq_y_pos", "1.5").to_f,
        sq_font_size: Sketchup.read_default("TF", "sq_font_size", "16"),
        sq_rotate: Sketchup.read_default("TF", "sq_rotate", "0").to_i,
        sq_bold: Sketchup.read_default("TF", "sq_bold", true),
      }.to_json,
      javascript: File.read(File.join(path, "configure.js")),
      stylesheet: File.read(File.join(path, "configure.css"))
    }

    html = File.read(File.join(path, "configure.html"))
    dialog.set_html(html % replacements)
    dialog.add_action_callback("tf_save_config") { |action_context, data|
      puts "saving config data: \n#{data}"
      dialog.close()

      Sketchup.write_default("TF", "company_name", data["company_name"])      
      data["dir_labels"] ? Sketchup.write_default("TF", "dir_labels", 1) : Sketchup.write_default("TF", "dir_labels", 0)
      data["roundup"] ? Sketchup.write_default("TF", "roundup", 1) : Sketchup.write_default("TF", "roundup", 0)
      Sketchup.write_default("TF", "list_file_format", data["list_file_format"])
      data["list_by_tag"] ? Sketchup.write_default("TF", "list_by_tag", 1) : Sketchup.write_default("TF", "list_by_tag", 0)
      data["metric"] ? Sketchup.write_default("TF", "metric", 1) : Sketchup.write_default("TF", "metric", 0)
      data["roll"] ? Sketchup.write_default("TF", "roll", 1) : Sketchup.write_default("TF", "roll", 0)
      Sketchup.write_default("TF", "side_spacing", data["side_spacing"].to_i )
      Sketchup.write_default("TF", "min_extra_timber_length", data["min_extra_timber_length"].to_i )
      data["qty"] ? Sketchup.write_default("TF", "qty", 1) : Sketchup.write_default("TF", "qty", 0)
      Sketchup.write_default("TF", "sq_x_pos", data["sq_x_pos"])
      Sketchup.write_default("TF", "sq_y_pos", data["sq_y_pos"])
      Sketchup.write_default("TF", "sq_font_size", data["sq_font_size"])
      Sketchup.write_default("TF", "sq_rotate", data["sq_rotate"])
      Sketchup.write_default("TF", "sq_bold", data["sq_bold"])
    }
    dialog.add_action_callback("tf_cancel") { |action_context|
      puts "User canceled"
      dialog.close()
    }
    dialog.show_modal

  end
end