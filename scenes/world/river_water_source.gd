class_name RiverWaterSource
extends Node3D
## Lets the player fill the watering can anywhere along the river banks, except on bridges.
## Follows the player along the shore, so the usual "nearest interactable" targeting finds it.

@export var terrain: Terrain
@export var player: Node3D
@export var water_item: String = "eau"
@export var bridge_margin: float = 1.0 ## Extra distance kept from bridge openings.
@export var water: MeshInstance3D ## The river surface, which shows the highlight halo.
@export var halo_offset: float = 1.8 ## Moves the halo from the bank toward the middle of the river.

var _highlighted: bool = false


func _ready() -> void:
	set_meta("interactable", self)


func _physics_process(_delta: float) -> void:
	var z := player.global_position.z
	var center_x := terrain.river_center_x(z)
	var side := signf(player.global_position.x - center_x)
	var shore_x := center_x + side * terrain.blocker_half_width
	# At the water level, not on the bank: in the gorges the water runs far below the banks,
	# and the player's height check then keeps it out of reach from the hilltops.
	var water_y := water.global_position.y if water else terrain.surface_height_at(shore_x, z)
	global_position = Vector3(shore_x, water_y, z)
	var on_bridge := false
	for crossing in terrain.river_crossings:
		if absf(z - crossing.x) < crossing.y + bridge_margin:
			on_bridge = true
	if on_bridge and is_in_group(Harvestable.INTERACTABLE_GROUP):
		remove_from_group(Harvestable.INTERACTABLE_GROUP)
	elif not on_bridge and not is_in_group(Harvestable.INTERACTABLE_GROUP):
		add_to_group(Harvestable.INTERACTABLE_GROUP)
	if _highlighted and _water_material():
		_water_material().set_shader_parameter("highlight_position", _halo_position())


func get_interaction_prompt() -> String:
	return GameData.text("riviere.remplir" if can_interact() else "riviere.plein")


func get_interaction_hint() -> String:
	return ""


func can_interact() -> bool:
	return Inventory.count(water_item) < _capacity()


func interact(_actor: Node3D) -> void:
	if can_interact():
		Sfx.play("remplir_arrosoir", global_position)
		Inventory.add(water_item, _capacity() - Inventory.count(water_item))


## Called by the player's TargetHighlight: a glowing halo on the water instead of a mesh glow.
func set_highlighted(on: bool, tint: Color) -> void:
	_highlighted = on
	var material := _water_material()
	if material:
		material.set_shader_parameter("highlight_amount", 1.0 if on else 0.0)
		material.set_shader_parameter("highlight_tint", tint)
		material.set_shader_parameter("highlight_position", _halo_position())


func _halo_position() -> Vector3:
	var toward_center := signf(terrain.river_center_x(global_position.z) - global_position.x)
	return global_position + Vector3(toward_center * halo_offset, 0.0, 0.0)


func _water_material() -> ShaderMaterial:
	if water == null or water.mesh == null:
		return null
	return water.mesh.surface_get_material(0) as ShaderMaterial


func _capacity() -> int:
	return int(GameData.get_item(water_item).get("max_pile", 1))
