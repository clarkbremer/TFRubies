module CB_TF
  base_name = File.dirname(__FILE__).split("/").last
  const_set("#{base_name}_VERSION", "3.1.10")
  const_set("#{base_name}_DATE", "2/12/2026")
end
