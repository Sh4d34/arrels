@tool
class_name KeyCap
extends PanelContainer
## A keyboard key drawn as a small rounded cap with a darker bottom edge, showing a letter.

@export var key_text: String = "E":
	set(value):
		key_text = value
		if _label:
			_label.text = value
@export var cap_color: Color = Color(0.96, 0.93, 0.85)
@export var edge_color: Color = Color(0.68, 0.6, 0.47) ## Bottom edge, gives the key some depth.
@export var text_color: Color = Color(0.22, 0.17, 0.11)
@export var font_size: int = 18

var _label: Label


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var style := StyleBoxFlat.new()
	style.bg_color = cap_color
	style.border_color = edge_color
	style.border_width_bottom = 3
	style.set_corner_radius_all(6)
	style.content_margin_left = 9
	style.content_margin_right = 9
	style.content_margin_top = 1
	style.content_margin_bottom = 2
	add_theme_stylebox_override("panel", style)
	_label = Label.new()
	_label.text = key_text
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.add_theme_color_override("font_color", text_color)
	_label.add_theme_constant_override("outline_size", 0)
	_label.add_theme_font_size_override("font_size", font_size)
	add_child(_label)
