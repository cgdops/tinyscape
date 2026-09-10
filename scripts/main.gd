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
const TreeNode = preload("res://scripts/tree_node.gd")
const LogPileNode = preload("res://scripts/log_pile_node.gd")

var world: Node3D
var navigation: RefCounted
var player: Node3D
var camera: Camera3D
var hud: CanvasLayer
var game_state: RefCounted
var dialogue_runner: RefCounted
var grid_visible := false
var hovered_tile := Vector2i(999, 999)
var hovered_entity: Node = null

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
	dialogue_runner.dialogue_message_emitted.connect(func(msg: String): hud.show_message(msg))
	game_state.quest_state_changed.connect(func(q_id: String, new_state: String, _old: String):
		var q_info = QuestData.get_quest_info(q_id)
		var q_title = q_info.get("display_name", q_id)
		if new_state == "active":
			hud.show_message("Quest started: %s" % q_title)
		elif new_state == "complete":
			hud.show_message("Quest complete: %s" % q_title)
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
	_hover_material = _flat_material(Color(0.97, 0.9, 0.64, 0.28))
	_hover_marker.material_override = _hover_material
	_hover_marker.position.y = 0.02
	_hover_marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_hover_marker)

	_destination_marker = MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = 0.42
	disc.bottom_radius = 0.42
	disc.height = 0.04
	disc.radial_segments = 24
	_destination_marker.mesh = disc
	_destination_marker.material_override = _flat_material(Color(0.95, 0.77, 0.32, 0.58))
	_destination_marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_destination_marker.visible = false
	add_child(_destination_marker)

	_route = MultiMeshInstance3D.new()
	_route.multimesh = MultiMesh.new()
	_route.multimesh.transform_format = MultiMesh.TRANSFORM_3D
	var dot := CylinderMesh.new()
	dot.top_radius = 0.08
	dot.bottom_radius = 0.08
	dot.height = 0.03
	dot.radial_segments = 12
	_route.material_override = _flat_material(Color(0.95, 0.84, 0.52, 0.48))
	_route.multimesh.mesh = dot
	_route.multimesh.instance_count = 625
	_route.multimesh.visible_instance_count = 0
	_route.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_route)

# Object Picking & Ground fallback (R1, R2)
func pick_object_or_ground(screen_position: Vector2) -> Dictionary:
	var result := {
		"entity": null,
		"tile": Vector2i(999, 999)
	}
	if not is_instance_valid(camera):
		return result

	var origin := camera.project_ray_origin(screen_position)
	var direction := camera.project_ray_normal(screen_position)

	# 1. Physics raycast against interactive entities (Layer 2)
	var space_state = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(origin, origin + direction * 150.0, 2)
	query.collide_with_areas = true
	query.collide_with_bodies = true
	var hit = space_state.intersect_ray(query)

	if not hit.is_empty():
		var collider = hit.get("collider")
		var ent = _find_entity_ancestor(collider)
		if ent:
			result["entity"] = ent
			if ent.has_method("get_entity_tile"):
				result["tile"] = ent.get_entity_tile()
			return result

	# 2. Fallback to ground plane raycast
	var intersection = Plane(Vector3.UP, 0.0).intersects_ray(origin, direction)
	if intersection != null:
		result["tile"] = world.world_to_tile(intersection)

	return result

func _find_entity_ancestor(node: Node) -> Node:
	var cur = node
	while cur != null and cur != self and cur != world:
		if cur is TreeNode or cur is NpcNode or cur is LogPileNode:
			return cur
		cur = cur.get_parent()
	return null

func tile_under_cursor(screen_position: Vector2) -> Vector2i:
	var pick = pick_object_or_ground(screen_position)
	return pick.tile

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
	if is_instance_valid(hud.grid_button):
		hud.grid_button.text = "G  Grid on" if grid_visible else "G  Grid"

var _rmb_press_pos := Vector2.ZERO
var _rmb_press_target: Dictionary = {}
var _rmb_drag_exceeded := false

func _unhandled_input(event: InputEvent) -> void:
	if hud.is_dialogue_open():
		return

	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			hud.hide_context_menu()
			var pick = pick_object_or_ground(event.position)
			var ent: Node = pick.get("entity", null)
			var clicked_tile: Vector2i = pick.get("tile", Vector2i(999, 999))
			_cancel_pending_interaction()
			player.stop_chopping()
			# R4: Left-click on interactive object performs its primary action
			if ent != null and ent.has_method("get_primary_action"):
				var prim = ent.get_primary_action()
				var act_type = prim.get("action", "")
				if act_type == "chop":
					_start_woodcut_action(clicked_tile)
				elif act_type == "talk":
					_start_talk_action(clicked_tile)
				elif act_type == "deposit":
					_deposit_logs_action()
				else:
					travel_to(clicked_tile)
			else:
				travel_to(clicked_tile)
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			if event.pressed:
				hud.hide_context_menu()
				_rmb_press_pos = event.position
				_rmb_press_target = pick_object_or_ground(event.position)
				_rmb_drag_exceeded = false
			else:
				# R8: Right-click opens menu on release, not on press
				# Check if drag exceeded 6 px (matching camera.DRAG_THRESHOLD)
				var dist = event.position.distance_to(_rmb_press_pos)
				var camera_dragged = camera.rmb_dragged if is_instance_valid(camera) else false
				if not _rmb_drag_exceeded and not camera_dragged and dist < camera.DRAG_THRESHOLD:
					var ent: Node = _rmb_press_target.get("entity", null)
					var tile: Vector2i = _rmb_press_target.get("tile", Vector2i(999, 999))
					_handle_right_click(_rmb_press_pos, ent, tile)
				_rmb_press_target.clear()

	elif event is InputEventMouseMotion:
		if is_instance_valid(camera) and camera.orbiting:
			if event.position.distance_to(_rmb_press_pos) >= camera.DRAG_THRESHOLD:
				_rmb_drag_exceeded = true

func _handle_right_click(screen_pos: Vector2, arg1: Variant, arg2: Variant = null) -> void:
	var ent: Node = null
	var tile: Vector2i = Vector2i(999, 999)
	if arg2 != null:
		ent = arg1 as Node
		tile = arg2 as Vector2i
	elif arg1 is Vector2i:
		tile = arg1
		if world.is_tree_at(tile):
			ent = world.get_tree_data(tile).get("node", null)
		elif world.is_npc_at(tile):
			ent = world.get_npc_at(tile)
		elif tile == world.LOGPILE_TILE:
			ent = world.logpile_node
	elif arg1 is Node:
		ent = arg1
		if ent.has_method("get_entity_tile"):
			tile = ent.get_entity_tile()

	# R3: Right-click takes picked entity and builds context menu from advertised options
	if ent != null and ent.has_method("get_context_options"):
		var callbacks := {
			"chop": func(): _start_woodcut_action(tile),
			"talk": func(): _start_talk_action(tile),
			"deposit": func(): _deposit_logs_action(),
			"examine": func():
				if ent is NpcNode:
					hud.show_message(ent.examine)
				elif ent is TreeNode:
					var type_name: String = ent.tree_type.capitalize() + " Tree"
					if ent.is_stump:
						hud.show_message("The cut stump of a %s." % ent.tree_type)
					else:
						hud.show_message("A sturdy %s in the forest." % type_name)
				elif ent is LogPileNode:
					hud.show_message("Lumber clearing log pile. Mabb stacks timber here.")
		}
		var options = ent.get_context_options(callbacks)
		hud.show_context_menu(screen_pos, options)
		return

	# Fallback if tile matching is needed
	if not world.REGION.has_point(tile):
		return
	if world.is_npc_at(tile):
		_start_talk_action(tile)
	elif world.is_tree_at(tile):
		_start_woodcut_action(tile)
	elif tile == world.LOGPILE_TILE:
		_deposit_logs_action()

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
	hud.show_message("Mabb counts your logs without looking up. 'They'll float Thursday.' (+%dc)" % total_coins)

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

	# Object Picking & Inverted-Hull Hover Outline (R5, R6, R7)
	var mouse_pos = get_viewport().get_mouse_position()
	var pick = pick_object_or_ground(mouse_pos)
	var new_hovered_ent: Node = pick.get("entity", null)
	hovered_tile = pick.get("tile", Vector2i(999, 999))

	if camera_orbiting or dialogue_active:
		new_hovered_ent = null

	if hovered_entity != new_hovered_ent:
		if is_instance_valid(hovered_entity) and hovered_entity.has_method("set_highlighted"):
			hovered_entity.set_highlighted(false)
		hovered_entity = new_hovered_ent
		if is_instance_valid(hovered_entity) and hovered_entity.has_method("set_highlighted"):
			hovered_entity.set_highlighted(true)

	# Ground marker (R6): narrow job — walkable and blocked ground only. No green tree tint.
	var show_ground_marker = world.REGION.has_point(hovered_tile) and not camera_orbiting and not dialogue_active and (hovered_entity == null)
	_hover_marker.visible = show_ground_marker
	if show_ground_marker:
		_hover_marker.position = _marker_position(hovered_tile)
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
		if is_instance_valid(hud):
			hud.update_state(player)
		_update_route()
