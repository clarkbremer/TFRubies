module CB_TF
  base_name = File.dirname(__FILE__).split("/").last
  const_set("#{base_name}_VERSION", "3.1.7")
  const_set("#{base_name}_DATE", "08/01/2025")
end
