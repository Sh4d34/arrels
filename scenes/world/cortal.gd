@tool
class_name Cortal
extends StaticBody3D
## An old shepherd's hut (cortal) in ruins: dry-stone walls with a door and its wooden lintel,
## gables following the fallen roof, a crumbled corner and two beams lying inside.
## It is an interactable for information only: aiming at it shows a carnet text.

@export var size: Vector2 = Vector2(4.0, 3.0) ## Outside width (x) and depth (z).
@export var thickness: float = 0.5
@export var eaves_height: float = 1.7
@export var ridge_height: float = 2.4
@export var door_width: float = 0.9
@export var door_height: float = 1.55
@export var foundation_depth: float = 0.5 ## Below the origin, so the walls sit on sloping ground.
@export var seed: int = 3
@export var wood_color: Color = Color(0.36, 0.25, 0.16)

var _mesh_instance: MeshInstance3D


func _ready() -> void:
	_build()
	if not Engine.is_editor_hint():
		set_meta("interactable", self)
		add_to_group(Harvestable.INTERACTABLE_GROUP)


func get_interaction_prompt() -> String:
	return GameData.text("lieux.cortal")


func get_interaction_hint() -> String:
	return GameData.text("lieux.cortal_carnet")


## Reached from anywhere around the hut, not only near its center.
func get_interaction_radius() -> float:
	return maxf(size.x, size.y) * 0.5 + 0.5


func can_interact() -> bool:
	return false


func interact(_actor: Node3D) -> void:
	pass


func _build() -> void:
	if _mesh_instance:
		_mesh_instance.queue_free()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var hx := size.x * 0.5 - thickness * 0.5
	var hz := size.y * 0.5 - thickness * 0.5
	var base := -foundation_depth
	var eaves := eaves_height + foundation_depth
	var ridge := ridge_height + foundation_depth
	# Back wall (-z) and front wall (+z) carry the gables; the front has the door.
	var door_from := hx - door_width * 0.5
	DryStone.wall(st, rng, Vector3(-hx, base, -hz), Vector3(0.0, base, -hz), eaves, ridge, thickness, [], 0.35)
	DryStone.wall(st, rng, Vector3(0.0, base, -hz), Vector3(hx, base, -hz), ridge, eaves * 0.55, thickness, [], 0.5) # Crumbled corner.
	DryStone.wall(st, rng, Vector3(-hx, base, hz), Vector3(hx, base, hz), eaves, eaves, thickness,
		[Vector3(door_from, door_from + door_width, door_height + foundation_depth)], 0.3)
	DryStone.wall(st, rng, Vector3(-hx, base, -hz), Vector3(-hx, base, hz), eaves, eaves, thickness, [], 0.3)
	DryStone.wall(st, rng, Vector3(hx, base, -hz), Vector3(hx, base, hz), eaves * 0.6, eaves * 0.9, thickness, [], 0.4)
	# Wooden lintel over the door, and two roof beams fallen inside.
	DryStone.box(st, Transform3D(Basis(), Vector3(0.0, door_height + 0.08, hz)), Vector3(door_width + 0.5, 0.16, thickness + 0.06), wood_color)
	DryStone.box(st, Transform3D(Basis(Vector3.UP, 0.4) * Basis(Vector3.FORWARD, 0.18), Vector3(-0.3, 0.25, -0.2)), Vector3(2.6, 0.14, 0.14), wood_color)
	DryStone.box(st, Transform3D(Basis(Vector3.UP, -0.7), Vector3(0.4, 0.08, 0.4)), Vector3(1.8, 0.12, 0.12), wood_color.darkened(0.2))
	_mesh_instance = MeshInstance3D.new()
	_mesh_instance.mesh = st.commit()
	_mesh_instance.material_override = DryStone.material()
	add_child(_mesh_instance, false, Node.INTERNAL_MODE_FRONT)
