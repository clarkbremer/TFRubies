mm = Sketchup.active_model
g1 = mm.entities.add_group
pts = [
  [0, 0, 0],
  [10, 0, 0],
  [10, 12, 0],
  [0, 12, 0]
]
face1 = g1.entities.add_face(pts)
face1.pushpull(-8)
c1 = g1.to_component

c2 = mm.entities.add_instance(c1.definition, Geom::Transformation.new([20,30,10]))

v1 = c1.definition.entities.grep(Sketchup::Face).first.vertices.first
puts "vertex 1: #{v1.inspect}: #{v1.position}"
path1 = Sketchup::InstancePath.new([c1, v1])
point1 = v1.position
point1.transform! c1.transformation
puts "point1: #{point1}"

v2 = c2.definition.entities.grep(Sketchup::Face).first.vertices.first
puts "vertex 2: #{v2.inspect}: #{v2.position}"
path2 = Sketchup::InstancePath.new([c2, v2])
point2 = v2.position
point2.transform! c2.transformation
puts "point2: #{point2}"

mm.active_entities.add_dimension_linear([path1, point1], [path2, point2], [0, 0, -30])
