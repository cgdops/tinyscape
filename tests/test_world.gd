extends SceneTree

const World = preload("res://scripts/world.gd")

func _initialize() -> void:
	var world = World.new()
	root.add_child(world)
	world.build()
	assert(world.REGION.size == Vector2i(50, 25), "World must span 50x25 across Willowmere and Forest")
	assert(not world.blocked.has(world.SPAWN), "Spawn must remain clear")
	for x in range(-1, 5):
		assert(not world.blocked.has(Vector2i(x, 4)), "Demo route must remain clear")
	# Connection gate between Willowmere and Forest must be open
	assert(not world.blocked.has(Vector2i(12, 3)), "Connection gate Z=3 must be open")
	assert(not world.blocked.has(Vector2i(12, 4)), "Connection gate Z=4 must be open")
	assert(not world.blocked.has(Vector2i(13, 3)), "Forest entrance Z=3 must be open")
	assert(not world.blocked.has(Vector2i(13, 4)), "Forest entrance Z=4 must be open")
	assert(world.tile_kind(Vector2i(7, 1)) == "water")
	assert(world.blocked.has(Vector2i(7, 1)))
	for x in range(4, 12):
		assert(world.tile_kind(Vector2i(x, 3)) == "bridge")
		assert(not world.blocked.has(Vector2i(x, 3)))
		assert(is_equal_approx(world.surface_height(Vector2i(x, 3)), 0.08))
	for z in range(-8, -3):
		for x in range(-8, -3):
			assert(world.blocked.has(Vector2i(x, z)), "Cottage footprint must be blocked")
	for z in range(1, 3):
		for x in range(-8, -4):
			assert(world.blocked.has(Vector2i(x, z)), "Market footprint must be blocked")
	for tile in [Vector2i(-3, -2), Vector2i(-2, -2), Vector2i(-3, -1), Vector2i(-2, -1)]:
		assert(world.blocked.has(tile), "Well footprint must be blocked")
	for tile in [Vector2i(5, 0), Vector2i(9, 0), Vector2i(11, 1), Vector2i(10, 5), Vector2i(9, 6), Vector2i(6, 6), Vector2i(5, 5)]:
		assert(world.blocked.has(tile), "Shore boulder footprint must be blocked")
	for tile in world.blocked:
		assert(world.REGION.has_point(tile), "Obstacles must be inside the map")
		assert(world.tile_kind(tile) in ["building", "tree", "water", "rock"])
	for z in range(-12, 13):
		for x in range(-12, 38):
			var tile = Vector2i(x, z)
			assert(world.world_to_tile(world.tile_to_world(tile)) == tile)
	assert(world.get_child_count() < 100, "Repeated art must be batched")
	world.set_grid_visible(true)
	assert(world.grid_overlay.visible)
	var before = world.get_child_count()
	world.build()
	assert(world.get_child_count() == before, "Build must be idempotent")
	print("WORLD PASS: ", world.blocked.size(), " blocked tiles; ", world.get_child_count(), " batched scene children; bridge, spawn, footprints, grid, coordinate round-trips verified.")
	world.queue_free()
	quit(0)
