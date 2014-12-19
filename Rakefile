base_name = File.dirname(__FILE__).split("/").last
require "./#{base_name}/version.rb"

task :default => "zipit"

version = CB_PluginInfo.const_get("#{base_name}_VERSION")

if RUBY_PLATFORM.include? "darwin"
  ZIP = "zip -r"
  MOVE = "mv"
else
  ZIP = "7za a -r -tzip"
  MOVE = "move /y"
end


desc "Create RBZ file"
task :zipit do
  puts "Creating RBZ file..."
  success = system "#{ZIP} #{base_name} #{base_name} #{base_name}.rb"
  if success
    system "#{MOVE} #{base_name}.zip #{base_name}_#{version}.rbz"
    puts "...RBZ file #{base_name}_#{version}.rbz created"
  else
    puts "...failed to create RBZ file."
  end
end
