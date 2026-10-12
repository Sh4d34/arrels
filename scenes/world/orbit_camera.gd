class_name OrbitCamera
extends Node3D
## Orbit camera around a ground pivot.
## Right drag: rotate. Middle drag or Shift + right drag: pan. Wheel / pinch: zoom.

@export_group("Rotation")
@export var rotate_sensitivity: float = 0.3 ## Degrees per pixel.
@export_range(-89.0, 0.0) var min_pitch_deg: float = -80.0
@export_range(-89.0, 0.0) var max_pitch_deg: float = -6.0

@export_group("Zoom")
@export var min_distance: float = 6.0
@export var max_distance: float = 45.0
@export var zoom_step: float = 2.5
@export var zoom_smoothing: float = 10.0

@export_group("Pan")
@export var pan_sensitivity: float = 0.0015 ## Scaled by current distance.
@export var bounds: Rect2 = Rect2(-28.0, -28.0, 56.0, 56.0) ## Pivot limits on the XZ plane.

@export_group("Initial view")
@export var distance: float = 30.0
@export var pitch_deg: float = -45.0

var _current_distance: float

@onready var _pitch: Node3D = $Pitch
@onready var _camera: Camera3D = $Pitch/Camera3D


func _ready() -> void:
	distance = clampf(distance, min_distance, max_distance)
	_current_distance = distance
	_apply_pitch()
	_camera.position = Vector3(0.0, 0.0, _current_distance)


func _process(delta: float) -> void:
	_current_distance = lerpf(_current_distance, distance, 1.0 - exp(-zoom_smoothing * delta))
	_camera.position.z = _current_distance


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var motion := event as InputEventMouseMotion
		if Input.is_action_pressed("camera_pan") or (motion.shift_pressed and Input.is_action_pressed("camera_rotate")):
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


func _apply_pitch() -> void:
	pitch_deg = clampf(pitch_deg, min_pitch_deg, max_pitch_deg)
	_pitch.rotation.x = deg_to_rad(pitch_deg)
