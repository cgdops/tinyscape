extends Node3D

signal movement_changed(walking: bool)
signal woodcut_progress(logs: int, xp: int, level: int, message: String)

const Movement = preload("res://scripts/movement.gd")
var motion: RefCounted
var model: Node3D
var animation_player: AnimationPlayer
var idle_clip := ""
var walk_clip := ""
var woodcut_clip := ""
var steps := 0
var _world: Node3D
var _was_moving := false

# Woodcutting Skill & Chopping state
var woodcut_level: int = 1
var woodcut_xp: int = 0
var logs: int = 0
var chopping: bool = false
var target_tree_tile: Vector2i = Vector2i(999, 999)
var _chop_timer: float = 0.0
var _axe_prop: Node3D

func initialize(world: Node3D, start: Vector2i) -> void:
	_world = world
	motion = Movement.new(start, 2.35)
	motion.tile_reached.connect(func(_tile: Vector2i): steps += 1)
	position = world.tile_to_world(start)
	var asset := load("res://assets/models/adventurer_woodcutting.glb") as PackedScene
	if asset == null:
		push_error("Adventurer asset failed to load. Reimport assets/models/adventurer_woodcutting.glb.")
		return
	model = asset.instantiate()
	add_child(model)
	_find_animation_player(model)
	if animation_player:
		for clip in animation_player.get_animation_list():
			var lower = clip.to_lower()
			if "idle" in lower:
				idle_clip = clip
			elif "walk" in lower:
				walk_clip = clip
			elif "wood" in lower or "chop" in lower or "cut" in lower:
				woodcut_clip = clip
		for clip in [idle_clip, walk_clip, woodcut_clip]:
			if not clip.is_empty():
				animation_player.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
		if not idle_clip.is_empty():
			animation_player.play(idle_clip)

	# Locate the rigged WoodCuttingAxe mesh attached to AxeSocket.R
	_axe_prop = model.find_child("WoodCuttingAxe", true, false)
	if _axe_prop:
		_axe_prop.visible = false

	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.36
	torus.outer_radius = 0.40
	torus.rings = 32
	torus.ring_segments = 6
	ring.mesh = torus
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("edda9b")
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring.material_override = mat
	ring.position.y = 0.035
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ring)
	model.rotation.y = 0.5

func start_chopping(tree_tile: Vector2i) -> void:
	target_tree_tile = tree_tile
	chopping = true
	_chop_timer = 1.8
	if _axe_prop:
		_axe_prop.visible = true
	# Face the tree
	var delta_tile = Vector2(target_tree_tile - motion.current_tile)
	if delta_tile.length_squared() > 0:
		model.rotation.y = atan2(delta_tile.x, delta_tile.y)
	if animation_player and not woodcut_clip.is_empty():
		animation_player.play(woodcut_clip, 0.15)

func stop_chopping() -> void:
	chopping = false
	target_tree_tile = Vector2i(999, 999)
	if _axe_prop:
		_axe_prop.visible = false
	if animation_player:
		var clip := walk_clip if (motion and motion.moving) else idle_clip
		if not clip.is_empty():
			animation_player.play(clip, 0.18)

func _find_animation_player(node: Node) -> void:
	if node is AnimationPlayer:
		animation_player = node
	for child in node.get_children():
		_find_animation_player(child)

func _physics_process(delta: float) -> void:
	if motion == null:
		return

	if motion.moving and chopping:
		stop_chopping()

	motion.advance(delta)
	position.x = motion.position.x * _world.TILE_SIZE
	position.z = motion.position.y * _world.TILE_SIZE
	if _world.has_method("surface_height"):
		position.y = move_toward(position.y, _world.surface_height(_world.world_to_tile(position)), delta * 1.5)
	if motion.moving and model:
		var facing := atan2(motion.direction.x, motion.direction.y)
		model.rotation.y = lerp_angle(model.rotation.y, facing, 1.0 - exp(-16.0 * delta))
	if motion.moving != _was_moving:
		_was_moving = motion.moving
		if animation_player and not chopping:
			var clip := walk_clip if motion.moving else idle_clip
			if not clip.is_empty():
				animation_player.play(clip, 0.18)
		movement_changed.emit(motion.moving)

	# Chopping animation and progress
	if chopping and not motion.moving:
		# Verify tree still exists and hasn't already been felled
		if not _world.is_tree_at(target_tree_tile):
			stop_chopping()
			woodcut_progress.emit(logs, woodcut_xp, woodcut_level, "The tree has been cut down.")
			return

		_chop_timer -= delta
		if _chop_timer <= 0.0:
			_chop_timer = 1.8
			_award_woodcut()

func _award_woodcut() -> void:
	logs += 1
	var xp_gained = 25
	woodcut_xp += xp_gained
	var next_level = 1 + int(woodcut_xp / 100.0)
	var leveled_up = next_level > woodcut_level
	woodcut_level = next_level

	var msg = "You get some logs. (Woodcutting XP: +%d)" % xp_gained
	if leveled_up:
		msg = "Congratulations! Your Woodcutting level is now %d!" % woodcut_level

	# Felling check (chance to turn tree into a stump)
	var felled = false
	if logs % 3 == 0:
		felled = _world.chop_tree(target_tree_tile)
		if felled:
			msg += " You chopped down the tree!"
			stop_chopping()

	woodcut_progress.emit(logs, woodcut_xp, woodcut_level, msg)
