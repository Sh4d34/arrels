@tool
extends Node3D
## Root of the game world. Keeps trees and ground cover standing on the terrain surface.

@export_tool_button("Poser la végétation sur le terrain", "Snap") var snap_action: Callable = snap_to_terrain
@export var tree_sink_depth: float = 0.15 ## Sinks trunks slightly so they never float on slopes.
@export var small_cover_height: float = 1.0 ## Ground cover lower than this casts no shadow and fades out with distance.
@export var small_cover_view_distance: float = 45.0

@onready var _terrain: Terrain = $Terrain
@onready var _snapped_groups: Array[Node3D] = [$ForestEdge, $Riparian, $Thicket, $Landmarks, $Props, $GroundCover]


func _ready() -> void:
	snap_to_terrain()
	_lighten_small_cover()


func snap_to_terrain() -> void:
	for group in _snapped_groups:
		for child in group.get_children():
			var node := child as Node3D
			if node:
				var p := node.global_position
				node.global_position.y = _terrain.surface_height_at(p.x, p.z) - tree_sink_depth


func _lighten_small_cover() -> void:
	# Grass, flowers and pebbles are barely visible from afar, but cost a lot to draw.
	for mesh in $GroundCover.find_children("*", "MeshInstance3D", true, false):
		var instance := mesh as MeshInstance3D
		if (instance.global_transform * instance.get_aabb()).size.y < small_cover_height:
			instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			instance.visibility_range_end = small_cover_view_distance
			instance.visibility_range_end_margin = 5.0
			instance.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
