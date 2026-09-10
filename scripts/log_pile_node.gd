# TinyScape — Log Pile Entity Component
class_name LogPileNode
extends Node3D

const WoodcuttingData = preload("res://scripts/woodcutting_data.gd")

var tile: Vector2i = Vector2i(22, 1)
var has_logs: bool = false

var empty_mesh: Node3D
var stacked_mesh: Node3D

func initialize(p_tile: Vector2i) -> void:
	tile = p_tile
	name = "LogPile"

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

func set_has_logs(value: bool) -> void:
	has_logs = value
	if is_instance_valid(empty_mesh):
		empty_mesh.visible = not value
	if is_instance_valid(stacked_mesh):
		stacked_mesh.visible = value
