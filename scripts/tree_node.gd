# TinyScape — Interactive Tree Entity Component
class_name TreeNode
extends Node3D

signal state_changed(tile: Vector2i, is_stump: bool)

const WoodcuttingData = preload("res://scripts/woodcutting_data.gd")

var tile: Vector2i
var tree_type: String
var height: float
var hit_points: int = 4
var max_hp: int = 4
var is_stump: bool = false
var respawn_timer: float = 0.0

var canopy: Node3D
var stump: Node3D
var trunk_mesh: MeshInstance3D

var pick_area: Area3D
var pick_collision: CollisionShape3D
var cylinder_shape: CylinderShape3D
var is_highlighted: bool = false
static var _outline_material: StandardMaterial3D

func initialize(p_tile: Vector2i, p_type: String, p_height: float, materials: Dictionary) -> void:
	tile = p_tile
	tree_type = p_type
	height = p_height
	name = "Tree_%d_%d" % [tile.x, tile.y]

	var tree_info = WoodcuttingData.get_tree_info(tree_type)
	max_hp = tree_info.get("hit_points", 4)
	hit_points = max_hp

	canopy = Node3D.new()
	canopy.name = "Canopy"
	add_child(canopy)

	stump = Node3D.new()
	stump.name = "Stump"
	add_child(stump)

	_setup_collision()
	_build_visuals(materials)

func _setup_collision() -> void:
	pick_area = Area3D.new()
	pick_area.name = "PickArea"
	# Layer 2 for interactive entities
	pick_area.collision_layer = 2
	pick_area.collision_mask = 0
	pick_area.monitoring = false
	pick_area.monitorable = true

	pick_collision = CollisionShape3D.new()
	cylinder_shape = CylinderShape3D.new()
	pick_collision.shape = cylinder_shape
	pick_area.add_child(pick_collision)
	add_child(pick_area)
	_update_collision_shape()

func _update_collision_shape() -> void:
	var new_shape = CylinderShape3D.new()
	if is_stump:
		new_shape.height = 0.35
		new_shape.radius = 0.35
		pick_collision.position = Vector3(0, 0.175, 0)
	else:
		new_shape.height = height
		var rad: float = 1.2
		if tree_type == "pine":
			rad = 1.0
		elif tree_type == "willow":
			rad = 1.3
		new_shape.radius = rad
		pick_collision.position = Vector3(0, height * 0.5, 0)
	pick_collision.shape = new_shape

func _build_visuals(materials: Dictionary) -> void:
	trunk_mesh = MeshInstance3D.new()
	var cyl = CylinderMesh.new()
	cyl.top_radius = 0.20 if tree_type == "pine" else 0.24
	cyl.bottom_radius = 0.23 if tree_type == "pine" else 0.28
	cyl.height = height * 0.44
	cyl.radial_segments = 8
	trunk_mesh.mesh = cyl
	trunk_mesh.material_override = materials["wood"]
	trunk_mesh.position = Vector3(0, height * 0.22, 0)
	canopy.add_child(trunk_mesh)

	if tree_type == "pine":
		for tier in range(3):
			var cone_node = MeshInstance3D.new()
			var cone_mesh = CylinderMesh.new()
			cone_mesh.top_radius = 0.0
			var rad = height * (0.28 - tier * 0.054)
			cone_mesh.bottom_radius = rad
			cone_mesh.height = height * 0.49
			cone_mesh.radial_segments = 7
			cone_node.mesh = cone_mesh
			cone_node.material_override = materials[["pine_dark", "pine", "pine_light"][tier]]
			cone_node.position = Vector3(0, height * (0.41 + tier * 0.20) + height * 0.245, 0)
			cone_node.rotation.y = tier * 0.55
			canopy.add_child(cone_node)
	elif tree_type == "willow":
		trunk_mesh.visible = false
		var asset_path: String = WoodcuttingData.ASSETS.get("willow_tree", "")
		if not asset_path.is_empty():
			var willow_asset = load(asset_path) as PackedScene
			if willow_asset:
				var willow_inst = willow_asset.instantiate()
				willow_inst.name = "WillowMesh"
				canopy.add_child(willow_inst)
	else:
		for i in range(5):
			var angle = i * TAU / 5.0
			var sph_node = MeshInstance3D.new()
			var sph = SphereMesh.new()
			sph.radius = 1.0
			sph.height = 2.0
			sph.radial_segments = 8
			sph.rings = 4
			sph_node.mesh = sph
			sph_node.scale = Vector3(1.30, 1.13, 1.20)
			sph_node.material_override = materials[["oak", "oak_light", "oak_dark"][i % 3]]
			sph_node.position = Vector3(cos(angle) * 0.98, height * 0.69, sin(angle) * 0.98)
			canopy.add_child(sph_node)
		var top_sph = MeshInstance3D.new()
		var top_mesh = SphereMesh.new()
		top_mesh.radius = 1.0
		top_mesh.height = 2.0
		top_mesh.radial_segments = 8
		top_mesh.rings = 4
		top_sph.mesh = top_mesh
		top_sph.scale = Vector3(1.12, 0.96, 1.07)
		top_sph.material_override = materials["oak_light"]
		top_sph.position = Vector3(0, height * 0.95, 0)
		canopy.add_child(top_sph)

	var stump_asset_key = "%s_stump" % tree_type
	var stump_asset_path: String = WoodcuttingData.ASSETS.get(stump_asset_key, "")
	var loaded_stump: bool = false
	if not stump_asset_path.is_empty() and ResourceLoader.exists(stump_asset_path):
		var stump_scene = load(stump_asset_path) as PackedScene
		if stump_scene:
			var stump_inst = stump_scene.instantiate()
			stump_inst.name = "StumpMesh"
			stump.add_child(stump_inst)
			loaded_stump = true

	if not loaded_stump:
		var stump_mesh = MeshInstance3D.new()
		var stump_cyl = CylinderMesh.new()
		stump_cyl.top_radius = 0.22
		stump_cyl.bottom_radius = 0.26
		stump_cyl.height = 0.32
		stump_cyl.radial_segments = 8
		stump_mesh.mesh = stump_cyl
		stump_mesh.material_override = materials.get("wood", null)
		stump_mesh.position = Vector3(0, 0.16, 0)
		stump.add_child(stump_mesh)

	stump.visible = false

func damage() -> bool:
	if is_stump:
		return false
	hit_points -= 1
	if hit_points <= 0:
		fell()
		return true
	return false

func fell() -> bool:
	if is_stump:
		return false
	is_stump = true
	hit_points = 0
	canopy.visible = false
	stump.visible = true
	_update_collision_shape()
	var tree_info = WoodcuttingData.get_tree_info(tree_type)
	respawn_timer = tree_info.get("respawn_time", 25.0)
	state_changed.emit(tile, true)
	return true

func respawn() -> void:
	if not is_stump:
		return
	is_stump = false
	hit_points = max_hp
	canopy.visible = true
	stump.visible = false
	_update_collision_shape()
	respawn_timer = 0.0
	state_changed.emit(tile, false)

func advance(delta: float) -> void:
	if is_stump:
		respawn_timer -= delta
		if respawn_timer <= 0.0:
			respawn()

static func get_outline_material() -> StandardMaterial3D:
	if _outline_material == null:
		_outline_material = StandardMaterial3D.new()
		_outline_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		# Highlight #fff6e4 from art-direction.md §2
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
	return tile

func get_primary_action() -> Dictionary:
	if is_stump:
		return {}
	var type_name: String = tree_type.capitalize() + " Tree"
	return {
		"action": "chop",
		"tile": tile,
		"text": "Chop " + type_name
	}

func get_context_options(callbacks: Dictionary) -> Array[Dictionary]:
	var options: Array[Dictionary] = []
	var type_name: String = tree_type.capitalize() + " Tree"
	if not is_stump:
		options.append({
			"text": "Chop " + type_name,
			"callback": callbacks.get("chop", Callable())
		})
		options.append({
			"text": "Examine",
			"callback": callbacks.get("examine", Callable())
		})
	else:
		options.append({
			"text": "Examine",
			"callback": callbacks.get("examine", Callable())
		})
	options.append({
		"text": "Cancel",
		"callback": Callable()
	})
	return options

func to_dict() -> Dictionary:
	return {
		"tile": tile,
		"type": tree_type,
		"height": height,
		"is_stump": is_stump,
		"hit_points": hit_points,
		"max_hp": max_hp,
		"respawn_timer": respawn_timer,
		"node": self,
		"canopy": canopy,
		"stump": stump
	}
