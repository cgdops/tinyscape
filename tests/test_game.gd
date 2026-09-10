extends SceneTree

var checks := 0
var failures := 0
var game: Node3D

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)

func _initialize() -> void:
	run.call_deferred()

func mouse_button(button: MouseButton, point: Vector2, pressed := true) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = button
	event.position = point
	event.global_position = point
	event.pressed = pressed
	root.push_input(event, true)

func key(code: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = true
	root.push_input(event, true)
	event = event.duplicate()
	event.pressed = false
	root.push_input(event, true)

func find_skeleton(node: Node) -> Skeleton3D:
	if node is Skeleton3D:
		return node
	for child in node.get_children():
		var found := find_skeleton(child)
		if found:
			return found
	return null

func run() -> void:
	var scene := load("res://scenes/main.tscn") as PackedScene
	if scene == null:
		push_error("Main scene must load")
		quit(1)
		return
	game = scene.instantiate()
	root.add_child(game)
	await process_frame
	await process_frame
	check(game.player.model != null, "Blender model must load")
	check(game.player.animation_player != null, "Imported model must contain an AnimationPlayer")
	check(not game.player.idle_clip.is_empty() and not game.player.walk_clip.is_empty(), "Must import named Idle and Walk clips")
	var skeleton := find_skeleton(game.player.model)
	check(skeleton != null and skeleton.get_bone_count() >= 15, "Character must have a usable skeleton")
	var animator: AnimationPlayer = game.player.animation_player
	for clip in [game.player.idle_clip, game.player.walk_clip]:
		animator.play(clip)
		animator.seek(0.15, true)
		var before: Array[Transform3D] = []
		for bone in skeleton.get_bone_count():
			before.append(skeleton.get_bone_pose(bone))
		animator.seek(0.55, true)
		var changed := false
		for bone in skeleton.get_bone_count():
			if not before[bone].is_equal_approx(skeleton.get_bone_pose(bone)):
				changed = true
		check(changed, "%s must animate the skeleton, not just have a clip name" % clip)
	animator.play(game.player.idle_clip)
	var destination: Vector2i = game.world.SPAWN + Vector2i(2, 0)
	check(game.navigation.is_walkable(destination), "Input-test destination must be open")
	var screen_point: Vector2 = game.camera.unproject_position(game.world.tile_to_world(destination))
	check(game.tile_under_cursor(screen_point) == destination, "Screen picking must map back to requested tile")
	mouse_button(MOUSE_BUTTON_LEFT, screen_point)
	mouse_button(MOUSE_BUTTON_LEFT, screen_point, false)
	await create_timer(0.20).timeout
	check(game.player.motion.moving, "Actual left-click must start movement")
	check(animator.current_animation == game.player.walk_clip, "Movement must play the imported Walk animation")
	check(game.player.position.distance_to(game.world.tile_to_world(game.world.SPAWN)) > 0.05, "Player node must move through the 3D world")
	var route_destination: Vector2i = game.player.motion.destination
	mouse_button(MOUSE_BUTTON_LEFT, Vector2(root.get_visible_rect().size.x - 50, 70))
	mouse_button(MOUSE_BUTTON_LEFT, Vector2(root.get_visible_rect().size.x - 50, 70), false)
	check(game.player.motion.destination == route_destination, "Clicking HUD must not issue world travel")
	key(KEY_ESCAPE)
	check(paused and game.hud.pause_screen.visible, "Escape must pause the game")
	var paused_position: Vector3 = game.player.position
	await create_timer(0.15, true).timeout
	check(game.player.position == paused_position, "Paused game must not advance movement")
	key(KEY_ESCAPE)
	check(not paused and not game.hud.pause_screen.visible, "Escape must resume game")
	await create_timer(1.3).timeout
	check(game.player.motion.current_tile == destination, "Clicked destination must be reached")
	check(not game.player.motion.moving and animator.current_animation == game.player.idle_clip, "Arrival must return to imported Idle")
	key(KEY_G)
	check(game.grid_visible, "G must toggle grid on")
	key(KEY_G)
	check(not game.grid_visible, "G must toggle grid off")
	var old_zoom: float = game.camera.zoom
	mouse_button(MOUSE_BUTTON_WHEEL_UP, screen_point)
	check(game.camera.zoom < old_zoom, "Scroll must zoom camera")
	key(KEY_HOME)
	check(game.camera.zoom == 24.0, "Home must reset camera")
	var yaw_before_v: float = game.camera.yaw
	key(KEY_V)
	check(game.camera.zoom == 4.0 and is_equal_approx(game.camera.yaw, yaw_before_v), "V must set close preset zoom to 4.0 without altering yaw")
	key(KEY_V)
	check(game.camera.zoom == 24.0, "V must restore the previous zoom")
	mouse_button(MOUSE_BUTTON_RIGHT, screen_point)
	var old_yaw: float = game.camera.yaw
	var drag := InputEventMouseMotion.new()
	drag.position = screen_point + Vector2(70, 0)
	drag.relative = Vector2(70, 0)
	drag.button_mask = MOUSE_BUTTON_MASK_RIGHT
	root.push_input(drag, true)
	mouse_button(MOUSE_BUTTON_RIGHT, Vector2(root.get_visible_rect().size.x - 50, 70), false)
	check(not is_equal_approx(game.camera.yaw, old_yaw), "Right-drag must orbit the camera")
	check(not game.camera.orbiting, "Releasing right-drag over HUD must stop orbiting")
	mouse_button(MOUSE_BUTTON_RIGHT, screen_point)
	check(game.camera.orbiting, "Begin drag before pausing")
	key(KEY_ESCAPE)
	mouse_button(MOUSE_BUTTON_RIGHT, screen_point, false)
	key(KEY_ESCAPE)
	check(not game.camera.orbiting, "Releasing a drag during pause must not latch orbit on resume")
	var map: Control = game.hud.minimap
	var map_destination := Vector2i(0, 4)
	var local_point := Vector2(14, 30) + (Vector2(map_destination) + Vector2(12.5, 12.5)) / 25.0 * Vector2(176, 176)
	var map_point: Vector2 = map.get_global_transform() * local_point
	mouse_button(MOUSE_BUTTON_LEFT, map_point)
	mouse_button(MOUSE_BUTTON_LEFT, map_point, false)
	check(game.player.motion.destination == map_destination, "Actual minimap click must select matching tile")
	print("Game integration: %s checks, %s failures" % [checks, failures])
	game.queue_free()
	await process_frame
	quit(1 if failures else 0)
