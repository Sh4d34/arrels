extends Node
## Game calendar: counts days, each lasting day_length real seconds.
## Jalon 6 will add the sun course and the sky changes on top of it.

signal new_day(day: int)

## Length of a game day, in real seconds.
var day_length: float = 120.0
var day: int = 1

var _elapsed: float = 0.0


func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed >= day_length:
		_elapsed -= day_length
		advance_day()


func advance_day() -> void:
	day += 1
	new_day.emit(day)


## Progress through the current day, from 0.0 (dawn) to 1.0.
func day_progress() -> float:
	return _elapsed / day_length


func _unhandled_input(event: InputEvent) -> void:
	# Testing shortcut, only in development builds.
	if OS.is_debug_build() and event.is_action_pressed("debug_next_day"):
		_elapsed = 0.0
		advance_day()
		get_viewport().set_input_as_handled()
