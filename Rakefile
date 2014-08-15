base_name = File.dirname(__FILE__).split("/").last
require "./#{base_name}/version.rb"

task :default => "zipit"
  
puts "Base Name: #{base_name}"
version = CbPluginInfo.const_get("#{base_name}_VERSION")
puts "version: #{version}"

desc "Create RBZ file"
task :zipit do
  puts "Creating RBZ file"
  system "7za a -r -tzip #{base_name} #{base_name} #{base_name}.rb"
  system "move /y #{base_name}.zip #{base_name}_#{version}.rbz"
  puts "RBZ file created"
end