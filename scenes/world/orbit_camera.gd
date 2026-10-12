class_name OrbitCamera
extends Node3D
## Orbit camera around a ground pivot, following a target when one is set.
## Right drag or A / E (AZERTY): rotate. Wheel / pinch: zoom.
## Without a target, middle drag or Shift + right drag: pan.
## With a moving target, the camera slowly swings back behind it unless rotated by hand recently.

@export var target: Node3D ## When set, the pivot follows it and panning is disabled.
@export var target_height: float = 1.2 ## Point looked at, above the target's origin.
@export var follow_smoothing: float = 8.0

@export_group("Rotation")
@export var rotate_sensitivity: float = 0.3 ## Degrees per pixel.
@export_range(-89.0, 0.0) var min_pitch_deg: float = -80.0
@export_range(-89.0, 0.0) var max_pitch_deg: float = -6.0
@export var keyboard_rotate_speed: float = 100.0 ## Degrees per second.

@export_group("Auto follow")
@export var auto_follow_enabled: bool = true
@export var auto_follow_delay: float = 2.5 ## Seconds after a manual rotation before swinging back.
@export var auto_follow_speed: float = 1.0 ## Higher swings back faster.
@export var auto_follow_min_speed: float = 1.0 ## Target speed (m/s) below which nothing happens.

@export_group("Zoom")
@export var min_distance: float = 4.0
@export var max_distance: float = 45.0
@export var zoom_step: float = 2.5
@export var zoom_smoothing: float = 10.0

@export_group("Pan")
@export var pan_sensitivity: float = 0.0015 ## Scaled by current distance.
@export var bounds: Rect2 = Rect2(-28.0, -28.0, 56.0, 56.0) ## Pivot limits on the XZ plane.

@export_group("Initial view")
@export var distance: float = 14.0
@export var pitch_deg: float = -35.0

var _current_distance: float
var _time_since_manual_rotation: float = INF

@onready var _pitch: Node3D = $Pitch
@onready var _camera: Camera3D = $Pitch/Camera3D


func _ready() -> void:
	distance = clampf(distance, min_distance, max_distance)
	_current_distance = distance
	_apply_pitch()
	_camera.position = Vector3(0.0, 0.0, _current_distance)
	if target:
		global_position = _target_point()


func _process(delta: float) -> void:
	_current_distance = lerpf(_current_distance, distance, 1.0 - exp(-zoom_smoothing * delta))
	_camera.position.z = _current_distance
	_time_since_manual_rotation += delta
	var key_axis := Input.get_axis("camera_rotate_right", "camera_rotate_left")
	if key_axis != 0.0:
		rotation.y += deg_to_rad(key_axis * keyboard_rotate_speed * delta)
		_time_since_manual_rotation = 0.0
	if target:
		global_position = global_position.lerp(_target_point(), 1.0 - exp(-follow_smoothing * delta))
		_auto_follow(delta)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var motion := event as InputEventMouseMotion
		var panning := Input.is_action_pressed("camera_pan") or (motion.shift_pressed and Input.is_action_pressed("camera_rotate"))
		if panning:
			if target == null:
				_pan(motion.relative)
		elif Input.is_action_pressed("camera_rotate"):
			_rotate(motion.relative)
	elif event.is_action_pressed("camera_zoom_in"):
		_zoom(-zoom_step)
	elif event.is_action_pressed("camera_zoom_out"):
		_zoom(zoom_step)
	elif event is InputEventMagnifyGesture:
		# Trackpad pinch: factor > 1 means fingers spreading, i.e. zoom in.
		distance = clampf(distance / (event as InputEventMagnifyGesture).factor, min_distance, max_distance)
	elif event is InputEventPanGesture:
		# Trackpad two-finger scroll.
		_zoom((event as InputEventPanGesture).delta.y * zoom_step * 0.5)


func _rotate(relative: Vector2) -> void:
	_time_since_manual_rotation = 0.0
	rotation.y -= deg_to_rad(relative.x * rotate_sensitivity)
	pitch_deg -= relative.y * rotate_sensitivity
	_apply_pitch()


func _pan(relative: Vector2) -> void:
	# The pivot only has yaw, so its basis stays horizontal.
	var right: Vector3 = global_basis.x
	var forward: Vector3 = -global_basis.z
	var offset := (-right * relative.x + forward * relative.y) * pan_sensitivity * _current_distance
	position.x = clampf(position.x + offset.x, bounds.position.x, bounds.end.x)
	position.z = clampf(position.z + offset.z, bounds.position.y, bounds.end.y)


func _zoom(amount: float) -> void:
	distance = clampf(distance + amount, min_distance, max_distance)


func _auto_follow(delta: float) -> void:
	var body := target as CharacterBody3D
	if not auto_follow_enabled or body == null or _time_since_manual_rotation < auto_follow_delay:
		return
	var move := Vector2(body.velocity.x, body.velocity.z)
	if move.length() < auto_follow_min_speed:
		return
	var move_dir := move.normalized()
	var view_dir := Vector2(-sin(rotation.y), -cos(rotation.y))
	# Only swing when walking away from the camera: strafing or walking toward it
	# would otherwise make the camera (and so the controls) spin.
	var alignment := maxf(move_dir.dot(view_dir), 0.0)
	var target_yaw := atan2(-move_dir.x, -move_dir.y)
	rotation.y = lerp_angle(rotation.y, target_yaw, (1.0 - exp(-auto_follow_speed * delta)) * alignment)


func _target_point() -> Vector3:
	# Interpolated transform: the target moves in physics ticks, the camera every frame.
	return target.get_global_transform_interpolated().origin + Vector3.UP * target_height


func _apply_pitch() -> void:
	pitch_deg = clampf(pitch_deg, min_pitch_deg, max_pitch_deg)
	_pitch.rotation.x = deg_to_rad(pitch_deg)
