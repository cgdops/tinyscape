extends Node3D

const World = preload("res://scripts/world.gd")
const Navigation = preload("res://scripts/navigation.gd")
const Player = preload("res://scripts/player.gd")
const GameCamera = preload("res://scripts/camera.gd")
const HUD = preload("res://scripts/hud.gd")
const GameState = preload("res://scripts/game_state.gd")
const DialogueRunner = preload("res://scripts/dialogue_runner.gd")
const QuestData = preload("res://scripts/quest_data.gd")
const NpcNode = preload("res://scripts/npc_node.gd")

var world: Node3D
var navigation: RefCounted
var player: Node3D
var camera: Camera3D
var hud: CanvasLayer
var game_state: RefCounted
var dialogue_runner: RefCounted
var grid_visible := false
var hovered_tile := Vector2i(999, 999)
var _hover_marker: MeshInstance3D
var _hover_material: StandardMaterial3D
var _destination_marker: MeshInstance3D
var _route: MultiMeshInstance3D
var _ui_timer := 0.0
var _time := 0.0

func _ready() -> void:
	_setup_light()
	game_state = GameState.new()
	world = World.new()
	world.name = "Willowmere"
	add_child(world)
	world.build()
	navigation = Navigation.new()
	navigation.configure(world.REGION, world.blocked)
	player = Player.new()
	player.name = "Wanderer"
	add_child(player)
	player.initialize(world, world.SPAWN)
	dialogue_runner = DialogueRunner.new()
	dialogue_runner.initialize(game_state, player)
	dialogue_runner.dialogue_message_emitted.connect(func(msg: String): hud.show_message(msg, 4.0))
	game_state.quest_state_changed.connect(func(q_id: String, new_state: String, _old: String):
		var q_info = QuestData.get_quest_info(q_id)
		var q_title = q_info.get("display_name", q_id)
		if new_state == "active":
			hud.show_message("Quest started: %s" % q_title, 4.0)
		elif new_state == "complete":
			hud.show_message("Quest complete: %s" % q_title, 4.0)
	)
	player.woodcut_progress.connect(func(_logs: int, _xp: int, _lvl: int, _msg: String):
		if not game_state.get_flag("chopped_a_tree"):
			game_state.set_flag("chopped_a_tree", true)
	)
	world.tree_state_changed.connect(func(_t: Vector2i, is_stump: bool):
		if is_stump and not game_state.get_flag("saw_offering"):
			game_state.set_flag("saw_offering", true)
	)
	camera = GameCamera.new()
	camera.name = "AdventureCamera"
	add_child(camera)
	camera.target = player
	_setup_markers()
	hud = HUD.new()
	add_child(hud)
	hud.initialize(world, player, camera, game_state, dialogue_runner)
	hud.grid_toggled.connect(toggle_grid)
	hud.recenter_requested.connect(camera.reset_view)
	hud.inspect_requested.connect(camera.toggle_character_view)
	hud.pause_changed.connect(func(_paused: bool): camera.orbiting = false)
	hud.destination_requested.connect(travel_to)
	world.set_grid_visible(grid_visible)
	world.tree_state_changed.connect(_on_tree_state_changed)

func _on_tree_state_changed(tile: Vector2i, is_stump: bool) -> void:
	navigation.set_walkable(tile, is_stump)

func _setup_light() -> void:
	var environment := WorldEnvironment.new()
	var settings := Environment.new()
	settings.background_mode = Environment.BG_COLOR
	settings.background_color = Color("8eaa9c")
	settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color = Color("d5e4d1")
	settings.ambient_light_energy = 0.40
	settings.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	settings.fog_enabled = true
	settings.fog_light_color = Color("a7bdaa")
	settings.fog_density = 0.0015
	environment.environment = settings
	add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-54, -32, 0)
	sun.light_color = Color("fff0cc")
	sun.light_energy = 0.85
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 75
	sun.shadow_bias = 0.06
	sun.shadow_normal_bias = 1.0
	add_child(sun)

func _flat_material(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return mat

func _setup_markers() -> void:
	_hover_marker = MeshInstance3D.new()
	var quad := PlaneMesh.new()
	quad.size = Vector2.ONE * world.TILE_SIZE * 0.94
	_hover_marker.mesh = quad
	_hover_material = _flat_material(Color(0.97, 0.9, 0.64, 0.32))
	_hover_marker.material_override = _hover_material
	_hover_marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_hover_marker)
	_destination_marker = MeshInstance3D.new()
	var ring := TorusMesh.new()
	ring.inner_radius = 0.35
	ring.outer_radius = 0.41
	ring.rings = 32
	ring.ring_segments = 6
	_destination_marker.mesh = ring
	_destination_marker.material_override = _flat_material(Color("f5d690"))
	_destination_marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_destination_marker.hide()
	add_child(_destination_marker)
	_route = MultiMeshInstance3D.new()
	var dot := CylinderMesh.new()
	dot.top_radius = 0.065
	dot.bottom_radius = 0.065
	dot.height = 0.013
	dot.radial_segments = 8
	dot.material = _flat_material(Color("eed799"))
	_route.multimesh = MultiMesh.new()
	_route.multimesh.transform_format = MultiMesh.TRANSFORM_3D
	_route.multimesh.mesh = dot
	_route.multimesh.instance_count = 625
	_route.multimesh.visible_instance_count = 0
	_route.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_route)

func tile_under_cursor(screen_position: Vector2) -> Vector2i:
	if not is_instance_valid(camera):
		return Vector2i(999, 999)
	var origin := camera.project_ray_origin(screen_position)
	var direction := camera.project_ray_normal(screen_position)
	var intersection = Plane(Vector3.UP, 0.0).intersects_ray(origin, direction)
	if intersection == null:
		return Vector2i(999, 999)
	return world.world_to_tile(intersection)

func travel_to(tile: Vector2i) -> bool:
	if not player.motion.request_destination(navigation, tile):
		hud.show_message("You can't walk there. Choose an open tile.")
		return false
	_destination_marker.position = _marker_position(tile)
	_destination_marker.visible = player.motion.moving
	_update_route()
	return true

func _marker_position(tile: Vector2i) -> Vector3:
	var point: Vector3 = world.tile_to_world(tile)
	point.y = 0.055
	if world.has_method("surface_height"):
		point.y += world.surface_height(tile)
	return point

func _update_route() -> void:
	var path: Array[Vector2i] = player.motion.remaining_path()
	_route.multimesh.visible_instance_count = path.size()
	for index in path.size():
		_route.multimesh.set_instance_transform(index, Transform3D(Basis.IDENTITY, _marker_position(path[index])))

var _pending_action: Dictionary = {} # { "kind": String, "tile": Vector2i }
var _active_npc_tile: Vector2i = Vector2i(999, 999)

func toggle_grid() -> void:
	grid_visible = not grid_visible
	world.set_grid_visible(grid_visible)
	hud.grid_button.text = "G   Grid on" if grid_visible else "G   Tile grid"

func _unhandled_input(event: InputEvent) -> void:
	if hud.is_dialogue_open():
		return
	if event is InputEventMouseButton and event.pressed:
		hud.hide_context_menu()
		var clicked_tile = tile_under_cursor(event.position)
		if event.button_index == MOUSE_BUTTON_LEFT:
			_cancel_pending_interaction()
			player.stop_chopping()
			travel_to(clicked_tile)
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			_handle_right_click(event.position, clicked_tile)

func _handle_right_click(screen_pos: Vector2, tile: Vector2i) -> void:
	if not world.REGION.has_point(tile):
		return
	if world.is_npc_at(tile):
		var npc = world.get_npc_at(tile)
		var options: Array[Dictionary] = [
			{
				"text": "Talk-to " + npc.display_name,
				"callback": func(): _start_talk_action(tile)
			},
			{
				"text": "Examine",
				"callback": func(): hud.show_message(npc.examine, 4.0)
			},
			{
				"text": "Cancel",
				"callback": func(): pass
			}
		]
		hud.show_context_menu(screen_pos, options)
		return
	if tile == world.LOGPILE_TILE:
		var options: Array[Dictionary] = [
			{
				"text": "Deposit logs",
				"callback": func(): _deposit_logs_action()
			},
			{
				"text": "Examine",
				"callback": func(): hud.show_message("Lumber clearing log pile. Mabb stacks timber here.", 3.0)
			},
			{
				"text": "Cancel",
				"callback": func(): pass
			}
		]
		hud.show_context_menu(screen_pos, options)
		return
	if world.is_tree_at(tile):
		var tree_info = world.get_tree_data(tile)
		var type_name: String = str(tree_info.get("type", "Tree")).capitalize() + " Tree"
		var options: Array[Dictionary] = [
			{
				"text": "Chop " + type_name,
				"callback": func(): _start_woodcut_action(tile)
			},
			{
				"text": "Examine",
				"callback": func(): hud.show_message("A sturdy %s in the forest." % type_name, 3.0)
			},
			{
				"text": "Cancel",
				"callback": func(): pass
			}
		]
		hud.show_context_menu(screen_pos, options)

func _deposit_logs_action() -> void:
	if player.inventory.is_empty():
		hud.show_message("You have no logs to deposit.")
		return
	var total_coins: int = 0
	var deposited_count: int = 0
	var remaining_inv: Array[Dictionary] = []
	for item in player.inventory:
		if item.get("name", "").ends_with("Log"):
			total_coins += int(item.get("value", 4))
			deposited_count += 1
		else:
			remaining_inv.append(item)
	if deposited_count == 0:
		hud.show_message("You have no logs to deposit.")
		return
	player.inventory = remaining_inv
	player.coins += total_coins
	world.set_logpile_has_logs(true)
	hud.show_message("Mabb counts your logs without looking up. 'They'll float Thursday.' (+%dc)" % total_coins, 4.0)

func _start_woodcut_action(tree_tile: Vector2i) -> void:
	if not world.is_tree_at(tree_tile):
		hud.show_message("There is no tree there to chop.")
		return

	var check = player.can_chop(tree_tile)
	if not check.allowed:
		hud.show_message(check.reason)
		return

	var diff = tree_tile - player.motion.current_tile
	if absi(diff.x) <= 1 and absi(diff.y) <= 1 and not (diff.x == 0 and diff.y == 0):
		_pending_action.clear()
		player.start_chopping(tree_tile)
		hud.show_message("You swing your axe at the tree...")
		return

	var best_tile = _find_adjacent_walkable(tree_tile)
	if best_tile != Vector2i(999, 999):
		_pending_action = { "kind": "chop", "tile": tree_tile }
		travel_to(best_tile)
		hud.show_message("Walking to tree...")
	else:
		hud.show_message("I can't reach that tree.")

func _start_talk_action(npc_tile: Vector2i) -> void:
	if not world.is_npc_at(npc_tile):
		return
	var npc = world.get_npc_at(npc_tile)
	var diff = npc_tile - player.motion.current_tile
	if absi(diff.x) <= 1 and absi(diff.y) <= 1 and not (diff.x == 0 and diff.y == 0):
		_pending_action.clear()
		_open_dialogue_with_npc(npc)
		return

	var best_tile = _find_adjacent_walkable(npc_tile)
	if best_tile != Vector2i(999, 999):
		_pending_action = { "kind": "talk", "tile": npc_tile }
		travel_to(best_tile)
		hud.show_message("Walking to %s..." % npc.display_name)
	else:
		hud.show_message("I can't reach %s." % npc.display_name)

func _find_adjacent_walkable(target_tile: Vector2i) -> Vector2i:
	var best_tile := Vector2i(999, 999)
	var shortest_path_len := 999999
	for dx in [-1, 0, 1]:
		for dz in [-1, 0, 1]:
			if dx == 0 and dz == 0:
				continue
			var candidate = target_tile + Vector2i(dx, dz)
			if navigation.is_walkable(candidate):
				var test_path = navigation.find_path(player.motion.current_tile, candidate)
				if not test_path.is_empty() or candidate == player.motion.current_tile:
					if test_path.size() < shortest_path_len:
						shortest_path_len = test_path.size()
						best_tile = candidate
	return best_tile

func _open_dialogue_with_npc(npc: NpcNode) -> void:
	player.stop_chopping()
	# Face each other
	var player_world_pos = world.tile_to_world(player.motion.current_tile)
	var npc_world_pos = world.tile_to_world(npc.home_tile)
	npc.turn_to_face(player_world_pos)
	player.model.rotation.y = atan2(npc_world_pos.x - player_world_pos.x, npc_world_pos.z - player_world_pos.z)

	_active_npc_tile = npc.home_tile
	hud.open_dialogue(npc.dialogue_file, npc.display_name)
	if is_instance_valid(hud.dialogue_box):
		hud.dialogue_box.dialogue_finished.connect(func():
			if world.is_npc_at(_active_npc_tile):
				world.get_npc_at(_active_npc_tile).reset_facing()
		, CONNECT_ONE_SHOT)

func _cancel_pending_interaction() -> void:
	_pending_action.clear()

func _process(delta: float) -> void:
	if player == null or player.motion == null:
		return
	_time += delta
	var camera_orbiting: bool = camera.orbiting if is_instance_valid(camera) else false
	var dialogue_active: bool = hud.is_dialogue_open() if is_instance_valid(hud) else false
	hovered_tile = tile_under_cursor(get_viewport().get_mouse_position())
	_hover_marker.visible = world.REGION.has_point(hovered_tile) and not camera_orbiting and not dialogue_active
	if _hover_marker.visible:
		_hover_marker.position = _marker_position(hovered_tile)
		if world.is_npc_at(hovered_tile):
			_hover_material.albedo_color = Color(0.95, 0.82, 0.35, 0.45)
		elif world.is_tree_at(hovered_tile):
			_hover_material.albedo_color = Color(0.25, 0.78, 0.40, 0.38)
		else:
			_hover_material.albedo_color = Color(0.97, 0.9, 0.64, 0.28) if navigation.is_walkable(hovered_tile) else Color(0.86, 0.32, 0.23, 0.40)
	_destination_marker.visible = player.motion.moving and not hud.is_dialogue_open()
	_destination_marker.scale = Vector3.ONE * (1.0 + sin(_time * 4.0) * 0.10)

	# Check if player arrived at pending action destination
	if not player.motion.moving and not _pending_action.is_empty():
		var target_tile: Vector2i = _pending_action.get("tile", Vector2i(999, 999))
		var action_kind: String = _pending_action.get("kind", "")
		var diff = target_tile - player.motion.current_tile
		if absi(diff.x) <= 1 and absi(diff.y) <= 1:
			_pending_action.clear()
			if action_kind == "chop" and world.is_tree_at(target_tile):
				player.start_chopping(target_tile)
				hud.show_message("You swing your axe at the tree...")
			elif action_kind == "talk" and world.is_npc_at(target_tile):
				_open_dialogue_with_npc(world.get_npc_at(target_tile))
		else:
			_pending_action.clear()

	_ui_timer += delta
	if _ui_timer >= 0.10:
		_ui_timer = 0.0
		hud.update_state(player)
		_update_route()
