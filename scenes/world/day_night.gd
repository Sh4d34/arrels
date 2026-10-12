@tool
class_name DayNight
extends Node
## Drives the sun, the moon, the sky, the ambient light and the fog from the hour.
## Colors and intensities are Gradients and Curves sampled over 24 hours (0.0 = midnight,
## 0.5 = noon), editable in the inspector. In the editor, preview_hour shows any time of day.
## Orientation reminder: -Z is south, +X is west, so the sun rises at -X.

@export var sun: DirectionalLight3D
@export var moon: DirectionalLight3D
@export var world_environment: WorldEnvironment
@export_range(0.0, 24.0, 0.25) var preview_hour: float = 16.0 ## Editor only.

@export_group("Course")
@export var dawn_hour: float = 6.0 ## Editor fallback; the game uses data/temps.json.
@export var dusk_hour: float = 21.0
@export var sun_max_elevation_deg: float = 62.0
@export var moon_max_elevation_deg: float = 48.0
@export var min_light_elevation_deg: float = 4.0 ## Keeps shadows sane near the horizon.

@export_group("Sun")
@export var sun_color: Gradient
@export var sun_energy: Curve
@export var sun_max_energy: float = 1.6

@export_group("Moon")
@export var moon_energy: Curve
@export var moon_max_energy: float = 0.35

@export_group("Sky")
@export var sky_top: Gradient
@export var sky_horizon: Gradient
@export var sky_ground: Gradient
@export var stars: Curve

@export_group("Ambient and fog")
@export var ambient_color: Gradient
@export var ambient_energy: Curve
@export var ambient_max_energy: float = 0.6
@export var fog_color: Gradient


func _process(_delta: float) -> void:
	if not (sun and moon and world_environment):
		return
	if Engine.is_editor_hint():
		apply(preview_hour, dawn_hour, dusk_hour)
	else:
		apply(TimeManager.hour(), TimeManager.dawn_hour, TimeManager.dusk_hour)


func apply(hour: float, dawn: float, dusk: float) -> void:
	var x := hour / 24.0
	var sun_dir := _sun_direction(hour, dawn, dusk)
	var moon_dir := _moon_direction(hour, dawn, dusk)

	sun.light_color = sun_color.sample(x)
	sun.light_energy = sun_energy.sample(x) * sun_max_energy
	sun.shadow_enabled = sun.light_energy > 0.02
	sun.basis = Basis.looking_at(-sun_dir)
	moon.light_energy = moon_energy.sample(x) * moon_max_energy
	moon.basis = Basis.looking_at(-moon_dir)

	var environment := world_environment.environment
	environment.ambient_light_color = ambient_color.sample(x)
	environment.ambient_light_energy = ambient_energy.sample(x) * ambient_max_energy
	environment.fog_light_color = fog_color.sample(x)

	var sky := environment.sky.sky_material as ShaderMaterial
	var horizon := sky_horizon.sample(x)
	sky.set_shader_parameter("top_color", sky_top.sample(x))
	sky.set_shader_parameter("horizon_color", horizon)
	sky.set_shader_parameter("ground_horizon_color", horizon.darkened(0.1))
	sky.set_shader_parameter("ground_bottom_color", sky_ground.sample(x))
	sky.set_shader_parameter("sun_direction", sun_dir)
	sky.set_shader_parameter("sun_color", sun.light_color)
	sky.set_shader_parameter("sun_intensity", sun_energy.sample(x))
	sky.set_shader_parameter("moon_direction", moon_dir)
	sky.set_shader_parameter("moon_intensity", moon_energy.sample(x))
	sky.set_shader_parameter("star_visibility", stars.sample(x))
	sky.set_shader_parameter("twinkle_time", Time.get_ticks_msec() * 0.001)


## Direction toward the sun: rises in the east, culminates in the south, sets in the west.
func _sun_direction(hour: float, dawn: float, dusk: float) -> Vector3:
	var t := (hour - dawn) / (dusk - dawn)
	if t < 0.0 or t > 1.0:
		return _sky_direction(t, -20.0) # Below the horizon at night.
	return _sky_direction(t, maxf(sun_max_elevation_deg * sin(PI * t), min_light_elevation_deg))


## Direction toward the moon, crossing the sky during the night.
func _moon_direction(hour: float, dawn: float, dusk: float) -> Vector3:
	var night_hours := 24.0 - (dusk - dawn)
	var t := fposmod(hour - dusk, 24.0) / night_hours
	if t > 1.0:
		return _sky_direction(t, -20.0)
	return _sky_direction(t, maxf(moon_max_elevation_deg * sin(PI * t), min_light_elevation_deg))


## t goes from 0 (east) through 0.5 (south) to 1 (west).
func _sky_direction(t: float, elevation_deg: float) -> Vector3:
	var azimuth := PI * clampf(t, 0.0, 1.0)
	var horizontal := Vector3(-cos(azimuth), 0.0, -sin(azimuth))
	var elevation := deg_to_rad(elevation_deg)
	return (horizontal * cos(elevation) + Vector3.UP * sin(elevation)).normalized()
