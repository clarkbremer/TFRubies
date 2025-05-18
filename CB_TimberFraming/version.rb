module CB_TF
  base_name = File.dirname(__FILE__).split("/").last
  const_set("#{base_name}_VERSION", "3.1.5")
  const_set("#{base_name}_DATE", "05/18/2025")
end
