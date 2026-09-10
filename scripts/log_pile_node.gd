# TinyScape — Log Pile Entity Component
class_name LogPileNode
extends Node3D

const WoodcuttingData = preload("res://scripts/woodcutting_data.gd")

var tile: Vector2i = Vector2i(22, 1)
var has_logs: bool = false

var empty_mesh: Node3D
var stacked_mesh: Node3D

var pick_area: Area3D
var pick_collision: CollisionShape3D
var box_shape: BoxShape3D
var is_highlighted: bool = false
static var _outline_material: StandardMaterial3D

func initialize(p_tile: Vector2i) -> void:
	tile = p_tile
	name = "LogPile"

	_setup_collision()

	var empty_path: String = WoodcuttingData.ASSETS.get("logpile_empty", "")
	if not empty_path.is_empty():
		var empty_asset = load(empty_path) as PackedScene
		if empty_asset:
			empty_mesh = empty_asset.instantiate()
			empty_mesh.name = "EmptyFrame"
			add_child(empty_mesh)

	var stacked_path: String = WoodcuttingData.ASSETS.get("logpile_stacked", "")
	if not stacked_path.is_empty():
		var stacked_asset = load(stacked_path) as PackedScene
		if stacked_asset:
			stacked_mesh = stacked_asset.instantiate()
			stacked_mesh.name = "StackedLogs"
			add_child(stacked_mesh)
			stacked_mesh.visible = false

func _setup_collision() -> void:
	pick_area = Area3D.new()
	pick_area.name = "PickArea"
	pick_area.collision_layer = 2
	pick_area.collision_mask = 0
	pick_area.monitoring = false
	pick_area.monitorable = true

	pick_collision = CollisionShape3D.new()
	box_shape = BoxShape3D.new()
	# R1: Box covering the visible extent of the pile
	box_shape.size = Vector3(1.6, 0.9, 1.4)
	pick_collision.shape = box_shape
	pick_collision.position = Vector3(0, 0.45, 0)
	pick_area.add_child(pick_collision)
	add_child(pick_area)

func set_has_logs(value: bool) -> void:
	has_logs = value
	if is_instance_valid(empty_mesh):
		empty_mesh.visible = not value
	if is_instance_valid(stacked_mesh):
		stacked_mesh.visible = value

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
	return tile

func get_primary_action() -> Dictionary:
	return {
		"action": "deposit",
		"tile": tile,
		"text": "Deposit logs"
	}

func get_context_options(callbacks: Dictionary) -> Array[Dictionary]:
	var options: Array[Dictionary] = [
		{
			"text": "Deposit logs",
			"callback": callbacks.get("deposit", Callable())
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
