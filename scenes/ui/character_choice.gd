class_name CharacterChoice
extends CanvasLayer
## Start screen: the player picks who arrives at the foot of the Canigou. The world waits, paused,
## until a choice is made. Only shown when the world is the running game (not in tests or tools).

@export var player: Player

@onready var _title: Label = %Title
@onready var _choices: HBoxContainer = %Choices


func _ready() -> void:
	var scene := get_tree().current_scene
	if scene == null or not scene.is_ancestor_of(self):
		queue_free()
		return
	get_tree().paused = true
	_title.text = GameData.text("choix_personnage.titre")
	for definition: Dictionary in GameData.characters.get("personnages", []):
		var button := Button.new()
		button.text = GameData.text("choix_personnage." + definition.id)
		button.custom_minimum_size = Vector2(200, 64)
		button.add_theme_font_size_override("font_size", 28)
		button.pressed.connect(_choose.bind(definition.id))
		_choices.add_child(button)
	if _choices.get_child_count() > 0:
		(_choices.get_child(0) as Button).grab_focus()


func _choose(character_id: String) -> void:
	player.set_character(character_id)
	get_tree().paused = false
	queue_free()
