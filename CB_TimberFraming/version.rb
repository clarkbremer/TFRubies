module CB_TF
  base_name = File.dirname(__FILE__).split("/").last
  const_set("#{base_name}_VERSION", "2.6.1")
  const_set("#{base_name}_DATE", "11/21/2019")
end
