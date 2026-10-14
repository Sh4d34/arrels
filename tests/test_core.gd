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
	_test_clock()
	_test_modes()
	_test_campfire()
	_test_projects()
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
	_check(game_data.get_harvestable("arbre_friche").get("repousse_jours") == null, "la friche ne repousse pas")
	_check(int(game_data.get_harvestable("arbre_lisiere").get("repousse_jours", 0)) > 0, "la lisière repousse en jours")
	_check(game_data.crop_for_seed("graine_tomate").get("id") == "tomate", "la graine de tomate donne la tomate")
	_check(game_data.describe([{"item": "herbes", "qte": 2}]) == "2 herbes", "description d'un coût")
	_check(game_data.text("parcelle.desherber") == "Désherber", "texte simple depuis textes.json")
	_check(game_data.text("construction.manque", {"quantite": 3, "objet": "bois"}) == "Il manque 3 bois", "texte avec marqueurs")
	_check(game_data.text("composteur.murit", {"n": 1}) == "Le compost mûrit (encore 1 jour)", "texte au singulier")
	_check(game_data.text("composteur.murit", {"n": 3}) == "Le compost mûrit (encore 3 jours)", "texte au pluriel")


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


func _test_clock() -> void:
	var time: Node = root.get_node("TimeManager")
	var start_day: int = time.day
	time.set_hour(8.0)
	_check(absf(time.hour() - 8.0) < 0.01, "réglage de l'heure : 8 h")
	_check(time.period_name() == "matin", "8 h, c'est le matin")
	_check(not time.is_night(), "8 h n'est pas la nuit")
	time.set_hour(14.0)
	_check(time.period_name() == "après-midi", "14 h, c'est l'après-midi")
	time.set_hour(23.0)
	_check(time.is_night() and absf(time.hour() - 23.0) < 0.01, "23 h est la nuit")
	time.set_hour(3.0)
	_check(time.is_night() and absf(time.hour() - 3.0) < 0.01, "3 h est la fin de la nuit")
	# The night lasts a quarter of the real day: 9 game hours in 30 real seconds.
	time.set_hour(21.0)
	time._process(time.day_length * time.night_share * 0.5)
	_check(absf(time.hour() - 1.5) < 0.05, "la nuit passe plus vite : 4 h 30 en 15 s")
	time._process(time.day_length * time.night_share * 0.5 + 0.01)
	_check(time.day == start_day + 1, "un nouveau jour commence à l'aube")
	_check(absf(time.hour() - time.dawn_hour) < 0.05, "le jour commence à 6 h")


func _test_modes() -> void:
	var game_data: Node = root.get_node("GameData")
	_check(game_data.buildables_in_mode("construction") == ["composteur", "foyer"], "mode construction : composteur et foyer")
	_check(game_data.buildables_in_mode("potager") == ["parcelle"], "mode potager : la parcelle")
	var drops: Array = game_data.get_harvestable("paquet_bienvenue").get("recolte", [])
	_check(drops.any(func(d: Dictionary) -> bool: return d.item == "allumettes" and int(d.qte) == 5), "le paquet de bienvenue contient 5 allumettes")


func _test_campfire() -> void:
	var inventory: Node = root.get_node("Inventory")
	var time: Node = root.get_node("TimeManager")
	var fire: Node3D = load("res://scenes/buildables/foyer.tscn").instantiate()
	root.add_child(fire)
	time.set_hour(18.0)
	_check(not fire.can_interact(), "préparer le feu demande du petit bois et du bois")
	_check(fire.get_interaction_prompt() == "Il faut 2 petit bois, 2 bois pour préparer le feu", "invite quand il manque du bois")
	inventory.add("petit_bois", 2)
	inventory.add("bois", 3)
	fire.interact(null)
	_check(fire.state == fire.State.PREPARED and inventory.count("petit_bois") == 0, "le feu est préparé")
	_check(fire.get_interaction_prompt() == "Il te faut une allumette", "allumer demande une allumette")
	inventory.add("allumettes", 1)
	fire.interact(null)
	_check(fire.state == fire.State.BURNING and fire.hours_left() == 6, "le feu brûle pour 6 heures")
	fire.interact(null)
	_check(fire.hours_left() == 8 and inventory.count("bois") == 0, "une bûche ajoute 2 heures")
	time.set_hour(3.0) # 18 h + 8 h = 2 h du matin : le feu s'est éteint.
	fire._process(0.0)
	_check(fire.state == fire.State.EMBERS, "il reste des braises après le feu")
	time.set_hour(5.0)
	fire._process(0.0)
	_check(fire.state == fire.State.EMPTY, "les braises finissent par s'éteindre")
	fire.queue_free()


func _test_projects() -> void:
	var game_data: Node = root.get_node("GameData")
	var events: Node = root.get_node("Events")
	var projects: Node = root.get_node("Projects")
	var inventory: Node = root.get_node("Inventory")
	_check(game_data.projects.size() >= 2, "projets.json contient le fil de projets")
	_check(game_data.projects[0].id == "paquet", "le premier projet est le paquet de bienvenue")
	projects.reset()
	_check(projects.current().id == "paquet", "on commence par le premier projet")
	events.action_done.emit("recolter", "arbre_friche")
	_check(projects.current().id == "paquet", "une autre action ne valide pas le projet")
	var completed: Array = []
	projects.project_completed.connect(func(project: Dictionary) -> void: completed.append(project.id))
	# The composter is built ahead of time: it will count when its project comes.
	events.action_done.emit("construire", "composteur")
	events.action_done.emit("recolter", "paquet_bienvenue")
	_check(projects.current().id == "bois", "ouvrir le paquet passe au projet suivant")
	inventory.add("bois", 5)
	_check(projects.progress() == 5 and projects.goal() == 8, "le bois récolté fait avancer le projet")
	inventory.remove("bois", 5)
	_check(projects.progress() == 5, "dépenser du bois ne fait pas reculer le projet")
	inventory.add("bois", 3)
	_check(projects.current().id == "semis", "un composteur déjà construit valide aussitôt son projet")
	_check(completed == ["paquet", "bois", "composteur"], "chaque projet accompli est annoncé")
	for i in game_data.projects.size():
		if projects.current().is_empty():
			break
		var objective: Dictionary = projects.current().objectif
		if objective.action == "obtenir":
			inventory.add(objective.cible, int(objective.nombre))
		else:
			for n in int(objective.get("nombre", 1)):
				events.action_done.emit(objective.action, objective.cible)
	_check(projects.current().is_empty(), "tous les projets peuvent être accomplis")
	projects.reset()
