class_name Harvestable
extends Node
## Makes its parent body harvestable. Hits, drops and regrowth come from data/harvestables.json.
## The parent body joins the "interactable" group and points back to this component through
## its "interactable" metadata, so the player can find it from a physics body.

signal harvested(harvestable_id: String)

const INTERACTABLE_GROUP := "interactable"

@export var harvestable_id: String
@export var fall_duration: float = 1.2
@export var regrow_duration: float = 3.0

var _data: Dictionary
var _hits_left: int = 0
var _body: CollisionObject3D
var _rest_basis: Basis ## Only the basis: world.gd moves trees onto the terrain after this _ready().
var _collision_layer: int


func _ready() -> void:
	_body = get_parent() as CollisionObject3D
	_data = GameData.get_harvestable(harvestable_id)
	if _body == null or _data.is_empty():
		push_error("Harvestable: unknown id '%s' or parent is not a physics body" % harvestable_id)
		return
	_rest_basis = _body.transform.basis
	_collision_layer = _body.collision_layer
	_body.set_meta("interactable", self)
	_reset()


func get_interaction_prompt() -> String:
	return _data.get("invite", "")


func can_interact() -> bool:
	return _hits_left > 0


func interact(actor: Node3D) -> void:
	if not can_interact():
		return
	_hits_left -= 1
	if _hits_left > 0:
		_shake()
	else:
		_fell(actor)


func _reset() -> void:
	_hits_left = int(_data.get("coups", 1))
	_body.collision_layer = _collision_layer
	_body.add_to_group(INTERACTABLE_GROUP)


func _shake() -> void:
	var axis := Vector3(randf_range(-1.0, 1.0), 0.0, randf_range(-1.0, 1.0)).normalized()
	var tween := create_tween()
	tween.tween_method(func(t: float) -> void:
		_body.transform.basis = Basis(axis, sin(t * TAU * 2.0) * 0.05 * (1.0 - t)) * _rest_basis,
		0.0, 1.0, 0.35)


func _fell(actor: Node3D) -> void:
	_body.remove_from_group(INTERACTABLE_GROUP)
	_body.collision_layer = 0
	for drop: Dictionary in _data.get("recolte", []):
		Inventory.add(drop.item, int(drop.qte))
	harvested.emit(harvestable_id)

	# Tip the tree over, away from the actor, then shrink it out of sight.
	var away := _body.global_position - actor.global_position
	away.y = 0.0
	if away.length() < 0.01:
		away = Vector3.FORWARD
	var axis := Vector3.UP.cross(away.normalized())
	var tween := create_tween()
	tween.tween_method(func(angle: float) -> void:
		_body.transform.basis = Basis(axis, angle) * _rest_basis,
		0.0, deg_to_rad(85.0), fall_duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(_body, "scale", _body.scale * 0.01, 0.6).set_delay(0.4)
	tween.tween_callback(_after_fall)


func _after_fall() -> void:
	var regrow_delay: Variant = _data.get("repousse_secondes")
	if regrow_delay == null:
		_body.queue_free()
		return
	_body.visible = false
	get_tree().create_timer(float(regrow_delay)).timeout.connect(_regrow)


func _regrow() -> void:
	_body.transform.basis = _rest_basis
	var full_scale := _body.scale
	_body.scale = full_scale * 0.1
	_body.visible = true
	var tween := create_tween()
	tween.tween_property(_body, "scale", full_scale, regrow_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_callback(_reset)
