module CB_TF
  base_name = File.dirname(__FILE__).split("/").last
  const_set("#{base_name}_VERSION", "3.1.3")
  const_set("#{base_name}_DATE", "09/05/2024")
end
