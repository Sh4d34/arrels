class_name Composter
extends StaticBody3D
## Turns green waste into compost: each deposited batch is ready after a few days.
## Rules come from the "compostage" entry of data/buildables.json.

@export var buildable_id: String = "composteur"
@export var empty_level: float = 0.25 ## Compost height scale when empty.
@export var level_per_batch: float = 0.3

var _rules: Dictionary
var _batches: Array[int] = [] ## Day each batch was started.

@onready var _compost: Node3D = $Visual/Compost


func _ready() -> void:
	_rules = GameData.get_buildable(buildable_id).get("compostage", {})
	set_meta("interactable", self)
	add_to_group(Harvestable.INTERACTABLE_GROUP)
	TimeManager.new_day.connect(func(_day: int) -> void: _refresh_visual())
	_refresh_visual()


func get_interaction_prompt() -> String:
	return _current_action().prompt


func get_interaction_hint() -> String:
	return _rules.get("carnet", "")


## The player's gesture for this action (see the "gestes" of data/personnages.json).
func get_interaction_gesture() -> String:
	return _rules.get("geste", "interagir")


func can_interact() -> bool:
	return _current_action().possible


func interact(_actor: Node3D) -> void:
	var action := _current_action()
	if not action.possible:
		return
	Sfx.play(action.id, global_position)
	if action.id == "recuperer":
		var ready_count := ready_batches()
		for i in ready_count:
			_batches.pop_front()
		for line: Dictionary in _rules.get("sortie", []):
			Inventory.add(line.item, int(line.qte) * ready_count)
	else:
		Inventory.remove_all(_rules.get("entree", []))
		_batches.append(TimeManager.day)
	Events.action_done.emit(action.id, buildable_id)
	_refresh_visual()


## Batches old enough to be collected. They are started in order, so they ripen in order.
func ready_batches() -> int:
	var count := 0
	for start_day in _batches:
		if TimeManager.day - start_day >= int(_rules.get("jours", 1)):
			count += 1
	return count


func _current_action() -> Dictionary:
	var input: Array = _rules.get("entree", [])
	if ready_batches() > 0:
		return {"id": "recuperer", "prompt": GameData.text("composteur.recuperer"), "possible": true}
	if _batches.size() < int(_rules.get("lots_max", 1)) and Inventory.has_all(input):
		return {"id": "deposer", "prompt": GameData.text("composteur.deposer", {"entree": GameData.describe(input)}), "possible": true}
	if not _batches.is_empty():
		var days_left := int(_rules.get("jours", 1)) - (TimeManager.day - _batches[0])
		return {"id": "attendre", "prompt": GameData.text("composteur.murit", {"n": days_left}), "possible": false}
	return {"id": "deposer", "prompt": GameData.text("composteur.manque", {"entree": GameData.describe(input)}), "possible": false}


func _refresh_visual() -> void:
	_compost.scale.y = empty_level + level_per_batch * _batches.size()
	_compost.position.y = 0.21 * _compost.scale.y
