extends Node
## Loads game content from data/*.json and exposes it by id.
## Note for exports: the data/*.json files must be added to the export filters (non-resource files).

const DATA_DIR := "res://data/"

var items: Dictionary = {}
var harvestables: Dictionary = {}


func _ready() -> void:
	items = _load_collection("items.json")
	harvestables = _load_collection("harvestables.json")
	_validate()


func get_item(id: String) -> Dictionary:
	return items.get(id, {})


func get_harvestable(id: String) -> Dictionary:
	return harvestables.get(id, {})


## Display name of an item, falling back to its id.
func item_name(id: String) -> String:
	return get_item(id).get("nom", id)


func _load_collection(file_name: String) -> Dictionary:
	var path := DATA_DIR + file_name
	var text := FileAccess.get_file_as_string(path)
	if text.is_empty():
		push_error("GameData: cannot read %s" % path)
		return {}
	var parsed: Variant = JSON.parse_string(text)
	if not parsed is Array:
		push_error("GameData: %s must contain a JSON array" % path)
		return {}
	var result := {}
	for entry: Variant in parsed:
		if not entry is Dictionary or not entry.has("id"):
			push_error("GameData: entry without id in %s" % path)
			continue
		if result.has(entry.id):
			push_error("GameData: duplicate id '%s' in %s" % [entry.id, path])
		result[entry.id] = entry
	return result


func _validate() -> void:
	# Catch broken references early, with a readable message.
	for harvestable: Dictionary in harvestables.values():
		for drop: Dictionary in harvestable.get("recolte", []):
			if not items.has(drop.get("item", "")):
				push_error("GameData: harvestable '%s' drops unknown item '%s'" % [harvestable.id, drop.get("item", "")])
