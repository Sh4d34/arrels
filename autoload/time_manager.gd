extends Node
## Game clock. A day starts at dawn; daylight and night share the real day length unevenly,
## so nights pass faster. Settings come from data/temps.json.

signal new_day(day: int)
signal hour_changed(hour: int) ## Emitted on every whole hour.

## Debug builds only: hold the key to speed time up by this factor.
const FAST_TIME_FACTOR := 20.0

var day: int = 1
var day_length: float = 120.0 ## Real seconds for a whole day, night included.
var night_share: float = 0.25 ## Part of day_length spent at night.
var dawn_hour: float = 6.0
var dusk_hour: float = 21.0

var _elapsed: float = 0.0 ## Real seconds since dawn.
var _last_whole_hour: int = -1
var _periods: Array = []


func _ready() -> void:
	var settings: Dictionary = GameData.time_settings
	day_length = float(settings.get("duree_jour_secondes", day_length))
	night_share = float(settings.get("part_nuit", night_share))
	dawn_hour = float(settings.get("heure_aube", dawn_hour))
	dusk_hour = float(settings.get("heure_crepuscule", dusk_hour))
	_periods = settings.get("periodes", [])
	set_hour(float(settings.get("heure_depart", dawn_hour)))


func _process(delta: float) -> void:
	var speed := 1.0
	if OS.is_debug_build() and Input.is_action_pressed("debug_fast_time"):
		speed = FAST_TIME_FACTOR
	_elapsed += delta * speed
	if _elapsed >= day_length:
		_elapsed -= day_length
		advance_day()
	var whole_hour := int(hour())
	if whole_hour != _last_whole_hour:
		_last_whole_hour = whole_hour
		hour_changed.emit(whole_hour)


func advance_day() -> void:
	day += 1
	new_day.emit(day)


## Current hour, from 0.0 to 24.0.
func hour() -> float:
	var daylight := _daylight_seconds()
	if _elapsed < daylight:
		return dawn_hour + _elapsed / daylight * (dusk_hour - dawn_hour)
	var night_hours := 24.0 - (dusk_hour - dawn_hour)
	return fposmod(dusk_hour + (_elapsed - daylight) / (day_length - daylight) * night_hours, 24.0)


## Hours elapsed since the start of day 1 at midnight: a clock that never wraps.
func total_hours() -> float:
	var h := hour()
	# Hours after midnight but before dawn belong to the night that started the previous evening.
	var day_index := day if h >= dawn_hour else day + 1
	return (day_index - 1) * 24.0 + h


func is_night() -> bool:
	return _elapsed >= _daylight_seconds()


## Moves the clock to an hour of the current day (hours before dawn belong to the night's end).
func set_hour(target_hour: float) -> void:
	var daylight := _daylight_seconds()
	if target_hour >= dawn_hour and target_hour < dusk_hour:
		_elapsed = (target_hour - dawn_hour) / (dusk_hour - dawn_hour) * daylight
	else:
		var night_hours := 24.0 - (dusk_hour - dawn_hour)
		_elapsed = daylight + fposmod(target_hour - dusk_hour, 24.0) / night_hours * (day_length - daylight)


## Name of the current part of the day ("matin", "nuit"...), from data/temps.json.
func period_name() -> String:
	var name := ""
	for period: Dictionary in _periods:
		if hour() >= float(period.get("debut", 0.0)):
			name = period.get("nom", "")
	return name


func _daylight_seconds() -> float:
	return day_length * (1.0 - night_share)


func _unhandled_input(event: InputEvent) -> void:
	# Testing shortcut, only in development builds: jump to the next dawn.
	if OS.is_debug_build() and event.is_action_pressed("debug_next_day"):
		_elapsed = 0.0
		advance_day()
		get_viewport().set_input_as_handled()
