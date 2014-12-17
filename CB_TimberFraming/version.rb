module CB_TF
  module PluginInfo
    base_name = File.dirname(__FILE__).split("/").last
    PluginInfo.const_set("#{base_name}_VERSION", "2.4.5")
    PluginInfo.const_set("#{base_name}_DATE", "12/16/2014")
  end
end