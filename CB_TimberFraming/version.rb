module CB_PluginInfo
  base_name = File.dirname(__FILE__).split("/").last
  const_set("#{base_name}_VERSION", "2.4.5")
  const_set("#{base_name}_DATE", "12/16/2014")
end
