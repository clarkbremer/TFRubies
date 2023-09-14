module CB_TF
  base_name = File.dirname(__FILE__).split("/").last
  const_set("#{base_name}_VERSION", "3.0.1")
  const_set("#{base_name}_DATE", "09/14/2023")
end
