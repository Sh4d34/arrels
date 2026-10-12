class_name Player
extends CharacterBody3D
## Player character: camera-relative movement on foot, with a simple walk bob for the placeholder model.

@export_group("Movement")
@export var walk_speed: float = 3.5
@export var run_speed: float = 6.5
@export var acceleration: float = 20.0
@export var deceleration: float = 25.0
@export var turn_speed: float = 12.0 ## Higher turns faster toward the movement direction.

@export_group("Walk bob")
@export var bob_height: float = 0.06
@export var bob_frequency: float = 9.0

@export_group("Safety")
@export var fall_limit: float = -20.0 ## Below this height, the player is put back at the spawn point.

var _spawn_position: Vector3
var _bob_phase: float = 0.0

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
	if global_position.y < fall_limit:
		global_position = _spawn_position
		velocity = Vector3.ZERO


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
