require './version.rb'
task :default => "zipit"
  
#base = "CB_TimberFraming"
base = File.dirname(__FILE__).split("/").last
puts "Base: #{base}"
version = CbPluginInfo.const_get("#{base}_VERSION")
puts "version: #{version}"

desc "Create RBZ file"
task :zipit do
  puts "Creating RBZ file"
  system "7za a -r -tzip #{base} #{base} #{base}.rb"
  system "move /y #{base}.zip #{base}_#{version}.rbz"
  puts "RBZ file created"
end