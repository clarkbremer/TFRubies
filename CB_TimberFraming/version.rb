module CB_TF
  base_name = File.dirname(__FILE__).split("/").last
  const_set("#{base_name}_VERSION", "3.1.8")
  const_set("#{base_name}_DATE", "11/21/2025")
end
