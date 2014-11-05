module CbPluginInfo
  base_name = File.dirname(__FILE__).split("/").last
  CbPluginInfo.const_set("#{base_name}_VERSION", "2.4.4")
  CbPluginInfo.const_set("#{base_name}_DATE", "11/04/2014")
end