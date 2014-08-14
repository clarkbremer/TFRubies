module CbPluginInfo
  base = File.dirname(__FILE__).split("/").last
  CbPluginInfo.const_set("#{base}_VERSION", "2.4.4")
  CbPluginInfo.const_set("#{base}_DATE", "8/13/2014")
end