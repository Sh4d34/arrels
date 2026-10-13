class_name Player
extends CharacterBody3D
## Player character: the keys give a direction relative to the camera; the character turns toward it
## at a limited rate and always walks the way it faces, so changes of direction draw curves.
## Simple walk bob for the placeholder model, and interaction with nearby interactables
## (E or left click, hold to repeat).

## prompt is empty when nothing can be interacted with; hint is an optional carnet text;
## possible is false for information-only prompts.
signal interaction_prompt_changed(prompt: String, hint: String, possible: bool)

@export_group("Movement")
@export var walk_speed: float = 3.5
@export var run_speed: float = 6.5
@export var acceleration: float = 14.0
@export var deceleration: float = 20.0
@export var turn_rate_deg: float = 400.0 ## Degrees per second when turning toward the input direction.
@export_range(0.0, 1.0) var sharp_turn_speed: float = 0.25 ## Speed kept when the input points behind.

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
var _speed: float = 0.0 ## Current walking speed along the facing direction.
var _bob_phase: float = 0.0
var _last_step: int = 0
var interaction_enabled: bool = true ## Turned off by modes that use the same inputs (building).
var _target: Node3D ## The physics body currently targeted, or null.
var _target_prompt: String = ""
var _target_hint: String = ""
var _target_possible: bool = false
var _cooldown_left: float = 0.0
var _swinging: bool = false

@onready var _model: Node3D = $Model
@onready var _highlight: TargetHighlight = $TargetHighlight


func _ready() -> void:
	_spawn_position = global_position


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta

	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction := _camera_relative_direction(input)
	var target_speed := 0.0
	if direction != Vector3.ZERO:
		# Turn toward the wanted direction at a limited rate (the model faces -Z).
		var wanted_yaw := atan2(-direction.x, -direction.z)
		var turn := angle_difference(_model.rotation.y, wanted_yaw)
		var max_step := deg_to_rad(turn_rate_deg) * delta
		_model.rotation.y += clampf(turn, -max_step, max_step)
		# Slow down in sharp turns: nearly on the spot when asked to go back.
		var alignment := cos(absf(turn))
		var full_speed := run_speed if Input.is_action_pressed("sprint") else walk_speed
		target_speed = full_speed * direction.length() * lerpf(sharp_turn_speed, 1.0, maxf(alignment, 0.0))
	var rate := acceleration if target_speed > _speed else deceleration
	_speed = move_toward(_speed, target_speed, rate * delta)
	# Always walk the way the character faces.
	var facing := Vector3(-sin(_model.rotation.y), 0.0, -cos(_model.rotation.y))
	velocity.x = facing.x * _speed
	velocity.z = facing.z * _speed
	move_and_slide()
	# Walls and trunks stop the walk instead of pushing back.
	_speed = minf(_speed, Vector2(get_real_velocity().x, get_real_velocity().z).length())

	_update_bob(delta, _speed)
	_update_interaction(delta)
	if global_position.y < fall_limit:
		global_position = _spawn_position
		velocity = Vector3.ZERO
		_speed = 0.0


func _update_interaction(delta: float) -> void:
	_cooldown_left = maxf(_cooldown_left - delta, 0.0)
	var target: Node3D = null
	if interaction_enabled:
		target = _find_hovered_interactable()
		if target == null:
			target = _find_nearest_interactable()
	var prompt := ""
	var hint := ""
	var possible := false
	if target:
		var interactable: Object = target.get_meta("interactable")
		prompt = interactable.call("get_interaction_prompt")
		if interactable.has_method("get_interaction_hint"):
			hint = interactable.call("get_interaction_hint")
		possible = interactable.call("can_interact")
	if target != _target or prompt != _target_prompt or hint != _target_hint or possible != _target_possible:
		_target = target
		_target_prompt = prompt
		_target_hint = hint
		_target_possible = possible
		_highlight.set_target(target, possible)
		interaction_prompt_changed.emit(prompt, hint, possible)
	if _target and Input.is_action_pressed("interact") and _cooldown_left == 0.0:
		_interact_with_target()


func _interact_with_target() -> void:
	var interactable: Object = _target.get_meta("interactable")
	if not interactable.call("can_interact"):
		return
	_cooldown_left = interact_cooldown
	var to_target := _target.global_position - global_position
	_model.rotation.y = atan2(-to_target.x, -to_target.z)
	_play_swing()
	interactable.call("interact", self)


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


## "bois", "terre" or "herbe": a "surface" metadata on the floor body wins (the bridge),
## then the terrain tells whether the player walks on the track.
func _floor_surface() -> String:
	for i in get_slide_collision_count():
		var collision := get_slide_collision(i)
		if collision.get_normal().y < 0.7:
			continue
		var floor_body := collision.get_collider() as Node
		if floor_body and floor_body.has_meta("surface"):
			return floor_body.get_meta("surface")
		if floor_body is Terrain:
			return "terre" if (floor_body as Terrain).is_on_track(global_position.x, global_position.z) else "herbe"
	return "herbe"


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
		# One step each time the bob touches the ground.
		var step := floori(_bob_phase / PI)
		if step != _last_step:
			_last_step = step
			Sfx.play("pas_" + _floor_surface(), global_position)
	else:
		_bob_phase = 0.0
		_last_step = 0
		_model.position.y = move_toward(_model.position.y, 0.0, delta)
