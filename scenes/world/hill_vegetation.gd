@tool
class_name HillVegetation
extends Node3D
## Woods and broom on the hills. Out-of-reach woods are simple low-poly trees drawn in one go
## (MultiMesh), so hundreds of them cost little; broom bushes grow on every slope.
## Clumped with noise to leave clearings, kept off the track, the river and the meadow.
## Rebuilt on load (in the editor too), like the terrain.

@export_tool_button("Régénérer", "Reload") var regenerate_action: Callable = generate

@export var terrain: Terrain
@export var seed: int = 5
@export var tree_count: int = 700
@export var broom_count: int = 380
@export var reach_margin: float = 1.0 ## Woods start this far beyond the walkable area.
@export var track_clearance: float = 5.0
@export var river_clearance: float = 3.0 ## Beyond the river walls.
@export var pine_height: float = 9.0 ## Above this ground height, pines take over.
@export_range(-1.0, 1.0) var clearing_threshold: float = -0.15 ## Higher leaves more clearings.

@export_group("Colors")
@export var trunk_color: Color = Color(0.42, 0.28, 0.19)
@export var pine_color: Color = Color(0.18, 0.34, 0.2)
@export var leaf_colors: PackedColorArray = PackedColorArray([Color(0.3, 0.47, 0.2), Color(0.36, 0.5, 0.22), Color(0.27, 0.42, 0.2)])
@export var broom_green: Color = Color(0.3, 0.42, 0.18)
@export var broom_yellow: Color = Color(0.98, 0.8, 0.15)

var _instances: Array[MultiMeshInstance3D] = []
var _clump_noise := FastNoiseLite.new()


func _ready() -> void:
	generate()


func generate() -> void:
	if not is_node_ready() or terrain == null:
		return
	for instance in _instances:
		instance.queue_free()
	_instances.clear()
	_clump_noise.seed = seed
	_clump_noise.frequency = 0.035
	var rng := RandomNumberGenerator.new()
	rng.seed = seed

	var pines: Array[Transform3D] = []
	var leafy: Array[Array] = [[], [], []]
	var brooms: Array[Transform3D] = []
	var half := terrain.size * 0.5 - 1.0
	var tries := 0
	while pines.size() + leafy[0].size() + leafy[1].size() + leafy[2].size() < tree_count and tries < tree_count * 12:
		tries += 1
		var p := Vector2(rng.randf_range(-half, half), rng.randf_range(-half, half))
		if _in_reach(p) or not _free(p) or _clump_noise.get_noise_2d(p.x, p.y) < clearing_threshold:
			continue
		var y := terrain.surface_height_at(p.x, p.y)
		var t := Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * rng.randf_range(0.8, 1.35)), Vector3(p.x, y - 0.2, p.y))
		if y > pine_height or rng.randf() < 0.25:
			pines.append(t)
		else:
			leafy[rng.randi() % 3].append(t)
	tries = 0
	while brooms.size() < broom_count and tries < broom_count * 12:
		tries += 1
		var p := Vector2(rng.randf_range(-half, half), rng.randf_range(-half, half))
		# Broom grows on all the slopes, reachable ones included: it is walked through like grass.
		if terrain.play_area.grow(-4.0).has_point(p) or not _free(p):
			continue
		var y := terrain.surface_height_at(p.x, p.y)
		brooms.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * rng.randf_range(0.6, 1.1)), Vector3(p.x, y - 0.05, p.y)))

	_add_multimesh(_pine_mesh(), pines, true)
	for i in leafy.size():
		_add_multimesh(_leafy_mesh(leaf_colors[i % leaf_colors.size()], i), leafy[i], true)
	_add_multimesh(_broom_mesh(), brooms, false)


## True inside the walkable area, where trees need real collisions (see world.tscn's HillWoods).
func _in_reach(p: Vector2) -> bool:
	return terrain.walk_bounds.grow(reach_margin).has_point(p)


func _free(p: Vector2) -> bool:
	if absf(p.x - terrain.river_center_x(p.y)) < terrain.blocker_half_width + river_clearance:
		return false
	return terrain.distance_to_track(p.x, p.y) > track_clearance


func _add_multimesh(mesh: Mesh, transforms: Array, shadows: bool) -> void:
	if transforms.is_empty():
		return
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = mesh
	multimesh.instance_count = transforms.size()
	for i in transforms.size():
		multimesh.set_instance_transform(i, transforms[i])
	var instance := MultiMeshInstance3D.new()
	instance.multimesh = multimesh
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.vertex_color_is_srgb = true
	material.roughness = 1.0
	instance.material_override = material
	add_child(instance, false, Node.INTERNAL_MODE_FRONT)
	_instances.append(instance)


# --- Low-poly meshes, merged from primitives with vertex colors.

func _pine_mesh() -> ArrayMesh:
	var st := _begin()
	_append(st, _cylinder(0.12, 0.2, 1.4, 6), Transform3D(Basis(), Vector3(0, 0.7, 0)), trunk_color)
	for layer in 3:
		var radius := 1.4 - layer * 0.35
		_append(st, _cylinder(0.0, radius, 2.0, 7), Transform3D(Basis(), Vector3(0, 2.0 + layer * 1.1, 0)), pine_color.lightened(layer * 0.04))
	return st.commit()


func _leafy_mesh(leaf: Color, variant: int) -> ArrayMesh:
	var st := _begin()
	_append(st, _cylinder(0.12, 0.22, 2.2, 6), Transform3D(Basis(), Vector3(0, 1.1, 0)), trunk_color)
	var blobs := [[Vector3(0, 3.0, 0), 1.6], [Vector3(0.9, 2.6, 0.3), 1.1], [Vector3(-0.7, 2.8, -0.4), 1.15]]
	for i in blobs.size():
		if variant == 1 and i == 2:
			continue
		var blob: Array = blobs[i]
		_append(st, _sphere(blob[1]), Transform3D(Basis(), blob[0]), leaf.lightened(i * 0.05))
	return st.commit()


func _broom_mesh() -> ArrayMesh:
	var st := _begin()
	_append(st, _sphere(0.55, 0.7), Transform3D(Basis(), Vector3(0, 0.3, 0)), broom_green)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in 14:
		var angle := rng.randf() * TAU
		var radius := rng.randf_range(0.15, 0.5)
		var flower := Vector3(cos(angle) * radius, rng.randf_range(0.45, 0.62), sin(angle) * radius)
		_append(st, _sphere(0.08), Transform3D(Basis(), flower), broom_yellow)
	return st.commit()


func _begin() -> SurfaceTool:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	return st


func _cylinder(top: float, bottom: float, height: float, sides: int) -> Array:
	var mesh := CylinderMesh.new()
	mesh.top_radius = top
	mesh.bottom_radius = bottom
	mesh.height = height
	mesh.radial_segments = sides
	mesh.rings = 1
	return mesh.get_mesh_arrays()


func _sphere(radius: float, squash: float = 1.0) -> Array:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0 * squash
	mesh.radial_segments = 7
	mesh.rings = 4
	return mesh.get_mesh_arrays()


## Appends a primitive's triangles, transformed and colored, to the surface being built.
func _append(st: SurfaceTool, arrays: Array, transform: Transform3D, color: Color) -> void:
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	st.set_color(color)
	for index in indices:
		st.set_normal((transform.basis * normals[index]).normalized())
		st.add_vertex(transform * vertices[index])
