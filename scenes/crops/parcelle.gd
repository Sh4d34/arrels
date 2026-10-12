class_name Parcel
extends StaticBody3D
## A vegetable plot on the build grid. The player prepares it step by step (weed, loosen,
## optional compost, mulch), then sows, waters and harvests. Rules and texts come from the
## "parcelle" entry of data/buildables.json and from data/crops.json.
## Lies on collision layer 2 only: the player walks over it, but building checks still see it.

enum Stage { GRASS, WEEDED, LOOSENED, MULCHED, SOWN }

@export var buildable_id: String = "parcelle"
@export var grass_tuft: PackedScene

@export_group("Colors")
@export var grass_color: Color = Color(0.36, 0.5, 0.24)
@export var soil_color: Color = Color(0.45, 0.33, 0.22)
@export var loosened_color: Color = Color(0.36, 0.25, 0.17)
@export var compost_color: Color = Color(0.22, 0.15, 0.1)
@export var mulch_color: Color = Color(0.72, 0.58, 0.38)
@export var stake_color: Color = Color(0.4, 0.29, 0.19)
@export var leaf_color: Color = Color(0.35, 0.6, 0.25)
@export_range(0.0, 1.0) var wet_darkening: float = 0.35

var stage: Stage = Stage.GRASS
var composted: bool = false
var crop_id: String = ""
var days_grown: int = 0
var last_watered_day: int = -1000

var _rules: Dictionary
var _hits_left: int = 0
var _extras: Node3D

@onready var _slab: MeshInstance3D = $Slab


func _ready() -> void:
	_rules = GameData.get_buildable(buildable_id)
	set_meta("interactable", self)
	add_to_group(Harvestable.INTERACTABLE_GROUP)
	TimeManager.new_day.connect(_on_new_day)
	_extras = Node3D.new()
	add_child(_extras)
	_reset_hits()
	_refresh_visual()


# --- Interaction interface (shared with Harvestable and the other interactables).

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
	Sfx.play(action.id, global_position) # Sound events are named after the actions.
	match action.id:
		"desherber", "ameublir":
			_hits_left -= 1
			_bounce()
			if _hits_left > 0:
				return
			for drop: Dictionary in _step(action.id).get("recolte", []):
				Inventory.add(drop.item, int(drop.qte))
			stage = Stage.WEEDED if action.id == "desherber" else Stage.LOOSENED
			_reset_hits()
		"compost":
			Inventory.remove_all(_step("compost").get("cout", []))
			composted = true
		"pailler":
			Inventory.remove_all(_step("pailler").get("cout", []))
			stage = Stage.MULCHED
		"semer":
			var seed_id := _available_seed()
			Inventory.remove(seed_id)
			crop_id = GameData.crop_for_seed(seed_id).id
			days_grown = 0
			last_watered_day = -1000
			stage = Stage.SOWN
		"arroser":
			Inventory.remove(_water().item, int(_water().qte))
			last_watered_day = TimeManager.day
		"recolter":
			_harvest()
	_refresh_visual()


# --- Rules.

func is_ripe() -> bool:
	return stage == Stage.SOWN and days_grown >= int(_crop().get("jours_pousse", 1))


## The soil stays moist for a few days after watering, thanks to the mulch.
func is_moist(day: int = TimeManager.day) -> bool:
	var retention := int(_step("pailler").get("retention_jours", 1)) if stage >= Stage.MULCHED else 1
	return day - last_watered_day < retention


## What the player can do now: id, prompt, whether it is possible, and the carnet hint.
func _current_action() -> Dictionary:
	match stage:
		Stage.GRASS:
			return _action("desherber", "Désherber", true, _step("desherber").get("carnet", ""))
		Stage.WEEDED:
			return _action("ameublir", "Ameublir à la grelinette", true, _step("ameublir").get("carnet", ""))
		Stage.LOOSENED, Stage.MULCHED:
			if not composted and Inventory.has_all(_step("compost").get("cout", [])):
				return _action("compost", "Ajouter du compost", true, _step("compost").get("carnet", ""))
			if stage == Stage.LOOSENED:
				var cost: Array = _step("pailler").get("cout", [])
				if Inventory.has_all(cost):
					return _action("pailler", "Pailler au BRF (%s)" % GameData.describe(cost), true, _step("pailler").get("carnet", ""))
				return _action("pailler", "Il faut %s pour pailler" % GameData.describe(cost), false, _step("pailler").get("carnet", ""))
			var seed_id := _available_seed()
			if seed_id != "":
				return _action("semer", "Semer une %s" % GameData.item_name(seed_id).to_lower(), true, GameData.crop_for_seed(seed_id).get("carnet", ""))
			return _action("semer", "Il te faut des graines", false, _rules.get("carnet", ""))
		_:
			var crop := _crop()
			var growth := "Pousse : %d / %d jours" % [days_grown, int(crop.get("jours_pousse", 1))]
			var hint := "%s\n%s" % [crop.get("carnet", ""), growth]
			if is_ripe():
				return _action("recolter", crop.get("invite_recolte", "Récolter"), true, crop.get("carnet", ""))
			if is_moist():
				return _action("arroser", "La terre est encore humide", false, hint)
			if Inventory.count(_water().item) >= int(_water().qte):
				return _action("arroser", "Arroser le plant de %s" % crop.get("nom", "").to_lower(), true, hint)
			return _action("arroser", "Arrosoir vide : va puiser à la rivière", false, hint)


func _action(id: String, prompt: String, possible: bool, hint: String) -> Dictionary:
	return {"id": id, "prompt": prompt, "possible": possible, "hint": hint}


func _on_new_day(day: int) -> void:
	# A plant grows one day for each day its soil stayed moist.
	if stage == Stage.SOWN and not is_ripe() and is_moist(day - 1):
		days_grown += 1
		_refresh_visual()
	elif stage == Stage.SOWN:
		_refresh_visual()


func _harvest() -> void:
	var drops: Array = _crop().get("recolte", [])
	for i in drops.size():
		var quantity := int(drops[i].qte)
		if i == 0 and composted:
			quantity += int(_step("compost").get("bonus_recolte", 0))
		Inventory.add(drops[i].item, quantity)
	crop_id = ""
	days_grown = 0
	composted = false
	stage = Stage.MULCHED


func _available_seed() -> String:
	for crop: Dictionary in GameData.crops.values():
		if Inventory.count(crop.get("graine", "")) > 0:
			return crop.graine
	return ""


func _step(id: String) -> Dictionary:
	return _rules.get("preparation", {}).get(id, {})


func _water() -> Dictionary:
	return _rules.get("arrosage", {"item": "", "qte": 1})


func _crop() -> Dictionary:
	return GameData.get_crop(crop_id)


func _reset_hits() -> void:
	match stage:
		Stage.GRASS:
			_hits_left = int(_step("desherber").get("coups", 1))
		Stage.WEEDED:
			_hits_left = int(_step("ameublir").get("coups", 1))


# --- Visuals.

func _refresh_visual() -> void:
	for child in _extras.get_children():
		child.queue_free()
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(global_position.snapped(Vector3.ONE * 0.1))

	var color := grass_color
	match stage:
		Stage.WEEDED:
			color = soil_color
		Stage.LOOSENED:
			color = compost_color if composted else loosened_color
		Stage.MULCHED, Stage.SOWN:
			color = mulch_color
	if stage == Stage.SOWN and is_moist():
		color = color.darkened(wet_darkening)
	_slab.material_override = _flat_material(color)

	for corner in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
		_add_box(Vector3(0.04, 0.3, 0.04), Vector3(corner.x * 0.46, 0.15, corner.y * 0.46), stake_color)
	match stage:
		Stage.GRASS:
			if grass_tuft:
				for i in 4:
					var tuft: Node3D = grass_tuft.instantiate()
					tuft.position = Vector3(rng.randf_range(-0.3, 0.3), 0.08, rng.randf_range(-0.3, 0.3))
					tuft.scale = Vector3.ONE * rng.randf_range(0.25, 0.35)
					_extras.add_child(tuft)
		Stage.LOOSENED:
			for i in 3:
				_add_box(Vector3(0.86, 0.06, 0.14), Vector3(0.0, 0.1, (i - 1) * 0.28), color.lightened(0.08))
		Stage.MULCHED, Stage.SOWN:
			for i in 14:
				var chip := mulch_color.lightened(rng.randf_range(-0.1, 0.15))
				if stage == Stage.SOWN and is_moist():
					chip = chip.darkened(wet_darkening)
				_add_box(Vector3(0.08, 0.02, 0.04), Vector3(rng.randf_range(-0.4, 0.4), 0.09, rng.randf_range(-0.4, 0.4)), chip, rng.randf() * TAU)
	if stage == Stage.SOWN:
		_add_plant(rng)


func _add_plant(rng: RandomNumberGenerator) -> void:
	var crop := _crop()
	var stages := int(crop.get("stades", 4))
	var days := int(crop.get("jours_pousse", 1))
	var growth := mini(floori(float(days_grown) / days * (stages - 1)), stages - 1)
	if growth == 0:
		# Sprout: two small leaves.
		for side in [-1, 1]:
			_add_box(Vector3(0.08, 0.015, 0.04), Vector3(side * 0.04, 0.14, 0.0), leaf_color, side * 0.4)
		return
	var model: PackedScene = load(crop.get("modele_plant", ""))
	if model:
		var plant: Node3D = model.instantiate()
		plant.scale = Vector3.ONE * (0.1 + 0.09 * growth)
		plant.position.y = 0.08
		plant.rotation.y = rng.randf() * TAU
		_extras.add_child(plant)
	if is_ripe():
		var fruit := Color.from_string(crop.get("couleur_fruit", "#cc3333"), Color.RED)
		for i in 6:
			var sphere := SphereMesh.new()
			sphere.radius = 0.05
			sphere.height = 0.1
			sphere.radial_segments = 8
			sphere.rings = 4
			sphere.material = _flat_material(fruit)
			var mesh := MeshInstance3D.new()
			mesh.mesh = sphere
			var angle := rng.randf() * TAU
			mesh.position = Vector3(cos(angle) * 0.15, rng.randf_range(0.3, 0.6), sin(angle) * 0.15)
			_extras.add_child(mesh)


func _add_box(size: Vector3, position_: Vector3, color: Color, yaw: float = 0.0) -> void:
	var box := BoxMesh.new()
	box.size = size
	box.material = _flat_material(color)
	var mesh := MeshInstance3D.new()
	mesh.mesh = box
	mesh.position = position_
	mesh.rotation.y = yaw
	_extras.add_child(mesh)


func _flat_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 1.0
	return material


func _bounce() -> void:
	var tween := create_tween()
	tween.tween_property(_extras, "position:y", 0.05, 0.08)
	tween.tween_property(_extras, "position:y", 0.0, 0.12)
