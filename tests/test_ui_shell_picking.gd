extends SceneTree

const MainScene = preload("res://scenes/main.tscn")
const TreeNode = preload("res://scripts/tree_node.gd")
const NpcNode = preload("res://scripts/npc_node.gd")
const LogPileNode = preload("res://scripts/log_pile_node.gd")

var _checks: int = 0
var _failures: int = 0

func _assert(cond: bool, msg: String) -> void:
	_checks += 1
	if not cond:
		_failures += 1
		print("  [FAIL] %s" % msg)
	else:
		print("  [PASS] %s" % msg)

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	print("\n--- Running UI Shell & Object Picking test suite ---")
	var scene = MainScene.instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame

	var world = scene.world
	var player = scene.player
	var camera = scene.camera
	var hud = scene.hud

	# 1. UI Shell R1: Wordmark removed
	_assert(hud.find_child("titles", true, false) == null, "Wordmark titles removed from HUD")

	# 2. UI Shell R4: Message log bounds and repeat collapse
	var msg_log = hud.message_log
	_assert(msg_log != null, "MessageLog component instantiated in HUD")
	hud.show_message("Test message")
	hud.show_message("Test message")
	hud.show_message("Test message")
	var last_msg = msg_log._messages[msg_log._messages.size() - 1]
	_assert(last_msg["count"] == 3, "Repeated messages collapsed to (x3)")
	_assert("(×3)" in last_msg["label"].text, "Label text reflects multiplier")

	for i in range(120):
		hud.show_message("Batch message %d" % i)
	_assert(msg_log._messages.size() == 100, "Message log capped strictly at 100 lines")

	# 3. UI Shell R3: 28-slot Bag Window (4x7)
	var bag = hud.bag_window
	_assert(bag != null, "BagWindow instantiated")
	_assert(bag.slots.size() == 28, "Bag has exactly 28 slots")
	_assert(bag.grid_container.columns == 4, "Bag grid has 4 columns")

	player.add_item("willow", "Willow Log", 4)
	bag.refresh()
	var slot0_icon = bag.slots[0].get_node("Icon").texture
	_assert(slot0_icon != null, "Slot 0 displays rendered item texture")
	_assert(hud.is_bag_open() == false, "Bag starts closed")
	hud.toggle_bag()
	_assert(hud.is_bag_open() == true, "toggle_bag opens bag")
	hud.toggle_journal()
	_assert(hud.is_journal_open() == true and hud.is_bag_open() == false, "Windows are mutually exclusive: opening journal closes bag")
	hud.toggle_journal()

	# 4. Object Picking R1 & R2: Physics raycast vs ground fallback
	# Raycast test: Mabb Truet at (21, 2)
	var mabb_world = world.tile_to_world(Vector2i(21, 2)) + Vector3(0, 0.9, 0)
	var mabb_screen = camera.unproject_position(mabb_world)
	var mabb_pick = scene.pick_object_or_ground(mabb_screen)
	_assert(mabb_pick.entity is NpcNode, "Picking at Mabb's model height returns NpcNode entity")

	# Raycast test: Pine Tree at (17, 1)
	var tree_tile = Vector2i(17, 1)
	var tree_world = world.tile_to_world(tree_tile) + Vector3(0, 3.5, 0)
	var tree_screen = camera.unproject_position(tree_world)
	var tree_pick = scene.pick_object_or_ground(tree_screen)
	_assert(tree_pick.entity is TreeNode and tree_pick.tile == tree_tile, "Picking at standing tree canopy returns TreeNode entity")

	# Felling tree shrinks pick shape to stump (R1)
	world.chop_tree(tree_tile)
	await process_frame
	var tree_pick_after = scene.pick_object_or_ground(tree_screen)
	_assert(tree_pick_after.entity != tree_pick.entity, "Canopy raycast no longer hits felled tree")

	# Ground-plane fallback (R2)
	var ground_screen = camera.unproject_position(world.tile_to_world(Vector2i(0, 4)))
	var ground_pick = scene.pick_object_or_ground(ground_screen)
	_assert(ground_pick.entity == null and ground_pick.tile == Vector2i(0, 4), "Ground click falls back to ground plane tile without entity")

	# Inverted-hull outline (R5)
	var npc = world.get_npc_at(Vector2i(21, 2))
	npc.set_highlighted(true)
	_assert(npc.is_highlighted == true, "NPC highlight enabled")
	npc.set_highlighted(false)
	_assert(npc.is_highlighted == false, "NPC highlight disabled")

	# Action advertising (R3)
	var npc_actions = npc.get_context_options({})
	_assert(npc_actions.size() >= 3, "NPC advertises context options")
	var prim_action = npc.get_primary_action()
	_assert(prim_action.get("action") == "talk", "NPC primary action is talk")

	# R8: Right-click menu opens on release, not on press
	# Press without release must not open menu
	var cur_mabb_screen = camera.unproject_position(world.tile_to_world(Vector2i(21, 2)) + Vector3(0, 0.9, 0))
	var rmb_press = InputEventMouseButton.new()
	rmb_press.button_index = MOUSE_BUTTON_RIGHT
	rmb_press.position = cur_mabb_screen
	rmb_press.global_position = cur_mabb_screen
	rmb_press.pressed = true
	scene._unhandled_input(rmb_press)
	_assert(not hud.context_menu.visible, "Context menu does not open on right press")

	# Release without drag (< 6px) opens menu
	var rmb_release = InputEventMouseButton.new()
	rmb_release.button_index = MOUSE_BUTTON_RIGHT
	rmb_release.position = cur_mabb_screen + Vector2(2, 2)
	rmb_release.global_position = cur_mabb_screen + Vector2(2, 2)
	rmb_release.pressed = false
	scene._unhandled_input(rmb_release)
	_assert(hud.context_menu.visible, "Context menu opens on right release within 6px threshold")
	hud.hide_context_menu()

	# Drag >= 6px suppresses menu on release
	scene._unhandled_input(rmb_press)
	var drag_ev = InputEventMouseMotion.new()
	drag_ev.position = mabb_screen + Vector2(10, 10)
	drag_ev.global_position = mabb_screen + Vector2(10, 10)
	drag_ev.relative = Vector2(10, 10)
	drag_ev.button_mask = MOUSE_BUTTON_MASK_RIGHT
	camera._unhandled_input(drag_ev)
	scene._unhandled_input(drag_ev)
	var rmb_release_drag = InputEventMouseButton.new()
	rmb_release_drag.button_index = MOUSE_BUTTON_RIGHT
	rmb_release_drag.position = mabb_screen # even if returned to start pos
	rmb_release_drag.global_position = mabb_screen
	rmb_release_drag.pressed = false
	scene._unhandled_input(rmb_release_drag)
	_assert(not hud.context_menu.visible, "Context menu suppressed if cursor dragged >= 6px before release")

	print("\nTEST SUMMARY: %d checks passed, %d failures" % [_checks, _failures])
	scene.queue_free()
	await process_frame
	if _failures > 0:
		quit(1)
	else:
		quit(0)
