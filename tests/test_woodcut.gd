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
	var sample_tree_tile: Vector2i = Vector2i(19, 7)
	assert(world.is_tree_at(sample_tree_tile), "Oak tree at (19, 7) must be active tree")
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
	assert(player.woodcut_xp == old_xp + 25, "Chopping oak must grant 25 Woodcutting XP")
	assert(player.woodcut_level >= 1, "Level must be at least 1")

	# 5. Verify multi-hit tree damage and felling into stump
	var test_tree_tile = Vector2i(25, -2) # untouched oak tree
	var test_hp = world.get_tree_data(test_tree_tile)["hit_points"]
	assert(test_hp == 4, "Oak tree must start with 4 hit points")
	var felled_early = world.damage_tree(test_tree_tile)
	assert(not felled_early, "First hit on oak must not fell tree")
	assert(world.get_tree_data(test_tree_tile)["hit_points"] == 3, "HP should decrease by 1")
	world.damage_tree(test_tree_tile) # HP 2
	world.damage_tree(test_tree_tile) # HP 1
	var felled_last = world.damage_tree(test_tree_tile) # HP 0 -> felled
	assert(felled_last, "Oak should be felled when HP reaches 0")
	assert(not world.is_tree_at(test_tree_tile), "Felled oak is no longer active tree")
	assert(not world.blocked.has(test_tree_tile), "Stump tile is unblocked")
	var oak_data = world.get_tree_data(test_tree_tile)
	assert(oak_data["is_stump"] == true, "Oak must be marked as stump")
	assert(oak_data["stump"].visible == true, "Stump visual must be visible")
	assert(oak_data["stump"].find_child("StumpMesh", true, false) != null, "Oak stump GLB mesh is instantiated")
	assert(oak_data["canopy"].visible == false, "Oak canopy must be hidden")

	# 6. Verify respawn logic
	world.respawn_tree(test_tree_tile)
	assert(world.is_tree_at(test_tree_tile), "Respawned tree must be active tree again")
	assert(world.blocked.has(test_tree_tile), "Respawned tree must be solid again")
	assert(world.get_tree_data(test_tree_tile)["hit_points"] == 4, "Respawned tree restores max HP")

	# 7. Level Gating (R2): Level 1 Wanderer cannot cut Pine (requires Level 15)
	var pine_tile = Vector2i(17, 1)
	player.woodcut_level = 1
	var pine_check = player.can_chop(pine_tile)
	assert(not pine_check.allowed, "Level 1 player cannot cut Pine")
	assert("level 15" in pine_check.reason.to_lower(), "Pine rejection message mentions level 15")
	player.woodcut_level = 15
	assert(player.can_chop(pine_tile).allowed, "Level 15 player can cut Pine")

	# 8. Inventory Limit (R1): Max 28 slots
	player.woodcut_level = 15
	for i in range(player.inventory.size(), 28):
		player.add_item("oak", "Oak Log", 6)
	assert(player.is_inventory_full(), "Inventory should be full at 28 items")
	var full_check = player.can_chop(sample_tree_tile)
	assert(not full_check.allowed, "Cannot chop when inventory is full")
	assert("full" in full_check.reason.to_lower(), "Rejection mentions full rucksack")

	# 9. Log Pile Deposit (R5): Deposit at (22, 1)
	assert(world.blocked.has(world.LOGPILE_TILE), "Log pile tile (22, 1) is blocked/solid")
	var prev_coins = player.coins
	scene._deposit_logs_action()
	assert(player.inventory.is_empty(), "Inventory must be cleared of logs after deposit")
	assert(player.coins > prev_coins, "Player must receive coins for deposited logs")
	assert(world.logpile_has_logs == true, "Log pile visual must switch to stacked logs")

	# 10. HUD Readout Verification (R6)
	hud.update_state(player)
	assert("Woodcutting: Lv" in hud.woodcut_label.text, "HUD displays Woodcutting level readout")
	assert("Logs 0/28" in hud.woodcut_label.text, "HUD displays logs 0/28 after deposit")
	assert(str(player.coins) + "c" in hud.woodcut_label.text, "HUD displays coins correctly")

	# 11. Context menu generation check
	scene._handle_right_click(Vector2(200, 200), sample_tree_tile)
	assert(hud.context_menu.visible, "Right-clicking tree must open context menu")
	hud.hide_context_menu()
	assert(not hud.context_menu.visible, "Hiding context menu must work")

	# Right-clicking Log Pile opens context menu with "Deposit logs"
	scene._handle_right_click(Vector2(200, 200), world.LOGPILE_TILE)
	assert(hud.context_menu.visible, "Right-clicking log pile opens context menu")
	hud.hide_context_menu()

	print("WOODCUT TEST PASS: All R1-R6 systems (inventory, level gates, multi-hit HP, log pile economy, HUD) verified!")
	scene.queue_free()
	await process_frame
	quit(0)
