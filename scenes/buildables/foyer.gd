class_name Campfire
extends StaticBody3D
## A ring of stones where a fire is prepared (kindling and logs), lit with a match, fed with logs,
## and left to die down into embers. Rules come from the "feu" entry of data/buildables.json;
## durations are in game hours, so a fire lasts about a night.

enum State { EMPTY, PREPARED, BURNING, EMBERS }

@export var buildable_id: String = "foyer"
@export var light_energy: float = 2.4
@export var embers_light_energy: float = 0.35
@export var flicker_amount: float = 0.25
@export var flicker_speed: float = 9.0

var state: State = State.EMPTY

var _rules: Dictionary
var _burn_until: float = 0.0 ## TimeManager.total_hours() when the fire dies down.
var _embers_until: float = 0.0
var _flicker_noise := FastNoiseLite.new()

@onready var _wood: Node3D = $Wood
@onready var _embers: Node3D = $Embers
@onready var _flames: CPUParticles3D = $Flames
@onready var _smoke: CPUParticles3D = $Smoke
@onready var _light: OmniLight3D = $Light
@onready var _crackle: AudioStreamPlayer3D = $Crackle


func _ready() -> void:
	_rules = GameData.get_buildable(buildable_id).get("feu", {})
	set_meta("interactable", self)
	add_to_group(Harvestable.INTERACTABLE_GROUP)
	var loop: Dictionary = GameData.sounds.get("ambiances", {}).get("feu", {})
	if ResourceLoader.exists(loop.get("fichier", "")):
		var stream: AudioStreamWAV = load(loop.fichier)
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_end = int(stream.get_length() * stream.mix_rate)
		_crackle.stream = stream
		_crackle.volume_db = float(loop.get("volume_db", 0.0))
	_refresh()


func _process(_delta: float) -> void:
	var now := TimeManager.total_hours()
	match state:
		State.BURNING:
			if now >= _burn_until:
				state = State.EMBERS
				_embers_until = _burn_until + float(_rules.get("braises_heures", 1.0))
				_refresh()
			else:
				var flicker := _flicker_noise.get_noise_1d(Time.get_ticks_msec() * 0.001 * flicker_speed * 10.0)
				_light.light_energy = light_energy * (1.0 + flicker * flicker_amount)
		State.EMBERS:
			if now >= _embers_until:
				state = State.EMPTY
				_refresh()


# --- Interaction interface.

func get_interaction_prompt() -> String:
	return _current_action().prompt


func get_interaction_hint() -> String:
	return _current_action().hint


func can_interact() -> bool:
	return _current_action().possible


func interact(_actor: Node3D) -> void:
	var action := _current_action()
	if not action.possible:
		return
	Sfx.play(action.id, global_position)
	var now := TimeManager.total_hours()
	match action.id:
		"preparer":
			Inventory.remove_all(_step("preparation").get("cout", []))
			state = State.PREPARED
		"allumer":
			Inventory.remove_all(_step("allumage").get("cout", []))
			_burn_until = now + float(_rules.get("duree_heures", 6.0))
			state = State.BURNING
		"ajouter":
			Inventory.remove_all(_step("ajout").get("cout", []))
			_burn_until += float(_step("ajout").get("heures", 1.0))
	_refresh()


## Hours of fire left, rounded up (0 when not burning).
func hours_left() -> int:
	return ceili(_burn_until - TimeManager.total_hours()) if state == State.BURNING else 0


func _current_action() -> Dictionary:
	match state:
		State.PREPARED:
			var match_cost: Array = _step("allumage").get("cout", [])
			var hint: String = _step("allumage").get("carnet", "")
			if Inventory.has_all(match_cost):
				return _action("allumer", GameData.text("foyer.allumer"), true, hint)
			return _action("allumer", GameData.text("foyer.sans_allumette"), false, hint)
		State.BURNING:
			var hint := GameData.text("foyer.reste", {"n": hours_left()})
			if Inventory.has_all(_step("ajout").get("cout", [])):
				return _action("ajouter", GameData.text("foyer.ajouter"), true, hint)
			return _action("ajouter", GameData.text("foyer.brule"), false, hint)
		_:
			var cost: Array = _step("preparation").get("cout", [])
			var hint: String = _step("preparation").get("carnet", "")
			if Inventory.has_all(cost):
				return _action("preparer", GameData.text("foyer.preparer", {"cout": GameData.describe(cost)}), true, hint)
			return _action("preparer", GameData.text("foyer.preparer_manque", {"cout": GameData.describe(cost)}), false, hint)


func _action(id: String, prompt: String, possible: bool, hint: String) -> Dictionary:
	return {"id": id, "prompt": prompt, "possible": possible, "hint": hint}


func _step(id: String) -> Dictionary:
	return _rules.get(id, {})


func _refresh() -> void:
	var burning := state == State.BURNING
	_wood.visible = state == State.PREPARED or burning
	_embers.visible = state == State.EMBERS or burning
	_flames.emitting = burning
	_smoke.emitting = burning or state == State.EMBERS
	_light.visible = burning or state == State.EMBERS
	_light.light_energy = light_energy if burning else embers_light_energy
	if burning and not _crackle.playing:
		_crackle.play()
	elif not burning:
		_crackle.stop()
