@tool
class_name NatureTree
extends StaticBody3D
## A tree built from an imported model, with a simple cylinder collision around its trunk.

@export var model: PackedScene:
	set(value):
		model = value
		if is_node_ready():
			_build()
@export var trunk_radius: float = 0.35
@export var trunk_height: float = 3.0

var _model_instance: Node3D
var _trunk_shape: CollisionShape3D


func _ready() -> void:
	_build()


func _build() -> void:
	# Built at load time as internal children, so the model is never duplicated in the scene file.
	if _model_instance:
		_model_instance.queue_free()
		_model_instance = null
	if model:
		_model_instance = model.instantiate()
		add_child(_model_instance, false, Node.INTERNAL_MODE_FRONT)
	if _trunk_shape == null:
		_trunk_shape = CollisionShape3D.new()
		add_child(_trunk_shape, false, Node.INTERNAL_MODE_FRONT)
	var cylinder := CylinderShape3D.new()
	cylinder.radius = trunk_radius
	cylinder.height = trunk_height
	_trunk_shape.shape = cylinder
	_trunk_shape.position.y = trunk_height * 0.5
