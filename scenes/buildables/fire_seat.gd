class_name FireSeat
extends StaticBody3D
## A log by the fire pit to sit on. While someone sits there, time flows faster (see Player.sit_on).
## Lies on collision layer 2 only: it does not block the player, who sits right on it.

var occupant: Node3D ## Who is sitting here, or null.

@onready var anchor: Marker3D = $Anchor ## Where the sitter stands, facing the fire (-Z).


func _ready() -> void:
	set_meta("interactable", self)
	add_to_group(Harvestable.INTERACTABLE_GROUP)


func get_interaction_prompt() -> String:
	return GameData.text("foyer.se_lever" if occupant else "foyer.s_asseoir")


func get_interaction_hint() -> String:
	return "" if occupant else GameData.text("foyer.assis_carnet")


func can_interact() -> bool:
	return true


func interact(actor: Node3D) -> void:
	if occupant == actor and actor.has_method("stand_up"):
		actor.call("stand_up")
	elif occupant == null and actor.has_method("sit_on"):
		actor.call("sit_on", self)
		var fire := get_parent() as Campfire
		Events.action_done.emit("s_asseoir", fire.buildable_id if fire else "")
