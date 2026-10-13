@tool
class_name NatureProp
extends StaticBody3D
## A tree or a rock built from an imported model, with a simple cylinder collision.
## With a harvestable_id, it can be harvested (see Harvestable and data/harvestables.json).

@export var model: PackedScene:
	set(value):
		model = value
		if is_node_ready():
			_build()
@export var collision_radius: float = 0.35
@export var collision_height: float = 3.0
@export var harvestable_id: String = "" ## Empty for a purely decorative prop.
@export_enum("arbre", "rocher") var kind: String = "arbre" ## Tells build mode what is in the way.

var _model_instance: Node3D
var _collision_shape: CollisionShape3D


func _ready() -> void:
	_build()
	if harvestable_id != "" and not Engine.is_editor_hint():
		var harvestable := Harvestable.new()
		harvestable.harvestable_id = harvestable_id
		add_child(harvestable)


func _build() -> void:
	# Built at load time as internal children, so the model is never duplicated in the scene file.
	if _model_instance:
		_model_instance.queue_free()
		_model_instance = null
	if model:
		_model_instance = model.instantiate()
		add_child(_model_instance, false, Node.INTERNAL_MODE_FRONT)
	if _collision_shape == null:
		_collision_shape = CollisionShape3D.new()
		add_child(_collision_shape, false, Node.INTERNAL_MODE_FRONT)
	var cylinder := CylinderShape3D.new()
	cylinder.radius = collision_radius
	cylinder.height = collision_height
	_collision_shape.shape = cylinder
	_collision_shape.position.y = collision_height * 0.5
