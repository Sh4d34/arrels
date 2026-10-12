@tool
class_name DistantMountain
extends Node3D
## Stylized far-away mountain (the Canigou), with its summit cross as a nod to the real one.
## Built on load as a low-poly heightfield; it ignores the scene fog and fakes aerial perspective instead.

@export_tool_button("Régénérer", "Reload") var regenerate_action: Callable = generate

@export_group("Shape")
@export var half_extent: float = 1320.0 ## Multiple of cell_size, so the summit is a vertex.
@export var cell_size: float = 55.0
@export var summit_height: float = 400.0
@export var summit_radius: float = 750.0
## Secondary peaks and ridge shoulders: x, z (local), relative height, radius.
@export var shoulders: Array[Vector4] = [
	Vector4(-380.0, 120.0, 0.72, 520.0),
	Vector4(420.0, 60.0, 0.6, 600.0),
	Vector4(820.0, -150.0, 0.42, 520.0),
	Vector4(-850.0, -80.0, 0.38, 500.0),
]
@export var noise: FastNoiseLite
@export var roughness: float = 0.12 ## Noise amplitude, relative to the summit height.

@export_group("Colors")
@export var snow_color: Color = Color(0.93, 0.95, 0.98)
@export var rock_color: Color = Color(0.5, 0.52, 0.56)
@export var forest_color: Color = Color(0.24, 0.36, 0.3)
@export var haze_color: Color = Color(0.68, 0.74, 0.82)
@export_range(0.0, 1.0) var haze_amount: float = 0.45
@export_range(0.0, 1.0) var snow_line: float = 0.8 ## Relative to the summit height.

@export_group("Cross")
@export var cross_height: float = 26.0 ## Oversized on purpose so it reads from afar.
@export var cross_color: Color = Color(0.12, 0.12, 0.13)

var _mesh_instance: MeshInstance3D
var _cross_parts: Array[MeshInstance3D] = []


func _ready() -> void:
	generate()


func height_at(x: float, z: float) -> float:
	var h := _peak(x, z, 0.0, 0.0, 1.0, summit_radius)
	for s in shoulders:
		h = maxf(h, _peak(x, z, s.x, s.y, s.z, s.w))
	var n: float = noise.get_noise_2d(x, z) if noise else 0.0
	return summit_height * (h + n * roughness * clampf(h * 3.0, 0.0, 1.0)) - 40.0


func generate() -> void:
	if not is_node_ready():
		return
	if _mesh_instance == null:
		_mesh_instance = MeshInstance3D.new()
		_mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(_mesh_instance, false, Node.INTERNAL_MODE_FRONT)
	var count := roundi(half_extent * 2.0 / cell_size)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for j in count:
		for i in count:
			var a := _vertex(i, j)
			var b := _vertex(i + 1, j)
			var c := _vertex(i, j + 1)
			var d := _vertex(i + 1, j + 1)
			_add_triangle(st, a, b, c)
			_add_triangle(st, b, d, c)
	_mesh_instance.mesh = st.commit()
	_mesh_instance.material_override = _make_material()
	_build_cross()


func _peak(x: float, z: float, cx: float, cz: float, relative_height: float, radius: float) -> float:
	var d := Vector2(x - cx, z - cz).length()
	return relative_height * pow(maxf(0.0, 1.0 - d / radius), 1.4)


func _vertex(i: int, j: int) -> Vector3:
	var x := -half_extent + i * cell_size
	var z := -half_extent + j * cell_size
	return Vector3(x, height_at(x, z), z)


func _add_triangle(st: SurfaceTool, v0: Vector3, v1: Vector3, v2: Vector3) -> void:
	var normal := (v0 - v2).cross(v0 - v1).normalized()
	st.set_normal(normal)
	st.set_color(_face_color((v0 + v1 + v2) / 3.0, normal))
	st.add_vertex(v0)
	st.add_vertex(v1)
	st.add_vertex(v2)


func _face_color(center: Vector3, normal: Vector3) -> Color:
	var t := center.y / summit_height
	var n: float = noise.get_noise_2d(center.z * 3.0, center.x * 3.0) if noise else 0.0
	var color := forest_color.lerp(rock_color, smoothstep(0.25, 0.5, t + n * 0.15))
	# Snow sticks to the gentler faces only, leaving dark rocky streaks.
	if t + n * 0.1 > snow_line - (normal.y - 0.6) * 0.3:
		color = snow_color
	return color.lerp(haze_color, haze_amount)


func _make_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.vertex_color_is_srgb = true
	material.roughness = 1.0
	material.disable_fog = true
	return material


func _build_cross() -> void:
	for part in _cross_parts:
		part.queue_free()
	_cross_parts.clear()
	var material := StandardMaterial3D.new()
	material.albedo_color = cross_color
	material.disable_fog = true
	var thickness := cross_height * 0.12
	var top := height_at(0.0, 0.0) - thickness
	var parts := [
		[Vector3(thickness, cross_height, thickness), Vector3(0.0, top + cross_height * 0.5, 0.0)],
		[Vector3(cross_height * 0.55, thickness, thickness), Vector3(0.0, top + cross_height * 0.72, 0.0)],
	]
	for part in parts:
		var box := BoxMesh.new()
		box.size = part[0]
		box.material = material
		var instance := MeshInstance3D.new()
		instance.mesh = box
		instance.position = part[1]
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(instance, false, Node.INTERNAL_MODE_FRONT)
		_cross_parts.append(instance)
