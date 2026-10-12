extends Node
## Loads game content from data/*.json and exposes it by id.
## Note for exports: the data/*.json files must be added to the export filters (non-resource files).

const DATA_DIR := "res://data/"

var items: Dictionary = {}
var harvestables: Dictionary = {}
var buildables: Dictionary = {}
var crops: Dictionary = {}
var time_settings: Dictionary = {} ## data/temps.json: day length, dawn and dusk hours, periods.
var sounds: Dictionary = {} ## data/sons.json: ambience loops and sound effect events.


func _ready() -> void:
	items = _load_collection("items.json")
	harvestables = _load_collection("harvestables.json")
	buildables = _load_collection("buildables.json")
	crops = _load_collection("crops.json")
	time_settings = _load_object("temps.json")
	sounds = _load_object("sons.json")
	_validate()


func get_item(id: String) -> Dictionary:
	return items.get(id, {})


func get_harvestable(id: String) -> Dictionary:
	return harvestables.get(id, {})


func get_buildable(id: String) -> Dictionary:
	return buildables.get(id, {})


func get_crop(id: String) -> Dictionary:
	return crops.get(id, {})


## The crop grown from a seed item, or an empty dictionary.
func crop_for_seed(seed_id: String) -> Dictionary:
	for crop: Dictionary in crops.values():
		if crop.get("graine") == seed_id:
			return crop
	return {}


## A cost or drop list as readable text, e.g. "2 herbes, 1 compost".
func describe(lines: Array) -> String:
	var parts: PackedStringArray = []
	for line: Dictionary in lines:
		parts.append("%d %s" % [int(line.qte), item_name(line.item).to_lower()])
	return ", ".join(parts)


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


func _load_object(file_name: String) -> Dictionary:
	var path := DATA_DIR + file_name
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary:
		push_error("GameData: %s must contain a JSON object" % path)
		return {}
	return parsed


func _validate() -> void:
	# Catch broken references early, with a readable message.
	for harvestable: Dictionary in harvestables.values():
		_check_items(harvestable.get("recolte", []), "harvestable '%s'" % harvestable.id)
	for buildable: Dictionary in buildables.values():
		var context := "buildable '%s'" % buildable.id
		_check_items(buildable.get("cout", []), context)
		var composting: Dictionary = buildable.get("compostage", {})
		_check_items(composting.get("entree", []) + composting.get("sortie", []), context)
		if buildable.has("arrosage"):
			_check_items([buildable.arrosage], context)
		for step: Dictionary in buildable.get("preparation", {}).values():
			_check_items(step.get("cout", []) + step.get("recolte", []), context)
		if not ResourceLoader.exists(buildable.get("scene", "")):
			push_error("GameData: %s has no scene at '%s'" % [context, buildable.get("scene", "")])
	for crop: Dictionary in crops.values():
		var context := "crop '%s'" % crop.id
		_check_items(crop.get("recolte", []) + [{"item": crop.get("graine", "")}], context)
		if not ResourceLoader.exists(crop.get("modele_plant", "")):
			push_error("GameData: %s has no plant model at '%s'" % [context, crop.get("modele_plant", "")])


func _check_items(lines: Array, context: String) -> void:
	for line: Dictionary in lines:
		if not items.has(line.get("item", "")):
			push_error("GameData: %s refers to unknown item '%s'" % [context, line.get("item", "")])
