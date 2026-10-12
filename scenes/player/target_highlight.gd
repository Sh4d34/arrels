class_name TargetHighlight
extends Node
## Makes the targeted object glow softly. Each mesh of the target gets brightened copies of its
## own materials (so cut-out leaves and vertex-color shading are kept), restored when the target changes.
## Re-applied every frame, because some targets (plots) rebuild their meshes as they change.
## A target without its own meshes (the river) can glow its own way by implementing
## set_highlighted(on: bool, tint: Color); it then gets no material changes.

@export var action_tint: Color = Color(1.0, 0.92, 0.7) ## Warm tint when an action is possible.
@export var info_tint: Color = Color(0.85, 0.92, 1.0) ## Cool tint for information-only prompts.
@export var brightness_min: float = 1.25 ## Brightness multiplier at the bottom of the pulse.
@export var brightness_max: float = 1.6
@export var pulse_speed: float = 3.5

var _target: Node3D
var _possible: bool = false
## MeshInstance3D -> {"override": [original, glowing] or [], "surfaces": {index: [active, glowing, previous override]}}
## The original material is kept to restore it, and to read its base color.
var _entries: Dictionary = {}


func set_target(target: Node3D, possible: bool) -> void:
	if target != _target:
		_set_custom_highlight(_target, false)
		_clear()
		_target = target
	_possible = possible
	_set_custom_highlight(_target, true)


func _process(_delta: float) -> void:
	if _target == null or not is_instance_valid(_target):
		_clear()
		_target = null
		return
	if _target.has_method("set_highlighted"):
		return
	for mesh in _meshes_in(_target):
		_apply(mesh)
	var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.001 * pulse_speed)
	var tint := (action_tint if _possible else info_tint) * lerpf(brightness_min, brightness_max, pulse)
	for mesh: MeshInstance3D in _entries:
		var entry: Dictionary = _entries[mesh]
		var pairs: Array = entry.surfaces.values()
		if not entry.override.is_empty():
			pairs.append(entry.override)
		for pair: Array in pairs:
			var base: Color = pair[0].albedo_color if pair[0] is BaseMaterial3D else Color.WHITE
			# Above 1.0 on purpose: the color multiplies the texture and vertex colors.
			pair[1].albedo_color = Color(base.r * tint.r, base.g * tint.g, base.b * tint.b, base.a)


func _apply(mesh: MeshInstance3D) -> void:
	var entry: Dictionary = _entries.get(mesh, {"override": [], "surfaces": {}})
	_entries[mesh] = entry
	if mesh.material_override:
		# The owner may have replaced its override since last frame: glow the new one.
		if entry.override.is_empty() or mesh.material_override != entry.override[1]:
			var glowing := _glowing_copy(mesh.material_override)
			if glowing:
				entry.override = [mesh.material_override, glowing]
				mesh.material_override = glowing
		return
	for i in mesh.get_surface_override_material_count():
		if entry.surfaces.has(i) and mesh.get_surface_override_material(i) == entry.surfaces[i][1]:
			continue
		var active := mesh.get_active_material(i)
		var glowing := _glowing_copy(active)
		if glowing:
			entry.surfaces[i] = [active, glowing, mesh.get_surface_override_material(i)]
			mesh.set_surface_override_material(i, glowing)


func _set_custom_highlight(node: Node3D, on: bool) -> void:
	if node and is_instance_valid(node) and node.has_method("set_highlighted"):
		node.set_highlighted(on, action_tint if _possible else info_tint)


func _clear() -> void:
	# Only restore materials still showing our glowing copy.
	for mesh in _entries:
		if not is_instance_valid(mesh):
			continue
		var entry: Dictionary = _entries[mesh]
		if not entry.override.is_empty() and mesh.material_override == entry.override[1]:
			mesh.material_override = entry.override[0]
		for i in entry.surfaces:
			if mesh.get_surface_override_material(i) == entry.surfaces[i][1]:
				mesh.set_surface_override_material(i, entry.surfaces[i][2])
	_entries.clear()


func _glowing_copy(material: Material) -> BaseMaterial3D:
	if not material is BaseMaterial3D:
		return null
	return material.duplicate()


## Every mesh under the node, including internal children (tree models are internal).
func _meshes_in(node: Node) -> Array[MeshInstance3D]:
	var result: Array[MeshInstance3D] = []
	for child in node.get_children(true):
		if child is MeshInstance3D:
			result.append(child)
		result.append_array(_meshes_in(child))
	return result
