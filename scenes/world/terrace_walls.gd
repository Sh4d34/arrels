@tool
class_name TerraceWalls
extends StaticBody3D
## Dry-stone walls holding up the terraces cut by the Terrain: irregular stones stacked along each
## step, merged into one mesh, with one collision box per wall. Rebuilt on load, like the terrain.

@export_tool_button("Régénérer", "Reload") var regenerate_action: Callable = generate

@export var terrain: Terrain
@export var seed: int = 12
@export var thickness: float = 0.6
@export var parapet: float = 0.25 ## Height of the wall above the upper terrace.

var _mesh_instance: MeshInstance3D
var _shapes: Array[CollisionShape3D] = []


func _ready() -> void:
	generate()


func generate() -> void:
	if not is_node_ready() or terrain == null or terrain.terrace_count < 2:
		return
	if _mesh_instance == null:
		_mesh_instance = MeshInstance3D.new()
		add_child(_mesh_instance, false, Node.INTERNAL_MODE_FRONT)
	for shape in _shapes:
		shape.queue_free()
	_shapes.clear()

	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rect := terrain.terrace_rect
	var heights := terrain.terrace_heights()
	var depth := rect.size.y / terrain.terrace_count
	for k in terrain.terrace_count - 1:
		# Between band k (higher) and band k + 1 (lower), facing the meadow.
		var z := rect.position.y + (k + 1) * depth - thickness * 0.5 - 0.15
		var bottom: float = heights[k + 1] - 0.3
		var top: float = heights[k] + parapet
		_build_wall(st, rng, rect.position.x, rect.end.x, z, bottom, top)
		_add_collision(rect.position.x, rect.end.x, z, bottom, top)
	_mesh_instance.mesh = st.commit()
	_mesh_instance.material_override = DryStone.material()


func _build_wall(st: SurfaceTool, rng: RandomNumberGenerator, x0: float, x1: float, z: float, bottom: float, top: float) -> void:
	DryStone.wall(st, rng, Vector3(x0, bottom, z), Vector3(x1, bottom, z), top - bottom, top - bottom, thickness)


func _add_collision(x0: float, x1: float, z: float, bottom: float, top: float) -> void:
	var box := BoxShape3D.new()
	box.size = Vector3(x1 - x0, top - bottom, thickness)
	var shape := CollisionShape3D.new()
	shape.shape = box
	shape.position = Vector3((x0 + x1) * 0.5, (bottom + top) * 0.5, z)
	add_child(shape, false, Node.INTERNAL_MODE_BACK)
	_shapes.append(shape)
