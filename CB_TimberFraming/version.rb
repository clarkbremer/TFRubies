module CB_TF
  base_name = File.dirname(__FILE__).split("/").last
  const_set("#{base_name}_VERSION", "3.0.16")
  const_set("#{base_name}_DATE", "04/16/2024")
end
