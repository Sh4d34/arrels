@tool
extends Node3D
## Root of the game world. Keeps every tree standing on the terrain surface.

@export_tool_button("Poser les arbres sur le terrain", "Snap") var snap_trees_action: Callable = snap_trees_to_terrain
@export var tree_sink_depth: float = 0.15 ## Sinks trunks slightly so they never float on slopes.

@onready var _terrain: Terrain = $Terrain
@onready var _tree_groups: Array[Node3D] = [$ForestEdge, $Riparian, $Thicket]


func _ready() -> void:
	snap_trees_to_terrain()


func snap_trees_to_terrain() -> void:
	for group in _tree_groups:
		for child in group.get_children():
			var tree := child as Node3D
			if tree:
				var p := tree.global_position
				tree.global_position.y = _terrain.surface_height_at(p.x, p.z) - tree_sink_depth
