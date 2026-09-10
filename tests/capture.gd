extends SceneTree

func _initialize() -> void:
	run.call_deferred()

func save_frame(path: String) -> void:
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	var error := image.save_png(path)
	print("Screenshot: %s (%s)" % [path, error_string(error)])

func run() -> void:
	root.size = Vector2i(1600, 1000)
	var game: Node3D = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await create_timer(1.3).timeout
	await save_frame("res://screenshots/willowmere.png")
	game.toggle_grid()
	game.travel_to(Vector2i(4, 4))
	await create_timer(0.35).timeout
	await save_frame("res://screenshots/walking.png")
	game.player.set_physics_process(false)
	game.camera.zoom = 11.0
	await create_timer(1.0).timeout
	await save_frame("res://screenshots/closeup.png")
	game.camera.toggle_character_view()
	await create_timer(1.0).timeout
	await save_frame("res://screenshots/character-ingame.png")
	game.hud.show_pause(true)
	await create_timer(0.1, true).timeout
	await save_frame("res://screenshots/controls.png")
	game.hud.hide_pause()
	print("Frame render metrics: %d objects, %d draw calls, %d primitives" % [
		Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME),
		Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)])
	game.queue_free()
	await process_frame
	quit()
