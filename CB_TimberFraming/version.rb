module CB_TF
  base_name = File.dirname(__FILE__).split("/").last
  const_set("#{base_name}_VERSION", "2.5.0")
  const_set("#{base_name}_DATE", "09/07/2017")
end
