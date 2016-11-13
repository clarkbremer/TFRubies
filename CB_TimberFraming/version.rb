module CB_TF
  base_name = File.dirname(__FILE__).split("/").last
  const_set("#{base_name}_VERSION", "2.4.7")
  const_set("#{base_name}_DATE", "11/13/2016")
end
