class_name BuildMode
extends Node3D
## Build mode: a grid projected around the cursor, a ghost preview snapped to the grid,
## placement checks and construction of the buildables defined in data/buildables.json.

signal mode_changed(active: bool, buildable_id: String)
signal placement_changed(valid: bool, reason: String) ## reason is empty when valid.
signal built(buildable_id: String)

@export var terrain: Terrain
@export var player: Player
@export var buildings: Node3D ## Parent of every placed building.

@export_group("Grid")
@export var cell_size: float = 1.0
@export var grid_extent: float = 12.0 ## Width of the visible grid, in meters.
@export_flags_3d_render var grid_layer: int = 2 ## Render layer the grid projects onto (the terrain).

@export_group("Placement")
@export var max_distance: float = 15.0 ## From the player.
@export var max_height_difference: float = 0.35 ## Across the footprint.
@export var water_margin: float = 0.4 ## Extra distance kept from the river walls.

@export_group("Ghost colors")
@export var valid_color: Color = Color(0.45, 0.95, 0.5, 0.5)
@export var invalid_color: Color = Color(1.0, 0.35, 0.3, 0.5)

var active: bool = false

var _buildable_id: String = ""
var _data: Dictionary
var _scene: PackedScene
var _ghost: Node3D
var _ghost_material: StandardMaterial3D
var _rotation_steps: int = 0
var _valid: bool = false
var _reason: String = ""

var _grid_mesh: MeshInstance3D ## Fallback grid where decals are not supported (web).
var _grid_mesh_cell := Vector2i(1 << 30, 0)

@onready var _grid: Decal = $GridDecal


func _ready() -> void:
	var texture := _make_grid_texture()
	_grid.texture_albedo = texture
	_grid.size = Vector3(grid_extent, 6.0, grid_extent)
	_grid.cull_mask = grid_layer
	_grid.visible = false
	if RenderingServer.get_current_rendering_method() == "gl_compatibility":
		# The Compatibility renderer (web) ignores decals: draw the grid on a mesh hugging the ground.
		_grid_mesh = MeshInstance3D.new()
		_grid_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var material := StandardMaterial3D.new()
		material.albedo_texture = texture
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_grid_mesh.material_override = material
		_grid_mesh.visible = false
		add_child(_grid_mesh)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("build_mode"):
		if active:
			exit()
		elif not GameData.buildables.is_empty():
			enter(GameData.buildables.keys()[0])
	elif not active:
		return
	elif _slot_pressed(event) >= 0:
		enter(GameData.buildables.keys()[_slot_pressed(event)])
	elif event.is_action_pressed("build_cancel"):
		exit()
	elif event.is_action_pressed("build_rotate"):
		_rotation_steps = (_rotation_steps + 1) % 4
	elif event.is_action_pressed("interact"):
		_try_place()
	else:
		return
	get_viewport().set_input_as_handled()


## Enters build mode with this buildable, or switches to it when already building.
func enter(buildable_id: String) -> void:
	_data = GameData.get_buildable(buildable_id)
	if _data.is_empty():
		return
	if _ghost:
		_ghost.queue_free()
	_buildable_id = buildable_id
	_scene = load(_data.scene)
	_ghost = _make_ghost()
	add_child(_ghost)
	active = true
	_grid.visible = _grid_mesh == null
	if _grid_mesh:
		_grid_mesh.visible = true
	player.interaction_enabled = false
	_valid = false
	_reason = ""
	mode_changed.emit(true, buildable_id)


func exit() -> void:
	if _ghost:
		_ghost.queue_free()
		_ghost = null
	active = false
	_grid.visible = false
	if _grid_mesh:
		_grid_mesh.visible = false
	player.interaction_enabled = true
	mode_changed.emit(false, "")


func get_buildable_id() -> String:
	return _buildable_id


## Index of the buildable chosen with the number keys (build_slot_1, build_slot_2...), or -1.
func _slot_pressed(event: InputEvent) -> int:
	for i in GameData.buildables.size():
		var action := "build_slot_%d" % (i + 1)
		if InputMap.has_action(action) and event.is_action_pressed(action):
			return i
	return -1


func _physics_process(_delta: float) -> void:
	if not active:
		return
	var hit: Variant = _mouse_ground_point()
	if hit == null:
		_ghost.visible = false
		_set_placement(false, "")
		return
	update_preview(hit)


## Moves the ghost to the grid cell under a ground point and checks the placement there.
func update_preview(point: Vector3) -> void:
	var size := _footprint_size()
	# The hovered cell is the footprint's first corner.
	var corner := Vector2(floorf(point.x / cell_size), floorf(point.z / cell_size)) * cell_size
	var center := corner + size * 0.5
	var heights := _footprint_heights(corner, size)
	var y: float = heights.reduce(func(a: float, b: float) -> float: return a + b) / heights.size()
	_ghost.visible = true
	_ghost.global_transform = Transform3D(Basis(Vector3.UP, _rotation_steps * PI * 0.5), Vector3(center.x, y, center.y))
	# Keep grid lines on cell boundaries.
	_grid.global_position = Vector3(roundf(point.x / cell_size) * cell_size, y, roundf(point.z / cell_size) * cell_size)
	if _grid_mesh:
		_update_grid_mesh(Vector2i(roundi(point.x / cell_size), roundi(point.z / cell_size)))
	var reason := _check_placement(center, size, heights)
	_set_placement(reason == "", reason)


func _footprint_size() -> Vector2:
	var cells: Array = _data.get("taille_grille", [1, 1])
	var size := Vector2(cells[0], cells[1]) * cell_size
	return Vector2(size.y, size.x) if _rotation_steps % 2 == 1 else size


func _footprint_heights(corner: Vector2, size: Vector2) -> Array[float]:
	var heights: Array[float] = []
	for offset in [Vector2.ZERO, Vector2(size.x, 0.0), Vector2(0.0, size.y), size, size * 0.5]:
		var p: Vector2 = corner + offset
		heights.append(terrain.surface_height_at(p.x, p.y))
	return heights


## Returns an empty string when the building can be placed, otherwise the reason shown to the player.
func _check_placement(center: Vector2, size: Vector2, heights: Array[float]) -> String:
	var to_player := Vector2(player.global_position.x, player.global_position.z) - center
	if to_player.length() > max_distance:
		return "Trop loin"
	if not terrain.walk_bounds.grow(-1.0).has_point(center):
		return "Hors du terrain"
	var half_diagonal := size.length() * 0.5
	if absf(center.x - terrain.river_center_x(center.y)) < terrain.blocker_half_width + water_margin + half_diagonal:
		return "Trop près de l'eau"
	if heights.max() - heights.min() > max_height_difference:
		return "Terrain trop pentu"
	var obstacle := _find_obstacle(center, size, heights.min())
	if obstacle != "":
		return obstacle
	for cost: Dictionary in _data.get("cout", []):
		var missing := int(cost.qte) - Inventory.count(cost.item)
		if missing > 0:
			return "Il manque %d %s" % [missing, GameData.item_name(cost.item).to_lower()]
	return ""


func _find_obstacle(center: Vector2, size: Vector2, ground_y: float) -> String:
	var box := BoxShape3D.new()
	box.size = Vector3(size.x - 0.1, 2.0, size.y - 0.1)
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = box
	query.transform = Transform3D(Basis.IDENTITY, Vector3(center.x, ground_y + 1.1, center.y))
	query.exclude = [terrain.get_rid()]
	for result in get_world_3d().direct_space_state.intersect_shape(query, 8):
		var collider: Object = result.collider
		if collider == player:
			return "Tu es sur l'emplacement"
		if collider is NatureTree:
			return "Un arbre gêne"
		return "La place est occupée"
	return ""


func _try_place() -> void:
	if not _valid or not Inventory.remove_all(_data.get("cout", [])):
		return
	var building: Node3D = _scene.instantiate()
	buildings.add_child(building)
	building.global_transform = _ghost.global_transform
	Sfx.play("construire", building.global_position)
	var full_scale := building.scale
	building.scale = full_scale * 0.6
	building.create_tween().tween_property(building, "scale", full_scale, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	built.emit(_buildable_id)


func _set_placement(valid: bool, reason: String) -> void:
	if _ghost_material:
		_ghost_material.albedo_color = valid_color if valid else invalid_color
	if valid != _valid or reason != _reason:
		_valid = valid
		_reason = reason
		placement_changed.emit(valid, reason)


func _make_ghost() -> Node3D:
	var ghost: Node3D = _scene.instantiate()
	# A ghost is only a picture: no gameplay script must run on it.
	for node in ghost.find_children("*", "", true, false) + [ghost]:
		node.set_script(null)
	for body in ghost.find_children("*", "CollisionObject3D", true, false) + [ghost]:
		if body is CollisionObject3D:
			body.collision_layer = 0
			body.collision_mask = 0
	_ghost_material = StandardMaterial3D.new()
	_ghost_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_ghost_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_ghost_material.albedo_color = invalid_color
	for mesh in ghost.find_children("*", "MeshInstance3D", true, false):
		(mesh as MeshInstance3D).material_override = _ghost_material
		(mesh as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return ghost


## Where the mouse ray meets the terrain surface, or null.
## Marches along the ray instead of using physics, so trees and buildings never get in the way.
func _mouse_ground_point() -> Variant:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return null
	var mouse := get_viewport().get_mouse_position()
	var origin := camera.project_ray_origin(mouse)
	var direction := camera.project_ray_normal(mouse)
	const STEP := 0.5
	const MAX_LENGTH := 200.0
	var t := 0.0
	while t < MAX_LENGTH:
		var p := origin + direction * (t + STEP)
		if p.y <= terrain.surface_height_at(p.x, p.z):
			# Refine between the last point above ground and this one.
			var low := t
			var high := t + STEP
			for i in 8:
				var mid := (low + high) * 0.5
				var q := origin + direction * mid
				if q.y <= terrain.surface_height_at(q.x, q.z):
					high = mid
				else:
					low = mid
			return origin + direction * high
		t += STEP
	return null


## Rebuilds the fallback grid around a cell corner, following the terrain heights.
func _update_grid_mesh(center: Vector2i) -> void:
	if center == _grid_mesh_cell:
		return
	_grid_mesh_cell = center
	const SUBDIVISIONS := 2 ## Vertices per cell, so the grid follows small bumps.
	var cells := roundi(grid_extent / cell_size)
	var count := cells * SUBDIVISIONS
	var step := cell_size / SUBDIVISIONS
	var origin := Vector2(center) * cell_size - Vector2.ONE * grid_extent * 0.5
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for j in count:
		for i in count:
			var quad: Array[Vector2] = [Vector2(i, j), Vector2(i + 1, j), Vector2(i, j + 1), Vector2(i + 1, j + 1)]
			var points: Array[Vector3] = []
			for corner in quad:
				var p := origin + corner * step
				points.append(Vector3(p.x, terrain.surface_height_at(p.x, p.y) + 0.04, p.y))
			for index in [0, 1, 2, 1, 3, 2]:
				st.set_uv(quad[index] / count)
				st.add_vertex(points[index])
	_grid_mesh.mesh = st.commit()


func _make_grid_texture() -> ImageTexture:
	# One white line per cell boundary, fading out toward the edges of the grid.
	const PIXELS_PER_CELL := 48
	const LINE_WIDTH := 2
	var cells := roundi(grid_extent / cell_size)
	var size := cells * PIXELS_PER_CELL
	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var half := size * 0.5
	for line in cells:
		for w in LINE_WIDTH:
			var fixed := line * PIXELS_PER_CELL + w
			for along in size:
				# Vertical line at x = fixed, then horizontal line at y = fixed.
				for pixel: Vector2i in [Vector2i(fixed, along), Vector2i(along, fixed)]:
					var r := Vector2(pixel.x - half, pixel.y - half).length() / half
					image.set_pixelv(pixel, Color(1.0, 1.0, 1.0, 0.6 * (1.0 - smoothstep(0.45, 1.0, r))))
	return ImageTexture.create_from_image(image)
