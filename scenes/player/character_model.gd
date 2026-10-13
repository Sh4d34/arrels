class_name CharacterModel
extends Node3D
## The player's look and animations, from data/personnages.json: a base body, hair pieces skinned
## on the same skeleton, a straw hat on the head bone, locomotion blended by speed, and gestures
## (cutting, kneeling, picking up...) played on top of it.

@export var hat_height: float = 0.15 ## Above the head bone, in meters (rest pose).
@export var hat_forward: float = 0.02
@export var straw_color: Color = Color(0.87, 0.74, 0.43)
@export var gesture_fade_in: float = 0.12
@export var gesture_fade_out: float = 0.2

static var _library: AnimationLibrary ## Built once from the animation file, shared by every body.

var _body: Node3D
var _skeleton: Skeleton3D
var _tree: AnimationTree
var _gesture_node: AnimationNodeAnimation


## Builds the character with this id (see data/personnages.json); replaces the previous one.
func set_character(character_id: String) -> void:
	var definition := _definition(character_id)
	if definition.is_empty():
		push_error("CharacterModel: unknown character '%s'" % character_id)
		return
	if _body:
		_body.queue_free()
	_body = (load(definition.corps) as PackedScene).instantiate()
	add_child(_body)
	_skeleton = _body.find_children("*", "Skeleton3D", true, false)[0]
	# With an outfit, only the head of the base body is kept: the rest would poke through the clothes.
	var skin_material: Material = null
	var body_mesh := _skeleton.get_node_or_null(NodePath(definition.get("maillage_corps", ""))) as MeshInstance3D
	if body_mesh == null:
		push_warning("CharacterModel: no body mesh '%s' in '%s'" % [definition.get("maillage_corps", ""), definition.corps])
	else:
		skin_material = body_mesh.get_active_material(0)
		if not definition.get("tenue", []).is_empty():
			_keep_only_bones(body_mesh, definition.get("os_gardes", ["Head", "neck_01"]))
	for outfit_path: String in definition.get("tenue", []):
		_attach_skinned((load(outfit_path) as PackedScene).instantiate(), Color.WHITE, skin_material, definition.get("prefixe_peau", ""))
	for piece_path: String in definition.get("pieces", []):
		_attach_skinned((load(piece_path) as PackedScene).instantiate(), Color.from_string(definition.get("couleur_cheveux", "#ffffff"), Color.WHITE))
	_add_hat()
	_setup_animation()


## Locomotion blend: idle, walk, jog and sprint follow the ground speed, in m/s.
func set_speed(speed: float) -> void:
	if _tree:
		_tree.set("parameters/move/blend_position", speed)


## Plays a gesture from data/personnages.json; returns how long it lasts, in seconds.
func play_gesture(gesture: String) -> float:
	var definition: Dictionary = GameData.characters.get("gestes", {}).get(gesture, {})
	if _tree == null or definition.is_empty():
		return 0.0
	var speed := float(definition.get("vitesse", 1.0))
	_gesture_node.animation = definition.animation
	_tree.set("parameters/gesture_speed/scale", speed)
	_tree.set("parameters/gesture/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)
	return _library.get_animation(definition.animation).length / speed


func _definition(character_id: String) -> Dictionary:
	for definition: Dictionary in GameData.characters.get("personnages", []):
		if definition.get("id") == character_id:
			return definition
	return {}


## Moves the skinned meshes of a piece (hair, outfit...) onto the body's skeleton.
## Their skins bind bones by name, so they follow the body's bones. The tint colors neutral
## textures (the free hair textures are meant to be tinted).
func _attach_skinned(piece: Node, tint: Color = Color.WHITE, skin_material: Material = null, skin_prefix: String = "") -> void:
	for mesh in piece.find_children("*", "MeshInstance3D", true, false):
		# Skin parts of an outfit (hands...) take the body's own skin, so they match the face.
		if skin_material and skin_prefix != "":
			for i in mesh.get_surface_override_material_count():
				var current: Material = mesh.get_active_material(i)
				if current and current.resource_name.begins_with(skin_prefix):
					mesh.set_surface_override_material(i, skin_material)
		if tint != Color.WHITE:
			for i in mesh.get_surface_override_material_count():
				var material: Material = mesh.get_active_material(i)
				if material is BaseMaterial3D:
					var tinted: BaseMaterial3D = material.duplicate()
					tinted.albedo_color = tint
					mesh.set_surface_override_material(i, tinted)
		mesh.owner = null
		mesh.get_parent().remove_child(mesh)
		_skeleton.add_child(mesh)
		mesh.skeleton = mesh.get_path_to(_skeleton)
	piece.free()


## Hides every part of a skinned mesh not driven by the given bones (all but the head): their
## bind poses are collapsed to a point, so those vertices shrink into the body, under the clothes.
## The mesh itself is untouched; only a copy of its skin changes.
func _keep_only_bones(mesh_instance: MeshInstance3D, bone_names: Array) -> void:
	if mesh_instance.skin == null:
		return
	var skin: Skin = mesh_instance.skin.duplicate()
	var collapsed := Transform3D(Basis().scaled(Vector3.ZERO), Vector3.ZERO)
	for bind in skin.get_bind_count():
		var name := skin.get_bind_name(bind)
		if name == "" and skin.get_bind_bone(bind) >= 0:
			name = _skeleton.get_bone_name(skin.get_bind_bone(bind))
		if not name in bone_names:
			skin.set_bind_pose(bind, collapsed)
	mesh_instance.skin = skin


## A straw hat on the head bone, placed level on the head in the rest pose.
func _add_hat() -> void:
	var head := _skeleton.find_bone("Head")
	if head < 0:
		return
	var attachment := BoneAttachment3D.new()
	attachment.bone_name = "Head"
	_skeleton.add_child(attachment)
	var head_rest := _skeleton.get_bone_global_rest(head)
	# Hat transform in skeleton space, then expressed relative to the head bone.
	var hat_in_skeleton := Transform3D(Basis(), head_rest.origin + Vector3(0.0, hat_height, hat_forward))
	var hat := Node3D.new()
	hat.transform = head_rest.affine_inverse() * hat_in_skeleton
	attachment.add_child(hat)
	var material := StandardMaterial3D.new()
	material.albedo_color = straw_color
	material.roughness = 1.0
	for part in [[0.3, 0.3, 0.03, 0.0], [0.13, 0.16, 0.13, 0.07]]:
		var cylinder := CylinderMesh.new()
		cylinder.top_radius = part[0]
		cylinder.bottom_radius = part[1]
		cylinder.height = part[2]
		cylinder.radial_segments = 14
		cylinder.rings = 1
		cylinder.material = material
		var mesh := MeshInstance3D.new()
		mesh.mesh = cylinder
		mesh.position.y = part[3]
		# No cast shadow: the brim would otherwise hide the face in shade.
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		hat.add_child(mesh)


func _setup_animation() -> void:
	var player := AnimationPlayer.new()
	_body.add_child(player) # Its root is the body, so tracks like "Armature/Skeleton3D:Head" resolve.
	player.add_animation_library("", _get_library())

	var blend := AnimationNodeBlendTree.new()
	var move := AnimationNodeBlendSpace1D.new()
	var steps: Array = GameData.characters.get("deplacement", [])
	for step: Dictionary in steps:
		var clip := AnimationNodeAnimation.new()
		clip.animation = step.animation
		move.add_blend_point(clip, float(step.vitesse), -1, step.animation)
	move.min_space = 0.0
	move.max_space = float(steps.back().vitesse) if not steps.is_empty() else 1.0
	_gesture_node = AnimationNodeAnimation.new()
	var gesture_speed := AnimationNodeTimeScale.new()
	var gesture := AnimationNodeOneShot.new()
	gesture.fadein_time = gesture_fade_in
	gesture.fadeout_time = gesture_fade_out
	blend.add_node("move", move)
	blend.add_node("gesture_clip", _gesture_node)
	blend.add_node("gesture_speed", gesture_speed)
	blend.add_node("gesture", gesture)
	blend.connect_node("gesture_speed", 0, "gesture_clip")
	blend.connect_node("gesture", 0, "move")
	blend.connect_node("gesture", 1, "gesture_speed")
	blend.connect_node("output", 0, "gesture")

	_tree = AnimationTree.new()
	_body.add_child(_tree)
	_tree.anim_player = _tree.get_path_to(player)
	_tree.tree_root = blend
	_tree.active = true
	_tree.advance(0.0) # Pose right away, even if the game starts paused (character choice).


static func _get_library() -> AnimationLibrary:
	if _library:
		return _library
	_library = AnimationLibrary.new()
	var source: Node = (load(GameData.characters.get("animations", "")) as PackedScene).instantiate()
	var player: AnimationPlayer = source.find_children("*", "AnimationPlayer", true, false)[0]
	var needed: Array[String] = []
	for step: Dictionary in GameData.characters.get("deplacement", []):
		needed.append(step.animation)
	for gesture: Dictionary in GameData.characters.get("gestes", {}).values():
		needed.append(gesture.animation)
	for name in needed:
		if player.has_animation(name) and not _library.has_animation(name):
			_library.add_animation(name, player.get_animation(name))
	source.free()
	return _library
