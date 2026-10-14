extends Node
## The thread of projects from data/projets.json: one current project at a time, guiding the player.
## Progress counts every action since the start of the game, so a step done ahead of time
## completes its project as soon as it becomes current.

signal project_changed(project: Dictionary) ## The new current project, empty once all are done.
signal project_completed(project: Dictionary)

## Objective action fed by inventory gains rather than by Events.
const GAIN_ACTION := "obtenir"

var _counts: Dictionary[String, int] = {} ## "action:target" -> times done (or items gained).
var _index := 0
var _known_quantities: Dictionary[String, int] = {}


func _ready() -> void:
	Events.action_done.connect(_on_action_done)
	Inventory.changed.connect(_on_inventory_changed)


## The current project, or an empty dictionary once every project is done.
func current() -> Dictionary:
	return GameData.projects[_index] if _index < GameData.projects.size() else {}


## How far the current project's objective is, from 0 to its "nombre".
func progress() -> int:
	var objective: Dictionary = current().get("objectif", {})
	return mini(count(objective.get("action", ""), objective.get("cible", "")), goal())


## How many times the current project's objective must be reached.
func goal() -> int:
	return int(current().get("objectif", {}).get("nombre", 1))


func count(action: String, target_id: String) -> int:
	return _counts.get("%s:%s" % [action, target_id], 0)


## Back to the first project with nothing counted (new game, tests).
func reset() -> void:
	_counts.clear()
	_index = 0
	_known_quantities = Inventory.get_all()
	project_changed.emit(current())


func _on_action_done(action: String, target_id: String) -> void:
	_add(action, target_id, 1)


func _on_inventory_changed(item_id: String, quantity: int) -> void:
	var gained: int = quantity - _known_quantities.get(item_id, 0)
	_known_quantities[item_id] = quantity
	if gained > 0:
		_add(GAIN_ACTION, item_id, gained)


func _add(action: String, target_id: String, amount: int) -> void:
	var key := "%s:%s" % [action, target_id]
	_counts[key] = _counts.get(key, 0) + amount
	_advance()


## Completes the current project while its objective is reached, possibly several in a row.
func _advance() -> void:
	var completed := false
	while not current().is_empty() and progress() >= goal():
		project_completed.emit(current())
		_index += 1
		completed = true
	if completed:
		project_changed.emit(current())
