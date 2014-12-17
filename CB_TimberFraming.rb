# Register and Load TF Extensions
require 'sketchup.rb'
require 'extensions.rb'
base_name = "CB_TimberFraming"
require "#{base_name}/version.rb"
tf_extensions = SketchupExtension.new "TF Extensions", "#{base_name}/tf.rb"
tf_extensions.version = CB_TF::PluginInfo.const_get("#{base_name}_VERSION")
tf_extensions.description = "Extensions for Timber Framers."
tf_extensions.copyright = "Copyright (c) 2014, Clark Bremer"
tf_extensions.creator = "Clark Bremer"
Sketchup.register_extension tf_extensions, true