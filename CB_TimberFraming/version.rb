module CB_TF
  base_name = File.dirname(__FILE__).split("/").last
  const_set("#{base_name}_VERSION", "3.1.4")
  const_set("#{base_name}_DATE", "03/21/2025")
end
