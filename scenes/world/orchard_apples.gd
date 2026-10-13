@tool
class_name OrchardApples
extends MultiMeshInstance3D
## Apples in the crowns of the orchard trees, and a few fallen in the grass, drawn in one go.
## Placed after the world has set the trees on the ground (deferred), so they follow them.

@export var trees: Node3D ## Parent of the orchard trees.
@export var apples_per_tree: int = 14
@export var fallen_per_tree: int = 3
@export var crown_height: Vector2 = Vector2(0.55, 0.85) ## Fraction of the tree height, min and max.
@export var crown_radius: float = 0.32 ## Fraction of the tree height.
@export var tree_height: float = 7.0 ## Height of the tree model at scale 1.
@export var colors: PackedColorArray = PackedColorArray([Color(0.8, 0.15, 0.1), Color(0.85, 0.3, 0.1), Color(0.92, 0.75, 0.2)])
@export var seed: int = 8


func _ready() -> void:
	generate.call_deferred()


func generate() -> void:
	if trees == null:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var placed: Array[Transform3D] = []
	var tints: Array[Color] = []
	for tree in trees.get_children():
		var t := tree as Node3D
		if t == null:
			continue
		var height := tree_height * t.scale.y
		for i in apples_per_tree + fallen_per_tree:
			var angle := rng.randf() * TAU
			var offset: Vector3
			if i < apples_per_tree:
				offset = Vector3(cos(angle), 0.0, sin(angle)) * height * crown_radius * rng.randf_range(0.6, 1.0)
				offset.y = height * rng.randf_range(crown_height.x, crown_height.y)
			else:
				offset = Vector3(cos(angle), 0.0, sin(angle)) * rng.randf_range(0.4, 1.6)
				offset.y = 0.05
			placed.append(Transform3D(Basis(), t.global_position + offset))
			tints.append(colors[rng.randi() % colors.size()])
	var sphere := SphereMesh.new()
	sphere.radius = 0.07
	sphere.height = 0.13
	sphere.radial_segments = 8
	sphere.rings = 4
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.roughness = 0.6
	sphere.material = material
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = sphere
	mm.instance_count = placed.size()
	for i in placed.size():
		mm.set_instance_transform(i, global_transform.affine_inverse() * placed[i])
		mm.set_instance_color(i, tints[i])
	multimesh = mm
