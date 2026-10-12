extends SceneTree
## Core tests for data loading and inventory. Run from the project folder:
##   godot --headless --path . -s tests/test_core.gd
## Exits with code 1 if any check fails.

var _failures := 0


func _initialize() -> void:
	# Autoloads are ready once the first frame starts.
	await process_frame
	_test_game_data()
	_test_inventory()
	print("Tests: %s" % ("OK" if _failures == 0 else "%d échec(s)" % _failures))
	quit(1 if _failures > 0 else 0)


func _check(condition: bool, description: String) -> void:
	if not condition:
		_failures += 1
		printerr("ÉCHEC : " + description)


func _test_game_data() -> void:
	var game_data: Node = root.get_node("GameData")
	_check(game_data.items.has("bois"), "items.json contient le bois")
	_check(game_data.item_name("bois") == "Bois", "nom affiché du bois")
	_check(game_data.item_name("inconnu") == "inconnu", "nom de repli = id")
	for id in ["arbre_friche", "arbre_mort", "arbre_lisiere"]:
		var data: Dictionary = game_data.get_harvestable(id)
		_check(not data.is_empty(), "harvestables.json contient %s" % id)
		_check(int(data.get("coups", 0)) > 0, "%s a au moins un coup" % id)
	_check(game_data.get_harvestable("arbre_friche").get("repousse_secondes") == null, "la friche ne repousse pas")
	_check(game_data.get_harvestable("arbre_lisiere").get("repousse_secondes") != null, "la lisière repousse")


func _test_inventory() -> void:
	var inventory: Node = root.get_node("Inventory")
	var events: Array = []
	inventory.changed.connect(func(id: String, quantity: int) -> void: events.append([id, quantity]))

	inventory.add("bois", 3)
	_check(inventory.count("bois") == 3, "ajout de 3 bois")
	_check(events.back() == ["bois", 3], "signal après ajout")
	inventory.add("bois", 0)
	_check(events.size() == 1, "ajouter 0 ne fait rien")
	_check(not inventory.remove("bois", 5), "retrait impossible au-delà du stock")
	_check(inventory.count("bois") == 3, "stock inchangé après un retrait refusé")
	_check(inventory.remove("bois", 3), "retrait du stock exact")
	_check(inventory.count("bois") == 0 and not inventory.get_all().has("bois"), "objet retiré quand il tombe à 0")
	_check(events.back() == ["bois", 0], "signal après retrait")
