@tool
class_name Terrain
extends StaticBody3D
## Procedural low-poly terrain: a nearly flat central meadow, rolling ground around it,
## hills along the borders, a meandering river carved along the Z axis and a dirt track.
## Rebuilt on load (in the editor too), so the mesh is never saved in the scene file.

@export_tool_button("Régénérer", "Reload") var regenerate_action: Callable = generate

@export_group("Grid")
@export var size: float = 140.0
@export var cell_size: float = 2.0
@export var material: Material
@export var noise: FastNoiseLite

@export_group("Relief")
@export var undulation_height: float = 3.0
@export var meadow: Rect2 = Rect2(-18.0, -22.0, 27.0, 44.0) ## Kept almost flat for building.
@export var meadow_falloff: float = 8.0
@export_range(0.0, 1.0) var meadow_undulation: float = 0.1
@export var play_area: Rect2 = Rect2(-32.0, -32.0, 64.0, 64.0) ## Hills rise outside it.
@export var hills_height: float = 14.0
@export var hills_ramp: float = 24.0

@export_group("River")
@export var river_x: float = 17.0
@export var river_half_width: float = 3.0
@export var river_bank_width: float = 2.5
@export var river_bed_height: float = -1.2
@export var meander_amplitude: float = 2.5
@export var meander_frequency: float = 0.07
@export var blocker_segment_length: float = 4.0
@export var blocker_half_width: float = 4.6 ## Covers the water up to its shoreline.
## Gaps in the river walls for bridges: x = z of the crossing on the river centerline, y = half width.
@export var river_crossings: PackedVector2Array = PackedVector2Array()

@export_group("World bounds")
@export var walk_bounds: Rect2 = Rect2(-45.0, -45.0, 90.0, 90.0) ## Invisible walls keep the player inside.
@export var wall_height: float = 80.0

@export_group("Track")
@export var track_points: PackedVector2Array = PackedVector2Array() ## Control points on the XZ plane, smoothed into a curve.
@export var track_width: float = 2.6
@export var track_color: Color = Color(0.46, 0.37, 0.25)
@export var track_lift: float = 0.06 ## Height above the ground, to avoid flickering.
@export var track_sample_spacing: float = 1.0

@export_group("Colors")
@export var grass_color: Color = Color(0.34, 0.48, 0.22)
@export var dry_grass_color: Color = Color(0.46, 0.5, 0.26)
@export var earth_color: Color = Color(0.45, 0.37, 0.26)
@export var gravel_color: Color = Color(0.5, 0.45, 0.36)
@export_range(0.0, 1.0) var steep_threshold: float = 0.82

## Render layers 1 and 2: layer 2 marks the ground, for decals such as the build grid.
const GROUND_RENDER_LAYERS := 0b11

var _mesh_instance: MeshInstance3D
var _track_instance: MeshInstance3D
var _ground_shape: CollisionShape3D
var _river_blockers: Array[CollisionShape3D] = []
var _bound_walls: Array[CollisionShape3D] = []
var _heights := PackedFloat32Array()
var _count: int = 0


func _ready() -> void:
	generate()


func river_center_x(z: float) -> float:
	return river_x + meander_amplitude * sin(z * meander_frequency)


func height_at(x: float, z: float) -> float:
	var n: float = noise.get_noise_2d(x, z) if noise else 0.0
	var h := n * undulation_height
	var meadow_t := 1.0 - smoothstep(0.0, meadow_falloff, _distance_to_rect(x, z, meadow))
	h = lerpf(h, h * meadow_undulation, meadow_t)
	var hills_t := smoothstep(0.0, hills_ramp, _distance_to_rect(x, z, play_area))
	h += hills_t * hills_height * (0.75 + 0.5 * n)
	# Clamp to stay above the water everywhere except in the river channel.
	var bank_t := smoothstep(river_half_width, river_half_width + river_bank_width, absf(x - river_center_x(z)))
	return lerpf(river_bed_height, maxf(h, 0.05), bank_t)


## Height of the generated (triangulated) surface, matching exactly what is rendered.
func surface_height_at(x: float, z: float) -> float:
	if _count == 0:
		return height_at(x, z)
	var half := size * 0.5
	var fx := (x + half) / cell_size
	var fz := (z + half) / cell_size
	var i := clampi(floori(fx), 0, _count - 1)
	var j := clampi(floori(fz), 0, _count - 1)
	var u := clampf(fx - i, 0.0, 1.0)
	var v := clampf(fz - j, 0.0, 1.0)
	var ha := _heights[j * (_count + 1) + i]
	var hb := _heights[j * (_count + 1) + i + 1]
	var hc := _heights[(j + 1) * (_count + 1) + i]
	var hd := _heights[(j + 1) * (_count + 1) + i + 1]
	# Same diagonals as in generate().
	if (i + j) % 2 == 0:
		if u + v <= 1.0:
			return ha + (hb - ha) * u + (hc - ha) * v
		return hd + (hc - hd) * (1.0 - u) + (hb - hd) * (1.0 - v)
	if u >= v:
		return ha + (hb - ha) * u + (hd - hb) * v
	return ha + (hd - hc) * u + (hc - ha) * v


## Track centerline sampled every track_sample_spacing meters (Catmull-Rom through track_points).
func track_samples() -> PackedVector2Array:
	var samples := PackedVector2Array()
	var n := track_points.size()
	if n < 2:
		return samples
	for k in n - 1:
		var p0 := track_points[maxi(k - 1, 0)]
		var p1 := track_points[k]
		var p2 := track_points[k + 1]
		var p3 := track_points[mini(k + 2, n - 1)]
		var steps := maxi(ceili(p1.distance_to(p2) / track_sample_spacing), 1)
		for s in steps:
			var t := float(s) / steps
			var t2 := t * t
			var t3 := t2 * t
			samples.append(0.5 * ((2.0 * p1) + (p2 - p0) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 + (3.0 * p1 - p0 - 3.0 * p2 + p3) * t3))
	samples.append(track_points[n - 1])
	return samples


func generate() -> void:
	if not is_node_ready():
		return
	_ensure_nodes()
	var count := roundi(size / cell_size)
	var half := size * 0.5
	var heights := PackedFloat32Array()
	heights.resize((count + 1) * (count + 1))
	for j in count + 1:
		for i in count + 1:
			heights[j * (count + 1) + i] = height_at(-half + i * cell_size, -half + j * cell_size)
	_heights = heights
	_count = count

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for j in count:
		for i in count:
			var a := _grid_vertex(heights, count, i, j)
			var b := _grid_vertex(heights, count, i + 1, j)
			var c := _grid_vertex(heights, count, i, j + 1)
			var d := _grid_vertex(heights, count, i + 1, j + 1)
			# Alternate diagonals for a less regular low-poly look.
			if (i + j) % 2 == 0:
				_add_triangle(st, a, b, c)
				_add_triangle(st, b, d, c)
			else:
				_add_triangle(st, a, b, d)
				_add_triangle(st, a, d, c)
	var mesh := st.commit()
	_mesh_instance.mesh = mesh
	_mesh_instance.material_override = material
	_ground_shape.shape = mesh.create_trimesh_shape()
	_build_river_blockers()
	_build_bound_walls()
	_build_track()


func _build_track() -> void:
	# A dirt ribbon laid on the surface, a few vertices across so it hugs the ground.
	_track_instance.mesh = null
	var samples := track_samples()
	if samples.size() < 2:
		return
	const ACROSS := 4
	var rows: Array[PackedVector3Array] = []
	for k in samples.size():
		var dir := (samples[mini(k + 1, samples.size() - 1)] - samples[maxi(k - 1, 0)]).normalized()
		var side := Vector2(-dir.y, dir.x) * track_width
		var row := PackedVector3Array()
		for a in ACROSS + 1:
			var p := samples[k] + side * (float(a) / ACROSS - 0.5)
			row.append(Vector3(p.x, surface_height_at(p.x, p.y) + track_lift, p.y))
		rows.append(row)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_color(track_color)
	for k in rows.size() - 1:
		for a in ACROSS:
			_add_track_triangle(st, rows[k][a], rows[k][a + 1], rows[k + 1][a])
			_add_track_triangle(st, rows[k][a + 1], rows[k + 1][a + 1], rows[k + 1][a])
	_track_instance.mesh = st.commit()
	_track_instance.material_override = material


func _add_track_triangle(st: SurfaceTool, v0: Vector3, v1: Vector3, v2: Vector3) -> void:
	var normal := (v0 - v2).cross(v0 - v1).normalized()
	if normal.y < 0.0:
		# Winding depends on the track direction: flip to keep the face pointing up.
		var tmp := v1
		v1 = v2
		v2 = tmp
		normal = -normal
	st.set_normal(normal)
	st.add_vertex(v0)
	st.add_vertex(v1)
	st.add_vertex(v2)


func _ensure_nodes() -> void:
	# Internal children are not shown in the scene tree and not saved.
	if _mesh_instance == null:
		_mesh_instance = MeshInstance3D.new()
		_mesh_instance.layers = GROUND_RENDER_LAYERS
		add_child(_mesh_instance, false, Node.INTERNAL_MODE_FRONT)
	if _track_instance == null:
		_track_instance = MeshInstance3D.new()
		_track_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_track_instance.layers = GROUND_RENDER_LAYERS
		add_child(_track_instance, false, Node.INTERNAL_MODE_FRONT)
	if _ground_shape == null:
		_ground_shape = CollisionShape3D.new()
		add_child(_ground_shape, false, Node.INTERNAL_MODE_FRONT)


func _grid_vertex(heights: PackedFloat32Array, count: int, i: int, j: int) -> Vector3:
	var half := size * 0.5
	return Vector3(-half + i * cell_size, heights[j * (count + 1) + i], -half + j * cell_size)


func _add_triangle(st: SurfaceTool, v0: Vector3, v1: Vector3, v2: Vector3) -> void:
	# Godot front faces are clockwise; this gives an upward normal for our winding.
	var normal := (v0 - v2).cross(v0 - v1).normalized()
	st.set_normal(normal)
	st.set_color(_face_color((v0 + v1 + v2) / 3.0, normal))
	st.add_vertex(v0)
	st.add_vertex(v1)
	st.add_vertex(v2)


func _face_color(center: Vector3, normal: Vector3) -> Color:
	if center.y < -0.3:
		return gravel_color
	var variation: float = noise.get_noise_2d(center.z * 2.3 + 500.0, center.x * 2.3) if noise else 0.0
	var grass := grass_color.lerp(dry_grass_color, clampf(0.5 + variation, 0.0, 1.0))
	var steep_t := 1.0 - smoothstep(steep_threshold - 0.15, steep_threshold, normal.y)
	return grass.lerp(earth_color, steep_t)


func _build_river_blockers() -> void:
	# Invisible walls following the meanders, covering the whole water surface,
	# with gaps where a bridge crosses.
	for blocker in _river_blockers:
		blocker.queue_free()
	_river_blockers.clear()
	var half := size * 0.5
	for interval in _blocked_intervals(-half, half):
		var z := interval.x
		while z < interval.y - 0.01:
			var z_end := minf(z + blocker_segment_length, interval.y)
			_add_river_blocker(z, z_end)
			z = z_end


func _blocked_intervals(z_min: float, z_max: float) -> Array[Vector2]:
	var intervals: Array[Vector2] = [Vector2(z_min, z_max)]
	for crossing in river_crossings:
		var gap_start := crossing.x - crossing.y
		var gap_end := crossing.x + crossing.y
		var split: Array[Vector2] = []
		for interval in intervals:
			if gap_end <= interval.x or gap_start >= interval.y:
				split.append(interval)
				continue
			if gap_start > interval.x:
				split.append(Vector2(interval.x, gap_start))
			if gap_end < interval.y:
				split.append(Vector2(gap_end, interval.y))
		intervals = split
	return intervals


func _add_river_blocker(z0: float, z1: float) -> void:
	var x0 := river_center_x(z0)
	var x1 := river_center_x(z1)
	var box := BoxShape3D.new()
	box.size = Vector3(blocker_half_width * 2.0, 4.0, Vector2(x1 - x0, z1 - z0).length() + 0.5)
	var blocker := CollisionShape3D.new()
	blocker.shape = box
	blocker.position = Vector3((x0 + x1) * 0.5, river_bed_height + 2.0, (z0 + z1) * 0.5)
	blocker.rotation.y = atan2(x1 - x0, z1 - z0)
	add_child(blocker, false, Node.INTERNAL_MODE_BACK)
	_river_blockers.append(blocker)


func _build_bound_walls() -> void:
	for wall in _bound_walls:
		wall.queue_free()
	_bound_walls.clear()
	var center := walk_bounds.get_center()
	var thickness := 2.0
	# Each wall: position on the XZ plane and its size along X and Z.
	var walls := [
		[Vector2(walk_bounds.position.x - thickness * 0.5, center.y), Vector2(thickness, walk_bounds.size.y)],
		[Vector2(walk_bounds.end.x + thickness * 0.5, center.y), Vector2(thickness, walk_bounds.size.y)],
		[Vector2(center.x, walk_bounds.position.y - thickness * 0.5), Vector2(walk_bounds.size.x, thickness)],
		[Vector2(center.x, walk_bounds.end.y + thickness * 0.5), Vector2(walk_bounds.size.x, thickness)],
	]
	for w in walls:
		var box := BoxShape3D.new()
		box.size = Vector3(w[1].x, wall_height, w[1].y)
		var wall := CollisionShape3D.new()
		wall.shape = box
		wall.position = Vector3(w[0].x, wall_height * 0.25, w[0].y)
		add_child(wall, false, Node.INTERNAL_MODE_BACK)
		_bound_walls.append(wall)


func _distance_to_rect(x: float, z: float, rect: Rect2) -> float:
	var dx := maxf(maxf(rect.position.x - x, 0.0), x - rect.end.x)
	var dz := maxf(maxf(rect.position.y - z, 0.0), z - rect.end.y)
	return sqrt(dx * dx + dz * dz)
