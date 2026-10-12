class_name Ambience
extends Node3D
## Ambient sound loops: the river (3D, from the water closest to the player), the wind,
## birds during the day and crickets at night, crossfading with the hour.
## Files and volumes come from the "ambiances" of data/sons.json.

const BUS := &"Ambiance"
const SILENT_DB := -60.0

@export var terrain: Terrain
@export var player: Node3D
@export var crossfade_hours: float = 1.5 ## Birds and crickets fade over this time around dawn and dusk.
@export var river_unit_size: float = 8.0

var _river: AudioStreamPlayer3D
var _wind: AudioStreamPlayer
var _birds: AudioStreamPlayer
var _crickets: AudioStreamPlayer
var _volumes: Dictionary = {} ## Loop name -> full volume in dB.


func _ready() -> void:
	_river = AudioStreamPlayer3D.new()
	_river.unit_size = river_unit_size
	_river.max_distance = 60.0
	_river.bus = BUS
	add_child(_river)
	_wind = _make_player()
	_birds = _make_player()
	_crickets = _make_player()
	_start(_river, "riviere")
	_start(_wind, "vent")
	_start(_birds, "oiseaux")
	_start(_crickets, "grillons")


func _process(_delta: float) -> void:
	# The river sounds from the middle of the water, level with the player.
	var z := player.global_position.z
	var x := terrain.river_center_x(z)
	_river.global_position = Vector3(x, terrain.surface_height_at(x, z) + 0.5, z)
	var day := _daylight_factor(TimeManager.hour())
	_birds.volume_db = _faded_db("oiseaux", day)
	_crickets.volume_db = _faded_db("grillons", 1.0 - day)


## 1.0 in full daylight, 0.0 at night, with smooth transitions around dawn and dusk.
func _daylight_factor(hour: float) -> float:
	var half := crossfade_hours * 0.5
	var rise := smoothstep(TimeManager.dawn_hour - half, TimeManager.dawn_hour + half, hour)
	var fall := 1.0 - smoothstep(TimeManager.dusk_hour - half, TimeManager.dusk_hour + half, hour)
	return minf(rise, fall)


func _faded_db(loop: String, factor: float) -> float:
	return lerpf(SILENT_DB, _volumes.get(loop, 0.0), sqrt(clampf(factor, 0.0, 1.0)))


func _make_player() -> AudioStreamPlayer:
	var player_ := AudioStreamPlayer.new()
	player_.bus = BUS
	add_child(player_)
	return player_


func _start(audio_player: Node, loop: String) -> void:
	var entry: Dictionary = GameData.sounds.get("ambiances", {}).get(loop, {})
	var path: String = entry.get("fichier", "")
	if not ResourceLoader.exists(path):
		push_warning("Ambience: missing loop '%s'" % path)
		return
	var stream: AudioStream = load(path)
	if stream is AudioStreamWAV:
		# Loop the whole file: the generated loops are seamless.
		var wav := stream as AudioStreamWAV
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 0
		wav.loop_end = wav.get_length() * wav.mix_rate
	_volumes[loop] = float(entry.get("volume_db", 0.0))
	audio_player.set("stream", stream)
	audio_player.set("volume_db", _volumes[loop])
	audio_player.call("play")

