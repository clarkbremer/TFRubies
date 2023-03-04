module CB_TF
  base_name = File.dirname(__FILE__).split("/").last
  const_set("#{base_name}_VERSION", "2.7.0")
  const_set("#{base_name}_DATE", "03/04/2023")
end
