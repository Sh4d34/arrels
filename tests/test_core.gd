extends SceneTree
## Core tests for data loading and inventory. Run from the project folder:
##   godot --headless --path . -s tests/test_core.gd
## Exits with code 1 if any check fails.

var _failures := 0
var _checks := 0


func _initialize() -> void:
	# Autoloads are ready once the first frame starts.
	await process_frame
	_test_game_data()
	_test_inventory()
	_test_costs()
	_test_parcel()
	_test_composter()
	print("Tests: %s (%d vérifications)" % ["OK" if _failures == 0 else "%d échec(s)" % _failures, _checks])
	quit(1 if _failures > 0 else 0)


func _check(condition: bool, description: String) -> void:
	_checks += 1
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
	_check(game_data.crop_for_seed("graine_tomate").get("id") == "tomate", "la graine de tomate donne la tomate")
	_check(game_data.describe([{"item": "herbes", "qte": 2}]) == "2 herbes", "description d'un coût")


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


func _test_costs() -> void:
	var inventory: Node = root.get_node("Inventory")
	var game_data: Node = root.get_node("GameData")
	var composteur: Dictionary = game_data.get_buildable("composteur")
	_check(not composteur.is_empty(), "buildables.json contient le composteur")
	var costs: Array = composteur.get("cout", [])
	_check(not costs.is_empty(), "le composteur a un coût")
	inventory.add("bois", 5)
	_check(not inventory.has_all(costs), "5 bois ne suffisent pas")
	_check(not inventory.remove_all(costs), "retrait refusé sans assez de bois")
	_check(inventory.count("bois") == 5, "rien n'est retiré quand le coût n'est pas couvert")
	inventory.add("bois", 5)
	_check(inventory.remove_all(costs), "retrait du coût avec 10 bois")
	_check(inventory.count("bois") == 2, "il reste 2 bois")
	inventory.remove("bois", 2)


func _interact_times(target: Node, times: int) -> void:
	for i in times:
		target.interact(null)


func _test_parcel() -> void:
	var inventory: Node = root.get_node("Inventory")
	var time: Node = root.get_node("TimeManager")
	var parcel: Node3D = load("res://scenes/crops/parcelle.tscn").instantiate()
	root.add_child(parcel)

	_check(parcel.get_interaction_prompt() == "Désherber", "une parcelle neuve se désherbe")
	_interact_times(parcel, 2)
	_check(inventory.count("herbes") == 2, "le désherbage donne 2 herbes")
	_check(parcel.get_interaction_prompt() == "Ameublir à la grelinette", "puis on ameublit")
	_interact_times(parcel, 2)
	_check(not parcel.can_interact(), "pailler sans branchages est impossible")
	inventory.add("compost", 1)
	_check(parcel.get_interaction_prompt() == "Ajouter du compost", "le compost est proposé quand on en a")
	parcel.interact(null)
	_check(parcel.composted and inventory.count("compost") == 0, "le compost est utilisé")
	inventory.add("branchages", 2)
	parcel.interact(null)
	_check(inventory.count("branchages") == 0, "le paillage utilise 2 branchages")
	_check(parcel.get_interaction_prompt() == "Il te faut des graines", "semer demande une graine")
	inventory.add("graine_tomate", 1)
	parcel.interact(null)
	_check(parcel.crop_id == "tomate", "la graine de tomate est semée")

	_check(parcel.get_interaction_prompt().begins_with("Arrosoir vide"), "arroser demande de l'eau")
	inventory.add("eau", 5)
	parcel.interact(null)
	_check(inventory.count("eau") == 4, "arroser utilise une unité d'eau")
	_check(not parcel.can_interact(), "pas besoin d'arroser une terre humide")
	time.advance_day()
	_check(parcel.days_grown == 1, "la plante pousse après un jour humide")
	_check(not parcel.can_interact(), "le paillage garde la terre humide le lendemain")
	time.advance_day()
	_check(parcel.days_grown == 2, "elle pousse encore grâce au paillage")
	time.advance_day()
	_check(parcel.days_grown == 2, "sans arrosage, elle attend sans mourir")
	_check(parcel.stage == parcel.Stage.SOWN, "la plante est toujours là")
	for day in 4:
		parcel.interact(null)
		time.advance_day()
	_check(parcel.is_ripe(), "la tomate est mûre après 6 jours de pousse")
	parcel.interact(null)
	_check(inventory.count("tomate") == 4, "récolte : 3 tomates + 1 grâce au compost")
	_check(inventory.count("graine_tomate") == 1, "récolte : 1 graine")
	_check(parcel.stage == parcel.Stage.MULCHED and not parcel.composted, "la parcelle paillée attend un nouveau semis")
	for item in ["tomate", "graine_tomate", "eau", "herbes"]:
		inventory.remove(item, inventory.count(item))
	parcel.queue_free()


func _test_composter() -> void:
	var inventory: Node = root.get_node("Inventory")
	var time: Node = root.get_node("TimeManager")
	var composter: Node3D = load("res://scenes/buildables/composteur.tscn").instantiate()
	root.add_child(composter)
	_check(not composter.can_interact(), "composter demande des herbes")
	inventory.add("herbes", 2)
	composter.interact(null)
	_check(inventory.count("herbes") == 0, "les herbes sont déposées")
	time.advance_day()
	time.advance_day()
	_check(composter.ready_batches() == 0, "le compost n'est pas prêt après 2 jours")
	time.advance_day()
	_check(composter.get_interaction_prompt() == "Récupérer le compost", "le compost est prêt après 3 jours")
	composter.interact(null)
	_check(inventory.count("compost") == 1, "on récupère 1 compost")
	inventory.remove("compost", 1)
	composter.queue_free()
