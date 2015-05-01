module CB_PluginInfo
  base_name = File.dirname(__FILE__).split("/").last
  const_set("#{base_name}_VERSION", "2.4.6")
  const_set("#{base_name}_DATE", "4/30/2015")
end
