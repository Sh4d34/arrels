class_name Hud
extends CanvasLayer
## On-screen information: inventory, interaction prompt and short pickup messages.

const PROMPT_KEYS := "Espace / clic"

@export var player: Player
@export var toast_duration: float = 1.6
@export var toast_rise: float = 30.0

var _known_quantities: Dictionary[String, int] = {}

@onready var _inventory_panel: PanelContainer = %InventoryPanel
@onready var _inventory_list: VBoxContainer = %InventoryList
@onready var _prompt_panel: PanelContainer = %PromptPanel
@onready var _prompt_label: Label = %PromptLabel
@onready var _toasts: Control = %Toasts


func _ready() -> void:
	Inventory.changed.connect(_on_inventory_changed)
	if player:
		player.interaction_prompt_changed.connect(_on_prompt_changed)
	_on_prompt_changed("")
	_refresh_inventory()


func _on_prompt_changed(prompt: String) -> void:
	_prompt_panel.visible = prompt != ""
	_prompt_label.text = "%s — %s" % [PROMPT_KEYS, prompt]


func _on_inventory_changed(item_id: String, quantity: int) -> void:
	var gained: int = quantity - _known_quantities.get(item_id, 0)
	if gained > 0:
		_show_toast("+%d %s" % [gained, GameData.item_name(item_id)])
	_refresh_inventory()


func _refresh_inventory() -> void:
	_known_quantities = Inventory.get_all()
	for child in _inventory_list.get_children():
		child.queue_free()
	for item_id in _known_quantities:
		var label := Label.new()
		label.text = "%s : %d" % [GameData.item_name(item_id), _known_quantities[item_id]]
		_inventory_list.add_child(label)
	_inventory_panel.visible = not _known_quantities.is_empty()


func _show_toast(text: String) -> void:
	var label := Label.new()
	label.text = text
	label.label_settings = _prompt_label.label_settings
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# Stacked below the toasts still fading out.
	label.position.y = _toasts.get_child_count() * 30.0
	label.size.x = _toasts.size.x
	_toasts.add_child(label)
	var tween := label.create_tween()
	tween.set_parallel()
	tween.tween_property(label, "position:y", label.position.y - toast_rise, toast_duration)
	tween.tween_property(label, "modulate:a", 0.0, toast_duration).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(label.queue_free)
