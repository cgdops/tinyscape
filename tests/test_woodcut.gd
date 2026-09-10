extends SceneTree

const MainScene = preload("res://scenes/main.tscn")

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var scene = MainScene.instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame

	var world = scene.world
	var player = scene.player
	var nav = scene.navigation
	var hud = scene.hud

	# 1. Verify Forest section exists and trees are registered
	assert(world.trees.size() >= 10, "Forest must have at least 10 harvestable trees")
	var sample_tree_tile: Vector2i = Vector2i(17, 1)
	assert(world.is_tree_at(sample_tree_tile), "Pine tree at (17, 1) must be active tree")
	assert(world.blocked.has(sample_tree_tile), "Active tree must block tile")

	# 2. Verify tree approach logic
	scene._start_woodcut_action(sample_tree_tile)
	assert(player.motion.moving, "Player must begin walking toward tree")
	var dest = player.motion.destination
	var diff = sample_tree_tile - dest
	assert(absi(diff.x) <= 1 and absi(diff.y) <= 1, "Destination must be adjacent to tree")
	assert(nav.is_walkable(dest), "Destination must be walkable")

	# 3. Simulate arrival and chopping
	player.motion.position = Vector2(dest)
	player.motion.current_tile = dest
	player.motion.moving = false
	scene._process(0.1)

	assert(player.chopping, "Player must enter chopping state upon reaching adjacent tile")
	assert(player.target_tree_tile == sample_tree_tile, "Target tree tile must match")
	assert(player._axe_prop.visible, "Axe prop must become visible during chopping")

	# 4. Advance woodcutting and verify logs & XP award
	var old_logs = player.logs
	var old_xp = player.woodcut_xp
	player._award_woodcut()
	assert(player.logs == old_logs + 1, "Chopping must increment logs")
	assert(player.woodcut_xp == old_xp + 25, "Chopping must grant 25 Woodcutting XP")
	assert(player.woodcut_level >= 1, "Level must be at least 1")

	# 5. Verify chopping down into stump
	world.chop_tree(sample_tree_tile)
	assert(not world.is_tree_at(sample_tree_tile), "Felled tree is no longer active tree")
	assert(not world.blocked.has(sample_tree_tile), "Stump tile is unblocked")
	var tree_data = world.get_tree_data(sample_tree_tile)
	assert(tree_data["is_stump"] == true, "Tree must be marked as stump")
	assert(tree_data["stump"].visible == true, "Stump visual must be visible")
	assert(tree_data["canopy"].visible == false, "Tree canopy must be hidden")

	# 6. Verify respawn logic
	world.respawn_tree(sample_tree_tile)
	assert(world.is_tree_at(sample_tree_tile), "Respawned tree must be active tree again")
	assert(world.blocked.has(sample_tree_tile), "Respawned tree must be solid again")

	# 7. Context menu generation check
	scene._handle_right_click(Vector2(200, 200), sample_tree_tile)
	assert(hud.context_menu.visible, "Right-clicking tree must open context menu")
	hud.hide_context_menu()
	assert(not hud.context_menu.visible, "Hiding context menu must work")

	print("WOODCUT TEST PASS: Forest expansion, tree approach, chopping state, log/XP progression, felling and respawn verified!")
	scene.queue_free()
	await process_frame
	quit(0)
