extends Node
## Background music, kept light: a track fades in, plays once, then a silence lets the ambience
## breathe before the next one. Day and night have their own tracks (each falls back on the other).
## Settings and track lists come from the "musique" entry of data/sons.json. M toggles the music.

signal toggled(enabled: bool)

const BUS := &"Musique"
const SILENT_DB := -60.0

var enabled: bool = true

var _settings: Dictionary
var _tracks: Dictionary = {"jour": [], "nuit": []} ## Loaded AudioStreams per part of the day.
var _player := AudioStreamPlayer.new()
var _last_track: AudioStream
var _wait: SceneTreeTimer
var _fade: Tween


func _ready() -> void:
	_settings = GameData.sounds.get("musique", {})
	for part: String in _tracks:
		for path: String in _settings.get(part, []):
			if ResourceLoader.exists(path):
				_tracks[part].append(load(path))
			else:
				push_warning("Music: missing track '%s'" % path)
	_player.bus = BUS
	add_child(_player)
	_player.finished.connect(func() -> void: _schedule_next(_silence()))
	_schedule_next(float(_settings.get("premier_morceau_secondes", 20.0)))


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_music"):
		set_enabled(not enabled)
		get_viewport().set_input_as_handled()


func set_enabled(value: bool) -> void:
	enabled = value
	if enabled:
		_schedule_next(2.0)
	else:
		_fade_to(SILENT_DB).tween_callback(_player.stop)
	toggled.emit(enabled)


func _schedule_next(delay: float) -> void:
	_wait = get_tree().create_timer(delay)
	var this_wait := _wait
	# Only the latest schedule may start a track (toggling M reschedules).
	_wait.timeout.connect(func() -> void:
		if this_wait == _wait:
			_play_next())


func _play_next() -> void:
	if not enabled or _player.playing:
		return
	var part := "nuit" if TimeManager.is_night() else "jour"
	var pool: Array = _tracks[part] if not _tracks[part].is_empty() else _tracks["nuit" if part == "jour" else "jour"]
	if pool.is_empty():
		return # No music installed: stay silent.
	var choices := pool.filter(func(track: AudioStream) -> bool: return track != _last_track)
	_last_track = (choices if not choices.is_empty() else pool).pick_random()
	_player.stream = _last_track
	_player.volume_db = SILENT_DB
	_player.play()
	_fade_to(float(_settings.get("volume_db", -20.0)))


func _fade_to(volume_db: float) -> Tween:
	if _fade:
		_fade.kill()
	_fade = create_tween()
	_fade.tween_property(_player, "volume_db", volume_db, float(_settings.get("fondu_secondes", 4.0)))
	return _fade


func _silence() -> float:
	return randf_range(float(_settings.get("silence_min_secondes", 60.0)), float(_settings.get("silence_max_secondes", 180.0)))
