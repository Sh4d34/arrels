class_name Hud
extends CanvasLayer
## On-screen information: day, inventory, interaction prompt with its carnet hint,
## short messages and the build panel.

const PROMPT_KEYS := "Espace / clic"

@export var player: Player
@export var build_mode: BuildMode
@export var valid_status_color: Color = Color(0.7, 0.95, 0.6)
@export var invalid_status_color: Color = Color(1.0, 0.6, 0.5)
@export var toast_duration: float = 1.6
@export var toast_rise: float = 30.0

var _known_quantities: Dictionary[String, int] = {}

@onready var _inventory_panel: PanelContainer = %InventoryPanel
@onready var _inventory_list: VBoxContainer = %InventoryList
@onready var _prompt_panel: PanelContainer = %PromptPanel
@onready var _prompt_label: Label = %PromptLabel
@onready var _prompt_hint: Label = %PromptHint
@onready var _day_label: Label = %DayLabel
@onready var _toasts: Control = %Toasts
@onready var _build_panel: PanelContainer = %BuildPanel
@onready var _build_title: Label = %BuildTitle
@onready var _build_choices: Label = %BuildChoices
@onready var _build_cost: Label = %BuildCost
@onready var _build_carnet: Label = %BuildCarnet
@onready var _build_status: Label = %BuildStatus


func _ready() -> void:
	Inventory.changed.connect(_on_inventory_changed)
	TimeManager.new_day.connect(_on_new_day)
	_day_label.text = "Jour %d" % TimeManager.day
	if player:
		player.interaction_prompt_changed.connect(_on_prompt_changed)
	if build_mode:
		build_mode.mode_changed.connect(_on_build_mode_changed)
		build_mode.placement_changed.connect(_on_placement_changed)
		build_mode.built.connect(_on_built)
	_on_prompt_changed("", "", false)
	_on_build_mode_changed(false, "")
	_refresh_inventory()


func _on_prompt_changed(prompt: String, hint: String, possible: bool) -> void:
	_prompt_panel.visible = prompt != ""
	_prompt_label.text = "%s — %s" % [PROMPT_KEYS, prompt] if possible else prompt
	_prompt_hint.text = hint
	_prompt_hint.visible = hint != ""


func _on_new_day(day: int) -> void:
	_day_label.text = "Jour %d" % day
	_show_toast("Un nouveau jour se lève (jour %d)" % day)


func _on_inventory_changed(item_id: String, quantity: int) -> void:
	var gained: int = quantity - _known_quantities.get(item_id, 0)
	if gained > 0:
		_show_toast("+%d %s" % [gained, GameData.item_name(item_id)])
	_refresh_inventory()
	_refresh_build_cost()


func _on_build_mode_changed(active: bool, buildable_id: String) -> void:
	_build_panel.visible = active
	if not active:
		return
	var data := GameData.get_buildable(buildable_id)
	_build_title.text = "Construire : %s" % data.get("nom", buildable_id)
	var choices: PackedStringArray = []
	var ids := GameData.buildables.keys()
	for i in ids.size():
		var marker := "▸ " if ids[i] == buildable_id else "   "
		choices.append("%s%d · %s" % [marker, i + 1, GameData.get_buildable(ids[i]).get("nom", ids[i])])
	_build_choices.text = "\n".join(choices)
	_build_carnet.text = data.get("carnet", "")
	_build_carnet.visible = _build_carnet.text != ""
	_on_placement_changed(false, "")
	_refresh_build_cost()


func _on_placement_changed(valid: bool, reason: String) -> void:
	if valid:
		_build_status.text = "Emplacement libre"
	elif reason != "":
		_build_status.text = reason
	else:
		_build_status.text = "Vise le sol pour placer"
	_build_status.modulate = valid_status_color if valid else invalid_status_color


func _on_built(buildable_id: String) -> void:
	_show_toast("%s construit !" % GameData.get_buildable(buildable_id).get("nom", buildable_id))


func _refresh_build_cost() -> void:
	if build_mode == null or not build_mode.active:
		return
	var lines: PackedStringArray = []
	for cost: Dictionary in GameData.get_buildable(build_mode.get_buildable_id()).get("cout", []):
		lines.append("%d %s (tu en as %d)" % [int(cost.qte), GameData.item_name(cost.item).to_lower(), Inventory.count(cost.item)])
	_build_cost.text = "Coût : " + (", ".join(lines) if not lines.is_empty() else "gratuit")


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
