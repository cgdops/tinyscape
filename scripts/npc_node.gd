# TinyScape — NPC Entity Component
class_name NpcNode
extends Node3D

var id: String = "mabb_truet"
var display_name: String = "Mabb Truet"
var examine: String = "Willowmere's woodcutter. She has not stopped working to look at you."
var home_tile: Vector2i = Vector2i(21, 2)
var facing: Vector2i = Vector2i(1, -1)
var dialogue_file: String = "mabb_truet"

var model: Node3D
var head_target: Node3D

var pick_area: Area3D
var pick_collision: CollisionShape3D
var is_highlighted: bool = false
static var _outline_material: StandardMaterial3D

func initialize(
	p_id: String,
	p_name: String,
	p_examine: String,
	p_home: Vector2i,
	p_facing: Vector2i,
	p_dialogue: String,
	materials: Dictionary
) -> void:
	id = p_id
	display_name = p_name
	examine = p_examine
	home_tile = p_home
	facing = p_facing
	dialogue_file = p_dialogue
	name = "NPC_%s" % id

	_setup_collision()
	_build_model(materials)
	reset_facing()

func _setup_collision() -> void:
	pick_area = Area3D.new()
	pick_area.name = "PickArea"
	pick_area.collision_layer = 2
	pick_area.collision_mask = 0
	pick_area.monitoring = false
	pick_area.monitorable = true

	pick_collision = CollisionShape3D.new()
	var cap_shape = CapsuleShape3D.new()
	# Height 1.70m, radius ~0.25m (R1: roughly 0.45m across, full height)
	cap_shape.radius = 0.25
	cap_shape.height = 1.70
	pick_collision.shape = cap_shape
	pick_collision.position = Vector3(0, 0.85, 0)
	pick_area.add_child(pick_collision)
	add_child(pick_area)

func _build_model(materials: Dictionary) -> void:
	# Try loading dedicated asset if exists (e.g. assets/models/villagers/MabbTruet.glb or assets/models/mabb_truet.glb)
	var candidate_paths = [
		"res://assets/models/villagers/MabbTruet.glb" if id == "mabb_truet" else "",
		"res://assets/models/%s.glb" % id,
		"res://assets/models/villagers/%s.glb" % id
	]
	for custom_path in candidate_paths:
		if not custom_path.is_empty() and ResourceLoader.exists(custom_path):
			var scene = load(custom_path) as PackedScene
			if scene:
				model = scene.instantiate()
				model.name = "Model"
				add_child(model)
				head_target = model.find_child("Head", true, false)
				var anim_player: AnimationPlayer = model.find_child("AnimationPlayer", true, false) as AnimationPlayer
				if anim_player:
					for anim_name in anim_player.get_animation_list():
						var anim = anim_player.get_animation(anim_name)
						if anim:
							anim.loop_mode = Animation.LOOP_LINEAR
					if anim_player.has_animation("Idle"):
						anim_player.play("Idle")
				return

	# Stylized fallback model matching art-direction specs:
	# Height ~1.70m, broad planted silhouette, sleeveless overtunic (Canopy shadow),
	# cream plaster sleeves, chestnut leather apron/gloves, deep pine trousers/boots,
	# ash hair tied back, weathered face.
	model = Node3D.new()
	model.name = "Model"
	add_child(model)

	# Legs / Trousers
	for leg_x in [-0.16, 0.16]:
		var leg = MeshInstance3D.new()
		var cyl = CylinderMesh.new()
		cyl.top_radius = 0.13
		cyl.bottom_radius = 0.11
		cyl.height = 0.70
		cyl.radial_segments = 7
		leg.mesh = cyl
		leg.material_override = materials.get("pine_dark", null)
		leg.position = Vector3(leg_x, 0.35, 0)
		model.add_child(leg)

	# Torso & Apron
	var torso = MeshInstance3D.new()
	var box = BoxMesh.new()
	box.size = Vector3(0.56, 0.65, 0.36)
	torso.mesh = box
	torso.material_override = materials.get("oak_dark", null) # Canopy shadow
	torso.position = Vector3(0, 0.95, 0)
	model.add_child(torso)

	# Apron over torso
	var apron = MeshInstance3D.new()
	var apron_mesh = BoxMesh.new()
	apron_mesh.size = Vector3(0.44, 0.58, 0.38)
	apron.mesh = apron_mesh
	apron.material_override = materials.get("wood_light", null) # Chestnut leather
	apron.position = Vector3(0, 0.92, 0.01)
	model.add_child(apron)

	# Brass buckle at belt
	var belt_buckle = MeshInstance3D.new()
	var b_box = BoxMesh.new()
	b_box.size = Vector3(0.08, 0.08, 0.40)
	belt_buckle.mesh = b_box
	belt_buckle.material_override = materials.get("brass", null)
	belt_buckle.position = Vector3(0, 0.72, 0)
	model.add_child(belt_buckle)

	# Arms (sleeves in cream plaster)
	for arm_x in [-0.34, 0.34]:
		var arm = MeshInstance3D.new()
		var arm_cyl = CylinderMesh.new()
		arm_cyl.top_radius = 0.09
		arm_cyl.bottom_radius = 0.08
		arm_cyl.height = 0.58
		arm_cyl.radial_segments = 6
		arm.mesh = arm_cyl
		arm.material_override = materials.get("plaster", null)
		arm.position = Vector3(arm_x, 0.92, 0)
		model.add_child(arm)

	# Head node
	head_target = Node3D.new()
	head_target.name = "Head"
	head_target.position = Vector3(0, 1.42, 0)
	model.add_child(head_target)

	var face = MeshInstance3D.new()
	var face_box = BoxMesh.new()
	face_box.size = Vector3(0.28, 0.32, 0.28)
	face.mesh = face_box
	face.material_override = materials.get("path_c", null) # Weathered skin
	head_target.add_child(face)

	var hair = MeshInstance3D.new()
	var hair_box = BoxMesh.new()
	hair_box.size = Vector3(0.30, 0.16, 0.32)
	hair.mesh = hair_box
	hair.material_override = materials.get("stone_dark", null) # Ash hair
	hair.position = Vector3(0, 0.11, -0.02)
	head_target.add_child(hair)

func turn_to_face(target_pos: Vector3) -> void:
	var dir = target_pos - global_position
	dir.y = 0
	if dir.length_squared() > 0.001:
		model.rotation.y = atan2(dir.x, dir.z)

func reset_facing() -> void:
	if facing != Vector2i.ZERO:
		model.rotation.y = atan2(float(facing.x), float(facing.y))

static func get_outline_material() -> StandardMaterial3D:
	if _outline_material == null:
		_outline_material = StandardMaterial3D.new()
		_outline_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_outline_material.albedo_color = Color("fff6e4")
		_outline_material.cull_mode = BaseMaterial3D.CULL_FRONT
		_outline_material.grow = true
		_outline_material.grow_amount = 0.02
	return _outline_material

func set_highlighted(enabled: bool) -> void:
	if is_highlighted == enabled:
		return
	is_highlighted = enabled
	var mat: Material = get_outline_material() if enabled else null
	_apply_material_overlay(self, mat)

func _apply_material_overlay(node: Node, mat: Material) -> void:
	if node is MeshInstance3D:
		node.material_overlay = mat
	for child in node.get_children():
		if child is Area3D:
			continue
		_apply_material_overlay(child, mat)

func get_entity_tile() -> Vector2i:
	return home_tile

func get_primary_action() -> Dictionary:
	return {
		"action": "talk",
		"tile": home_tile,
		"text": "Talk-to " + display_name
	}

func get_context_options(callbacks: Dictionary) -> Array[Dictionary]:
	var options: Array[Dictionary] = [
		{
			"text": "Talk-to " + display_name,
			"callback": callbacks.get("talk", Callable())
		},
		{
			"text": "Examine",
			"callback": callbacks.get("examine", Callable())
		},
		{
			"text": "Cancel",
			"callback": Callable()
		}
	]
	return options
