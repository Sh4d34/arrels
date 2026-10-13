class_name DryStone
extends RefCounted
## Dry-stone masonry shared by the terrace walls and the cortal: courses of irregular stones
## along a segment, merged into a SurfaceTool. The top can slope (gables) and crumble (ruins),
## and openings (doors) are left free.

const COLORS: Array[Color] = [
	Color(0.62, 0.58, 0.5), Color(0.55, 0.5, 0.42), Color(0.68, 0.63, 0.53), Color(0.5, 0.47, 0.42), Color(0.6, 0.53, 0.42)]


## A wall from start to end (their y is the wall's base), top_start / top_end high at each end.
## openings: Array of Vector3(from, to, top) along the wall, in meters from start.
## crumble: how much of the top may randomly be missing, in meters.
static func wall(st: SurfaceTool, rng: RandomNumberGenerator, start: Vector3, end: Vector3, top_start: float,
		top_end: float, thickness: float, openings: Array = [], crumble: float = 0.0) -> void:
	var flat := Vector3(end.x - start.x, 0.0, end.z - start.z)
	var length := flat.length()
	var basis := Basis.looking_at(flat.normalized().cross(Vector3.UP), Vector3.UP) # Local x runs along the wall.
	var y := 0.0
	var tallest := maxf(top_start, top_end)
	while y < tallest:
		var course := rng.randf_range(0.22, 0.32)
		var along := -rng.randf() * 0.8
		while along < length:
			var stone := rng.randf_range(0.35, 0.8)
			var a0 := maxf(along, 0.0)
			var a1 := minf(along + stone, length)
			along += stone
			var middle := (a0 + a1) * 0.5
			var top := lerpf(top_start, top_end, middle / length) - rng.randf() * crumble
			if a1 - a0 < 0.1 or y + 0.12 > top or _in_opening(middle, y, openings):
				continue
			var size := Vector3(a1 - a0 - 0.04, minf(course, top - y) - 0.03, thickness * rng.randf_range(0.85, 1.0))
			var base := start.lerp(end, middle / length)
			var center := Vector3(base.x, start.y + y + size.y * 0.5, base.z)
			var tilt := Basis(Vector3.FORWARD, rng.randf_range(-0.04, 0.04))
			var color: Color = COLORS[rng.randi() % COLORS.size()].darkened(rng.randf_range(0.0, 0.12))
			box(st, Transform3D(basis * tilt, center), size, color)
		y += course


static func _in_opening(along: float, y: float, openings: Array) -> bool:
	for opening: Vector3 in openings:
		if along > opening.x and along < opening.y and y < opening.z:
			return true
	return false


static func box(st: SurfaceTool, transform: Transform3D, size: Vector3, color: Color) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	var arrays := mesh.get_mesh_arrays()
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	st.set_color(color)
	for index: int in arrays[Mesh.ARRAY_INDEX]:
		st.set_normal((transform.basis * normals[index]).normalized())
		st.add_vertex(transform * vertices[index])


static func material() -> StandardMaterial3D:
	var result := StandardMaterial3D.new()
	result.vertex_color_use_as_albedo = true
	result.vertex_color_is_srgb = true
	result.roughness = 1.0
	return result
