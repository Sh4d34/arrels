extends Node
## Plays one-shot sound effects by event name, in 3D at the place of the action.
## Events, files, volumes and pitch variation come from the "evenements" of data/sons.json.
## An event without files is simply silent, so sounds can be added later without code changes.

const POOL_SIZE := 12
const BUS := &"Effets"

var _events: Dictionary = {} ## name -> {"streams": Array[AudioStream], "volume_db": float, "pitch": float}
var _players: Array[AudioStreamPlayer3D] = []
var _next: int = 0


func _ready() -> void:
	var events: Dictionary = GameData.sounds.get("evenements", {})
	for event_name: String in events:
		var entry: Dictionary = events[event_name]
		var streams: Array[AudioStream] = []
		for path: String in entry.get("fichiers", []):
			if ResourceLoader.exists(path):
				streams.append(load(path))
			else:
				push_warning("Sfx: missing sound '%s' for event '%s'" % [path, event_name])
		_events[event_name] = {
			"streams": streams,
			"volume_db": float(entry.get("volume_db", 0.0)),
			"pitch": float(entry.get("variation_hauteur", 0.0)),
		}
	for i in POOL_SIZE:
		var player := AudioStreamPlayer3D.new()
		player.bus = BUS
		player.unit_size = 6.0
		player.max_distance = 45.0
		add_child(player)
		_players.append(player)


## Plays a random sound of the event at a world position. Unknown or empty events are silent.
func play(event_name: String, at: Vector3) -> void:
	var entry: Dictionary = _events.get(event_name, {})
	if entry.is_empty() or entry.streams.is_empty():
		return
	var player := _players[_next]
	_next = (_next + 1) % POOL_SIZE
	player.stream = entry.streams.pick_random()
	player.global_position = at
	player.volume_db = entry.volume_db
	player.pitch_scale = 1.0 + randf_range(-entry.pitch, entry.pitch)
	player.play()


func has_sound(event_name: String) -> bool:
	return not _events.get(event_name, {}).get("streams", []).is_empty()
