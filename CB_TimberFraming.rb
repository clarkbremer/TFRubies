     # Register and Load TF Extensions
     require 'sketchup.rb'
     require 'extensions.rb'

     tf_extensions = SketchupExtension.new "TF Extensions", "CB_TimberFraming/tf.rb"
     tf_extensions.version = '2.4.3'
     tf_extensions.description = "Extensions for Timber Framers."
     tf_extensions.copyright = "Copyright (c) 2014, Clark Bremer"
     tf_extensions.creator = "Clark Bremer"
     Sketchup.register_extension tf_extensions, true