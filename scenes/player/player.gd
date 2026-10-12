class_name Player
extends CharacterBody3D
## Player character: camera-relative movement on foot, with a simple walk bob for the placeholder model,
## and interaction with nearby interactables (Space or left click, hold to repeat).

signal interaction_prompt_changed(prompt: String) ## Empty when nothing can be interacted with.

@export_group("Movement")
@export var walk_speed: float = 3.5
@export var run_speed: float = 6.5
@export var acceleration: float = 20.0
@export var deceleration: float = 25.0
@export var turn_speed: float = 12.0 ## Higher turns faster toward the movement direction.

@export_group("Walk bob")
@export var bob_height: float = 0.06
@export var bob_frequency: float = 9.0

@export_group("Interaction")
@export var interact_reach: float = 2.6 ## Horizontal distance to an interactable's origin.
@export var interact_cooldown: float = 0.45 ## Seconds between two hits when holding the key.
@export_range(0.0, 180.0) var interact_max_angle_deg: float = 110.0 ## Ignored behind the player.
@export var hover_pick_radius: float = 90.0 ## Pixels around the mouse to pick an interactable on screen.

@export_group("Safety")
@export var fall_limit: float = -20.0 ## Below this height, the player is put back at the spawn point.

var _spawn_position: Vector3
var _bob_phase: float = 0.0
var _target: Node3D ## The physics body currently targeted, or null.
var _target_prompt: String = ""
var _cooldown_left: float = 0.0
var _swinging: bool = false

@onready var _model: Node3D = $Model


func _ready() -> void:
	_spawn_position = global_position


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta

	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction := _camera_relative_direction(input)
	var target_speed := run_speed if Input.is_action_pressed("sprint") else walk_speed
	var horizontal := Vector3(velocity.x, 0.0, velocity.z)
	if direction != Vector3.ZERO:
		horizontal = horizontal.move_toward(direction * target_speed, acceleration * delta)
		# The model faces -Z, so this yaw points it along the movement direction.
		var target_yaw := atan2(-direction.x, -direction.z)
		_model.rotation.y = lerp_angle(_model.rotation.y, target_yaw, 1.0 - exp(-turn_speed * delta))
	else:
		horizontal = horizontal.move_toward(Vector3.ZERO, deceleration * delta)
	velocity.x = horizontal.x
	velocity.z = horizontal.z
	move_and_slide()

	_update_bob(delta, horizontal.length())
	_update_interaction(delta)
	if global_position.y < fall_limit:
		global_position = _spawn_position
		velocity = Vector3.ZERO


func _update_interaction(delta: float) -> void:
	_cooldown_left = maxf(_cooldown_left - delta, 0.0)
	var target := _find_hovered_interactable()
	if target == null:
		target = _find_nearest_interactable()
	var prompt := ""
	if target:
		prompt = (target.get_meta("interactable") as Object).call("get_interaction_prompt")
	if target != _target or prompt != _target_prompt:
		_target = target
		_target_prompt = prompt
		interaction_prompt_changed.emit(prompt)
	if _target and Input.is_action_pressed("interact") and _cooldown_left == 0.0:
		_interact_with_target()


func _interact_with_target() -> void:
	_cooldown_left = interact_cooldown
	var to_target := _target.global_position - global_position
	_model.rotation.y = atan2(-to_target.x, -to_target.z)
	_play_swing()
	(_target.get_meta("interactable") as Object).call("interact", self)


func _is_reachable(body: Node3D) -> bool:
	var to_body := body.global_position - global_position
	to_body.y = 0.0
	if to_body.length() > interact_reach:
		return false
	if to_body.length() < 0.5:
		return true
	var facing := Vector3(-sin(_model.rotation.y), 0.0, -cos(_model.rotation.y))
	return rad_to_deg(facing.angle_to(to_body)) <= interact_max_angle_deg


func _find_nearest_interactable() -> Node3D:
	var best: Node3D = null
	var best_distance := INF
	for node in get_tree().get_nodes_in_group(Harvestable.INTERACTABLE_GROUP):
		var body := node as Node3D
		if body and _is_reachable(body):
			var distance := global_position.distance_to(body.global_position)
			if distance < best_distance:
				best = body
				best_distance = distance
	return best


func _find_hovered_interactable() -> Node3D:
	# Picks on screen around the trunk, so pointing at the foliage works too.
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return null
	var mouse := get_viewport().get_mouse_position()
	var best: Node3D = null
	var best_distance := hover_pick_radius
	for node in get_tree().get_nodes_in_group(Harvestable.INTERACTABLE_GROUP):
		var body := node as Node3D
		if body == null or not _is_reachable(body):
			continue
		var point := body.global_position + Vector3.UP * 1.5
		if camera.is_position_behind(point):
			continue
		var distance := camera.unproject_position(point).distance_to(mouse)
		if distance < best_distance:
			best = body
			best_distance = distance
	return best


func _play_swing() -> void:
	if _swinging:
		return
	_swinging = true
	var tween := create_tween()
	tween.tween_property(_model, "rotation:x", -0.35, 0.1).set_ease(Tween.EASE_OUT)
	tween.tween_property(_model, "rotation:x", 0.0, 0.2).set_ease(Tween.EASE_IN_OUT)
	tween.tween_callback(func() -> void: _swinging = false)


func _camera_relative_direction(input: Vector2) -> Vector3:
	var camera := get_viewport().get_camera_3d()
	if camera == null or input == Vector2.ZERO:
		return Vector3(input.x, 0.0, input.y)
	# Flatten the camera axes so looking down does not slow the player.
	var forward := -camera.global_basis.z
	forward.y = 0.0
	var right := camera.global_basis.x
	right.y = 0.0
	return right.normalized() * input.x - forward.normalized() * input.y


func _update_bob(delta: float, speed: float) -> void:
	if speed > 0.1 and is_on_floor():
		_bob_phase += delta * bob_frequency * (speed / walk_speed)
		_model.position.y = absf(sin(_bob_phase)) * bob_height
	else:
		_bob_phase = 0.0
		_model.position.y = move_toward(_model.position.y, 0.0, delta)
