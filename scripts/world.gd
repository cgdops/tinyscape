extends Node3D
## Authored Willowmere diorama. Meshes sharing a shape and palette are batched.

const TILE_SIZE = 1.35
const REGION = Rect2i(-12, -12, 50, 25)
const WILLOWMERE_REGION = Rect2i(-12, -12, 25, 25)
const FOREST_REGION = Rect2i(13, -12, 25, 25)
const SPAWN = Vector2i(-1, 4)

signal tree_state_changed(tile: Vector2i, is_stump: bool)

var blocked: Array[Vector2i] = []
var grid_overlay: Node3D
var trees: Dictionary = {} ## Vector2i -> Dictionary { type, height, is_stump, respawn_timer, node }
var _kinds: Dictionary = {}
var _batches: Dictionary = {}
var _materials: Dictionary = {}
var _meshes: Dictionary = {}
var _rng = RandomNumberGenerator.new()
var _built = false

const COLORS = {
	"grass_a": "71844b", "grass_b": "75884e", "grass_c": "798b52", "grass_d": "6d8048",
	"path_a": "b6a077", "path_b": "bda77d", "path_c": "af9871",
	"soil": "75694d", "earth": "8b7958", "earth_dark": "5d6049", "stone": "b6b39a",
	"stone_light": "c8c1a5", "stone_dark": "858a78", "plaster": "e1cfaa",
	"wood": "573f2e", "wood_light": "907044", "plank": "ab8653", "wood_dark": "3a3026",
	"roof": "a75339", "roof_light": "b96142", "roof_dark": "8f4836", "window": "29494a",
	"pine": "2c5140", "pine_light": "3b6350", "pine_dark": "284636",
	"oak": "758747", "oak_light": "8d9c55", "oak_dark": "607840",
	"flower_pink": "d497a1", "flower_cream": "e8d694", "flower_white": "ece5c5",
	"reed": "91965b", "reed_tip": "5c4836", "canvas": "e9d5a5", "canvas_green": "637c61",
	"iron": "414c46", "brass": "d4b16d", "glow": "f1ca79", "apple": "b95638",
	"water": "579b9f", "ripple": "98c4ba", "lily": "7d9b68"
}

func build() -> void:
	if _built:
		return
	_built = true
	_rng.seed = 92107
	_prepare_materials()
	_define_map()
	_ground()
	_cottage(Vector2(-6, -6))
	_market(Vector2(-6.5, 2.5))
	_well(Vector2(-2.1, -1.7))
	_bridge()
	_trees()
	_forest()
	_fences()
	_details()
	_flush_batches()
	_make_grid()

func tile_to_world(tile: Vector2i) -> Vector3:
	return Vector3(tile.x * TILE_SIZE, 0.0, tile.y * TILE_SIZE)

func world_to_tile(point: Vector3) -> Vector2i:
	return Vector2i(roundi(point.x / TILE_SIZE), roundi(point.z / TILE_SIZE))

func tile_kind(tile: Vector2i) -> String:
	return _kinds.get(tile, "grass")

func surface_height(tile: Vector2i) -> float:
	return 0.08 if tile_kind(tile) == "bridge" else 0.0

func set_grid_visible(value: bool) -> void:
	if is_instance_valid(grid_overlay):
		grid_overlay.visible = value

func _block(tile: Vector2i, kind: String) -> void:
	if not blocked.has(tile):
		blocked.append(tile)
	_kinds[tile] = kind

func _unblock(tile: Vector2i, new_kind: String = "grass") -> void:
	blocked.erase(tile)
	_kinds[tile] = new_kind

func _block_rect(rect: Rect2i, kind: String) -> void:
	for z in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			_block(Vector2i(x, z), kind)

func _define_map() -> void:
	for z in range(-11, 12):
		for x in range(-1, 2):
			_kinds[Vector2i(x, z)] = "path"
	for x in range(-11, 12):
		for z in range(3, 5):
			_kinds[Vector2i(x, z)] = "path"
	for x in range(-7, 0):
		_kinds[Vector2i(x, -3)] = "path"
	for z in range(-3, 4):
		_kinds[Vector2i(-6, z)] = "path"
	var pond_rows = {0: Vector2i(6, 8), 1: Vector2i(5, 9), 2: Vector2i(5, 10), 3: Vector2i(5, 10), 4: Vector2i(5, 10), 5: Vector2i(6, 9), 6: Vector2i(7, 8)}
	for z in pond_rows:
		var limits: Vector2i = pond_rows[z]
		for x in range(limits.x, limits.y + 1):
			_block(Vector2i(x, z), "water")
	for x in range(4, 12):
		var tile = Vector2i(x, 3)
		blocked.erase(tile)
		_kinds[tile] = "bridge"
	_block_rect(Rect2i(-8, -8, 5, 5), "building")
	_block_rect(Rect2i(-8, 1, 4, 2), "building")
	_block_rect(Rect2i(-3, -2, 2, 2), "building")

	# Forest Section Paths & Clearings
	# Highway path connecting east from bridge through gate into forest center
	for x in range(12, 36):
		for z in range(3, 5):
			_kinds[Vector2i(x, z)] = "path"
	# Winding northern forest trail
	for z in range(-7, 4):
		for x in range(23, 25):
			_kinds[Vector2i(x, z)] = "path"
	for x in range(17, 24):
		_kinds[Vector2i(x, -6)] = "path"
	# Southern forest clearing trail
	for z in range(5, 10):
		for x in range(26, 28):
			_kinds[Vector2i(x, z)] = "path"
	# Forest lumber camp clearing
	for x in range(21, 27):
		for z in range(1, 4):
			_kinds[Vector2i(x, z)] = "path"

func _prepare_materials() -> void:
	for key in COLORS:
		var mat = StandardMaterial3D.new()
		mat.albedo_color = Color(COLORS[key])
		mat.roughness = 0.94
		if key == "glow":
			mat.emission_enabled = true
			mat.emission = Color("e1b65f")
			mat.emission_energy_multiplier = 0.45
		_materials[key] = mat
	var water_material = ShaderMaterial.new()
	water_material.shader = load("res://assets/shaders/water.gdshader")
	_materials["water"] = water_material
	var cube = BoxMesh.new()
	cube.size = Vector3.ONE
	_meshes["box"] = cube
	var cylinder = CylinderMesh.new()
	cylinder.top_radius = 1.0
	cylinder.bottom_radius = 1.0
	cylinder.height = 1.0
	cylinder.radial_segments = 8
	_meshes["cylinder"] = cylinder
	var cone = CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = 1.0
	cone.height = 1.0
	cone.radial_segments = 7
	_meshes["cone"] = cone
	var sphere = SphereMesh.new()
	sphere.radius = 1.0
	sphere.height = 2.0
	sphere.radial_segments = 8
	sphere.rings = 4
	_meshes["sphere"] = sphere

func _stamp(shape: String, material: String, position: Vector3, size: Vector3, rotation: Vector3 = Vector3.ZERO) -> void:
	var key = shape + ":" + material
	if not _batches.has(key):
		_batches[key] = []
	var basis = Basis.from_euler(rotation).scaled_local(size)
	_batches[key].append(Transform3D(basis, position))

func _box(material: String, position: Vector3, size: Vector3, rotation: Vector3 = Vector3.ZERO) -> void:
	_stamp("box", material, position, size, rotation)

func _beam(material: String, start: Vector3, finish: Vector3, width: float) -> void:
	var direction = finish - start
	var basis = Basis(Quaternion(Vector3.UP, direction.normalized())).scaled_local(Vector3(width, direction.length(), width))
	var key = "box:" + material
	if not _batches.has(key):
		_batches[key] = []
	_batches[key].append(Transform3D(basis, (start + finish) * 0.5))

func _point(tile: Vector2, height: float = 0.0) -> Vector3:
	return Vector3(tile.x * TILE_SIZE, height, tile.y * TILE_SIZE)

func _ground() -> void:
	# Willowmere + Forest combined foundation slab: 50 tiles wide x 25 tiles deep
	# Center of [-12, 37] is x = 12.5; world x = 12.5 * 1.35 = 16.875
	_box("earth_dark", Vector3(16.875, -1.4, 0), Vector3(67.6, 1.15, 33.85))
	_box("earth", Vector3(16.875, -0.81, 0), Vector3(67.5, 0.34, 33.8))
	for z in range(-12, 13):
		for x in range(-12, 38):
			var tile = Vector2i(x, z)
			var kind = tile_kind(tile)
			var p = tile_to_world(tile)
			var palette: String
			if kind == "water" or (kind == "bridge" and x >= 5 and x <= 10):
				_box("soil", p + Vector3(0, -0.48, 0), Vector3(TILE_SIZE, 0.34, TILE_SIZE))
				_box("water", p + Vector3(0, -0.20, 0), Vector3(TILE_SIZE + 0.002, 0.24, TILE_SIZE + 0.002))
				continue
			if kind == "path" or kind == "bridge":
				palette = ["path_a", "path_b", "path_c"][_rng.randi_range(0, 2)]
			else:
				palette = ["grass_a", "grass_b", "grass_c", "grass_d"][_rng.randi_range(0, 3)]
			_box(palette, p + Vector3(0, -0.325, 0), Vector3(TILE_SIZE, 0.65, TILE_SIZE))
	# Strata and embedded stones along the exposed outer diorama edges.
	for i in range(68):
		var a = -16.25 + float(i) * 0.98
		var y = _rng.randf_range(-1.25, -0.45)
		_stamp("sphere", "stone_dark", Vector3(a, y, 16.92), Vector3(_rng.randf_range(0.18, 0.42), 0.12, 0.06))
		_stamp("sphere", "stone_dark", Vector3(a, y, -16.92), Vector3(_rng.randf_range(0.18, 0.42), 0.12, 0.06))
	for i in range(34):
		var a = -16.25 + float(i) * 0.98
		var y = _rng.randf_range(-1.25, -0.45)
		_stamp("sphere", "stone_dark", Vector3(-16.92, y, a), Vector3(0.06, 0.12, _rng.randf_range(0.18, 0.42)))
		_stamp("sphere", "stone_dark", Vector3(50.67, y, a), Vector3(0.06, 0.12, _rng.randf_range(0.18, 0.42)))

func _cottage(tile: Vector2) -> void:
	var p = _point(tile)
	var width = 5.7
	var depth = 5.1
	_box("stone_dark", p + Vector3(0, 0.18, 0), Vector3(width + 0.22, 0.36, depth + 0.22))
	_box("plaster", p + Vector3(0, 1.65, 0), Vector3(width, 2.75, depth))
	# Individually coursed stone foundation, with alternate mortar lines.
	for side in [-1.0, 1.0]:
		for i in range(8):
			_box("stone_light" if i % 3 == 0 else "stone", p + Vector3(-2.52 + i * 0.72, 0.33, side * 2.58), Vector3(0.67, 0.45, 0.17))
		for i in range(7):
			_box("stone", p + Vector3(side * 2.89, 0.32, -2.2 + i * 0.73), Vector3(0.17, 0.43, 0.67))
	# Studs, cross braces, and continuous timber plates.
	for x in [-2.84, -1.4, 1.4, 2.84]:
		for z in [-2.59, 2.59]:
			_box("wood", p + Vector3(x, 1.75, z), Vector3(0.16, 2.65, 0.16))
	for y in [0.62, 2.95]:
		for z in [-2.59, 2.59]:
			_box("wood", p + Vector3(0, y, z), Vector3(width + 0.16, 0.18, 0.18))
		for x in [-2.9, 2.9]:
			_box("wood", p + Vector3(x, y, 0), Vector3(0.18, 0.18, depth))
	for x in [-2.12, 2.12]:
		_beam("wood", p + Vector3(x - 0.61, 0.77, 2.61), p + Vector3(x + 0.61, 2.8, 2.61), 0.115)
	for z in [-1.72, 0.0, 1.72]:
		_box("wood", p + Vector3(2.93, 1.77, z), Vector3(0.17, 2.6, 0.15))
	# Front door, carved lintel, raised stone doorstep.
	_box("wood_dark", p + Vector3(0, 1.35, 2.635), Vector3(1.20, 2.0, 0.12))
	for i in range(6):
		_box("wood_light" if i % 2 else "wood", p + Vector3(-0.45 + i * 0.18, 1.36, 2.715), Vector3(0.166, 1.87, 0.06))
	for y in [0.88, 1.8]:
		_box("iron", p + Vector3(0, y, 2.76), Vector3(0.95, 0.07, 0.05))
	_stamp("sphere", "brass", p + Vector3(0.32, 1.35, 2.83), Vector3.ONE * 0.075)
	_box("wood", p + Vector3(0, 2.45, 2.68), Vector3(1.48, 0.2, 0.23))
	_box("stone_light", p + Vector3(0, 0.075, 2.91), Vector3(1.5, 0.15, 0.55))
	for x in [-2.02, 2.02]:
		_window(p + Vector3(x, 1.9, 2.69), false)
	_window(p + Vector3(2.96, 1.93, 0.8), true)
	_window(p + Vector3(2.96, 1.93, -1.65), true)
	# Front and rear gable triangles; split roof has visible shingle courses.
	var rise = 1.8
	for z in [-2.56, 2.56]:
		_triangle(p + Vector3(-2.86, 3.04, z), p + Vector3(2.86, 3.04, z), p + Vector3(0, 4.84, z), "plaster")
		_box("wood", p + Vector3(0, 3.9, z + 0.035), Vector3(0.17, 1.8, 0.18))
		_beam("wood", p + Vector3(-2.86, 3.08, z), p + Vector3(0, 4.89, z), 0.15)
		_beam("wood", p + Vector3(0, 4.89, z), p + Vector3(2.86, 3.08, z), 0.15)
	var pitch = atan2(rise, 2.86)
	for side in [-1.0, 1.0]:
		_box("roof_dark", p + Vector3(side * 1.58, 3.88, 0), Vector3(3.83, 0.15, 5.9), Vector3(0, 0, -side * pitch))
		for row in range(6):
			var xx = 0.23 + row * 0.565
			var yy = 4.92 - xx * tan(pitch)
			for column in range(11):
				var zz = -2.73 + column * 0.535 + (0.04 if row % 2 else 0.0)
				var roof_palette = ["roof", "roof_light", "roof_dark"][_rng.randi_range(0, 2)]
				_box(roof_palette, p + Vector3(side * xx, yy, zz), Vector3(0.70, 0.10, 0.52), Vector3(0, 0, -side * pitch))
		_beam("wood", p + Vector3(side * 3.22, 2.89, -2.98), p + Vector3(side * 3.22, 2.89, 2.98), 0.14)
	for z in range(12):
		_box("roof_light", p + Vector3(0, 4.99, -2.81 + z * 0.51), Vector3(0.35, 0.2, 0.48))
	_box("stone_dark", p + Vector3(1.7, 4.35, -1.47), Vector3(0.72, 2.15, 0.77))
	for y in range(6):
		_box("stone" if y % 2 else "stone_light", p + Vector3(1.7, 3.56 + y * 0.34, -1.47), Vector3(0.78, 0.29, 0.8))
	_box("stone_dark", p + Vector3(1.7, 5.48, -1.47), Vector3(0.98, 0.18, 1.0))
	_box("wood_dark", p + Vector3(1.7, 5.58, -1.47), Vector3(0.52, 0.03, 0.54))
	# Log pile tucked beside the western wall.
	for i in range(5):
		_stamp("cylinder", "wood", p + Vector3(-3.1, 0.22 + (i / 3) * 0.32, -0.8 + (i % 3) * 0.36), Vector3(0.17, 1.1, 0.17), Vector3(0, 0, PI * 0.5))
	_lantern(p + Vector3(0.95, 2.15, 3.0), 0.75)

func _triangle(a: Vector3, b: Vector3, c: Vector3, material: String) -> void:
	var surface = SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for vertex in [a, b, c, c, b, a]:
		surface.add_vertex(vertex)
	surface.generate_normals()
	var mesh_instance = MeshInstance3D.new()
	mesh_instance.mesh = surface.commit()
	mesh_instance.material_override = _materials[material]
	add_child(mesh_instance)

func _window(p: Vector3, side: bool) -> void:
	var rotation = Vector3(0, PI * 0.5 if side else 0.0, 0)
	var basis = Basis.from_euler(rotation)
	_box("wood", p, Vector3(1.02, 1.16, 0.13), rotation)
	_box("window", p + basis * Vector3(0, 0, 0.085), Vector3(0.83, 0.93, 0.04), rotation)
	_box("wood_light", p + basis * Vector3(0, 0, 0.13), Vector3(0.07, 1.0, 0.06), rotation)
	_box("wood_light", p + basis * Vector3(0, 0.04, 0.13), Vector3(0.9, 0.07, 0.06), rotation)
	_box("wood_light", p + basis * Vector3(0, -0.62, 0.12), Vector3(1.17, 0.13, 0.34), rotation)
	for direction in [-1.0, 1.0]:
		_box("canvas_green", p + basis * Vector3(direction * 0.69, 0, 0.01), Vector3(0.26, 1.05, 0.08), rotation)
		for yy in [-0.34, 0.33]:
			_box("wood", p + basis * Vector3(direction * 0.69, yy, 0.065), Vector3(0.28, 0.06, 0.04), rotation)

func _market(tile: Vector2) -> void:
	var p = _point(tile)
	# Stall occupies the two tiles north of the street; open counter faces south.
	p.z -= 1.4
	for x in [-1.9, 1.9]:
		for z in [-1.02, 1.02]:
			_box("wood", p + Vector3(x, 1.37, z), Vector3(0.14, 2.75, 0.14))
	for i in range(9):
		_box("canvas" if i % 2 == 0 else "canvas_green", p + Vector3(-1.78 + i * 0.445, 2.76, 0), Vector3(0.445, 0.10, 2.65), Vector3(-0.12, 0, 0))
		_box("canvas" if i % 2 == 0 else "canvas_green", p + Vector3(-1.78 + i * 0.445, 2.4, 1.3), Vector3(0.44, 0.30, 0.08))
	_box("wood_light", p + Vector3(0, 0.73, 0.7), Vector3(3.74, 1.2, 0.67))
	_box("plank", p + Vector3(0, 1.36, 0.7), Vector3(4.0, 0.12, 0.88))
	for x in range(12):
		_box("wood", p + Vector3(-1.77 + x * 0.32, 0.74, 1.065), Vector3(0.025, 1.1, 0.04))
	for i in range(3):
		var crate = p + Vector3(-1.2 + i * 1.15, 1.46, 0.65)
		_box("wood_dark", crate, Vector3(0.91, 0.10, 0.62))
		for side in [-1.0, 1.0]:
			_box("plank", crate + Vector3(0, 0.08, side * 0.33), Vector3(0.98, 0.17, 0.07))
			_box("plank", crate + Vector3(side * 0.46, 0.08, 0), Vector3(0.06, 0.17, 0.64))
		for j in range(8):
			_stamp("sphere", ["apple", "flower_cream", "oak_light"][i], crate + Vector3(-0.31 + (j % 4) * 0.20, 0.16, -0.15 + (j / 4) * 0.27), Vector3(0.10, 0.095, 0.11))
	_barrel(p + Vector3(-1.2, 0, -0.65), 0.8)
	_box("wood", p + Vector3(0.8, 0.37, -0.65), Vector3(0.85, 0.73, 0.7))
	for y in [0.18, 0.55]:
		_box("plank", p + Vector3(0.8, y, -0.27), Vector3(0.9, 0.12, 0.07))

func _well(tile: Vector2) -> void:
	var p = _point(tile)
	_stamp("cylinder", "stone_dark", p + Vector3(0, 0.12, 0), Vector3(1.00, 0.24, 1.00))
	_stamp("cylinder", "window", p + Vector3(0, 0.44, 0), Vector3(0.69, 0.05, 0.69))
	for layer in range(3):
		for i in range(10):
			var angle = float(i) * TAU / 10 + (0.15 if layer % 2 else 0.0)
			_box("stone_light" if i % 3 == 0 else "stone", p + Vector3(cos(angle) * 0.79, 0.29 + layer * 0.27, sin(angle) * 0.79), Vector3(0.29, 0.25, 0.51), Vector3(0, -angle, 0))
	for x in [-1.04, 1.04]:
		_box("wood", p + Vector3(x, 1.38, 0), Vector3(0.16, 2.6, 0.19))
	_box("wood_light", p + Vector3(0, 1.8, 0), Vector3(2.3, 0.14, 0.14))
	_box("wood_light", p + Vector3(0, 2.5, 0), Vector3(2.5, 0.14, 0.18))
	for side in [-1.0, 1.0]:
		_box("roof", p + Vector3(0, 2.7, side * 0.58), Vector3(2.9, 0.14, 1.34), Vector3(side * 0.36, 0, 0))
	_box("roof_light", p + Vector3(0, 2.94, 0), Vector3(2.96, 0.17, 0.22))
	_box("wood_light", p + Vector3(0.10, 1.35, 0), Vector3(0.025, 0.88, 0.025))
	_stamp("cylinder", "wood_light", p + Vector3(0.10, 0.89, 0), Vector3(0.20, 0.31, 0.20))
	_box("iron", p + Vector3(1.24, 1.68, 0), Vector3(0.1, 0.41, 0.1))
	_box("wood_light", p + Vector3(1.39, 1.48, 0), Vector3(0.32, 0.10, 0.10))

func _bridge() -> void:
	# All boards have exactly the same top (0.08); navigation uses surface_height.
	for i in range(32):
		var x = 4 * TILE_SIZE - TILE_SIZE * 0.5 + 0.16 + i * 0.3375
		_box("plank" if i % 3 else "wood_light", Vector3(x, 0.025, 3 * TILE_SIZE), Vector3(0.315, 0.11, 1.23))
	for z in [3 * TILE_SIZE - 0.66, 3 * TILE_SIZE + 0.66]:
		_box("wood", Vector3(7.5 * TILE_SIZE, -0.13, z), Vector3(10.8, 0.24, 0.15))
		for x in [4.15, 5.75, 7.35, 8.95, 10.75]:
			_box("wood", Vector3(x * TILE_SIZE, 0.48, z), Vector3(0.14, 1.04, 0.14))
			_box("wood_light", Vector3(x * TILE_SIZE, 1.035, z), Vector3(0.20, 0.09, 0.20))
		_box("wood_light", Vector3(7.45 * TILE_SIZE, 0.87, z), Vector3(9.0, 0.10, 0.12))
		_box("wood", Vector3(7.45 * TILE_SIZE, 0.45, z), Vector3(9.0, 0.07, 0.07))
	# Shore boulders, reeds, lilies and reflective dashes.
	for tile in [Vector2(5.0, 0.1), Vector2(9.2, 0.4), Vector2(10.5, 1.4), Vector2(10.4, 4.8), Vector2(8.9, 6.2), Vector2(6.0, 5.8), Vector2(4.8, 4.6)]:
		var p = _point(tile)
		var shore_tile = world_to_tile(p)
		if tile_kind(shore_tile) == "grass":
			_block(shore_tile, "rock")
		_stamp("sphere", "stone", p + Vector3(0, 0.17, 0), Vector3(0.42, 0.26, 0.33), Vector3(0, _rng.randf() * TAU, 0))
		for i in range(5):
			var offset = Vector3(_rng.randf_range(-0.34, 0.34), 0, _rng.randf_range(-0.25, 0.25))
			var h = _rng.randf_range(0.4, 0.83)
			_box("reed", p + offset + Vector3(0, h * 0.5, 0), Vector3(0.03, h, 0.03), Vector3(0, 0, _rng.randf_range(-0.16, 0.16)))
			_stamp("cylinder", "reed_tip", p + offset + Vector3(0, h, 0), Vector3(0.043, 0.18, 0.043))
	for tile in [Vector2(6.2, 1.0), Vector2(7.3, 1.4), Vector2(8.6, 4.8), Vector2(7.1, 5.2)]:
		var p = _point(tile, -0.068)
		_stamp("cylinder", "lily", p, Vector3(0.26, 0.018, 0.22))
		_stamp("sphere", "flower_white", p + Vector3(0.07, 0.06, 0), Vector3(0.085, 0.07, 0.085))
	for tile in [Vector2(6.6, 0.5), Vector2(8.6, 1.7), Vector2(9.3, 2.25), Vector2(6.2, 4.4), Vector2(7.9, 5.6)]:
		_box("ripple", _point(tile, -0.060), Vector3(0.58, 0.005, 0.025))
		_box("ripple", _point(tile, -0.060) + Vector3(0.20, 0, 0.10), Vector3(0.32, 0.005, 0.016))

func _trees() -> void:
	var conifers = [
		Vector3(-10, 5.4, -10), Vector3(-8, 6.1, -11), Vector3(-4, 5.8, -11),
		Vector3(3, 5.8, -11), Vector3(5, 6.9, -10), Vector3(8, 6.2, -11),
		Vector3(11, 6.4, -8), Vector3(-11, 5.8, -7), Vector3(-10, 4.8, -3),
		Vector3(11, 5.0, -3), Vector3(-11, 5.2, 0), Vector3(-11, 4.8, 8),
		Vector3(-8, 4.6, 10), Vector3(10, 4.5, 9), Vector3(11, 4.9, 7)
	]
	for item in conifers:
		var p = _point(Vector2(item.x, item.z))
		var height: float = item.y
		_block(world_to_tile(p), "tree")
		_stamp("cylinder", "wood", p + Vector3(0, height * 0.22, 0), Vector3(0.20, height * 0.44, 0.20))
		for tier in range(3):
			var crown_y = height * (0.41 + tier * 0.20)
			var radius = height * (0.28 - tier * 0.054)
			_stamp("cone", ["pine_dark", "pine", "pine_light"][tier], p + Vector3(0, crown_y, 0), Vector3(radius, height * 0.49, radius), Vector3(0, tier * 0.55, 0))
		_roots(p)
	for item in [Vector3(3, 4.6, -7), Vector3(-10, 4.8, 5), Vector3(-5, 4.3, 8), Vector3(5, 4.7, 9), Vector3(9, 5.4, -6)]:
		_oak(Vector2(item.x, item.z), item.y)

func _roots(p: Vector3) -> void:
	for angle in [0.2, 2.3, 4.4]:
		_beam("wood", p + Vector3(0, 0.26, 0), p + Vector3(cos(angle) * 0.43, 0.04, sin(angle) * 0.43), 0.15)

func _oak(tile: Vector2, height: float) -> void:
	var p = _point(tile)
	_block(world_to_tile(p), "tree")
	_stamp("cylinder", "wood", p + Vector3(0, height * 0.30, 0), Vector3(0.24, height * 0.60, 0.24))
	_roots(p)
	for i in range(5):
		var angle = i * TAU / 5.0
		var offset = Vector3(cos(angle) * 0.98, height * 0.69 + _rng.randf_range(-0.2, 0.4), sin(angle) * 0.98)
		_beam("wood", p + Vector3(0, height * 0.35, 0), p + offset, 0.17)
		_stamp("sphere", ["oak", "oak_light", "oak_dark"][i % 3], p + offset, Vector3(1.30, 1.13, 1.20), Vector3(0, angle, 0))
	_stamp("sphere", "oak_light", p + Vector3(0, height * 0.95, 0), Vector3(1.12, 0.96, 1.07))

func _forest() -> void:
	# Dedicated Forest diorama: 25x25 (X: 13..37, Z: -12..12)
	# Harvestable interactive trees (Pine / Oak) scattered across groves and clearings
	var harvestables = [
		{"tile": Vector2i(17, 1), "type": "pine", "height": 6.2},
		{"tile": Vector2i(19, 7), "type": "oak", "height": 5.0},
		{"tile": Vector2i(21, -3), "type": "pine", "height": 5.8},
		{"tile": Vector2i(25, -2), "type": "oak", "height": 5.4},
		{"tile": Vector2i(27, 2), "type": "pine", "height": 6.5},
		{"tile": Vector2i(29, 6), "type": "oak", "height": 4.8},
		{"tile": Vector2i(32, -4), "type": "pine", "height": 6.0},
		{"tile": Vector2i(33, 4), "type": "pine", "height": 5.6},
		{"tile": Vector2i(30, -7), "type": "oak", "height": 5.2},
		{"tile": Vector2i(20, -8), "type": "pine", "height": 6.4},
		{"tile": Vector2i(23, 8), "type": "oak", "height": 4.6},
		{"tile": Vector2i(34, 0), "type": "pine", "height": 5.9},
		{"tile": Vector2i(16, 5), "type": "oak", "height": 4.7},
		{"tile": Vector2i(35, 7), "type": "oak", "height": 5.1}
	]
	for h in harvestables:
		_create_interactive_tree(h["tile"], h["type"], h["height"])

	# Forest details & lumber camp props
	_barrel(tile_to_world(Vector2i(21, 2)) + Vector3(0.3, 0, 0.3), 0.90)
	_barrel(tile_to_world(Vector2i(21, 2)) + Vector3(-0.3, 0, -0.2), 0.75)
	_lantern_post(Vector2(14.5, 4.8))
	_lantern_post(Vector2(26.5, 4.8))
	_signpost(Vector2(13.8, 2.3))

	# Woodcutter's logpile in lumber clearing
	var lp = tile_to_world(Vector2i(22, 1))
	for i in range(7):
		_stamp("cylinder", "wood", lp + Vector3(0, 0.22 + (i / 3) * 0.30, -0.4 + (i % 3) * 0.36), Vector3(0.18, 1.2, 0.18), Vector3(0, 0, PI * 0.5))

	# Forest mossy boulders
	for boulder in [Vector2i(15, -9), Vector2i(28, -9), Vector2i(35, -9), Vector2i(15, 9), Vector2i(32, 9)]:
		var p = _point(Vector2(boulder))
		_block(boulder, "rock")
		_stamp("sphere", "stone_dark", p + Vector3(0, 0.37, 0), Vector3(0.70, 0.55, 0.60), Vector3(0.1, 0.45, 0.1))
		_stamp("sphere", "stone", p + Vector3(0.32, 0.43, 0.08), Vector3(0.38, 0.38, 0.39))
		_stamp("sphere", "oak_dark", p + Vector3(-0.14, 0.80, 0), Vector3(0.39, 0.08, 0.33))

	# Forest flower patches
	for flower_tile in [Vector2(19.2, -4.5), Vector2(24.5, -5.2), Vector2(31.0, 1.5), Vector2(28.5, 8.2)]:
		_flower_patch(flower_tile)

func _create_interactive_tree(tile: Vector2i, type: String, height: float) -> void:
	_block(tile, "tree")
	var root_node = Node3D.new()
	root_node.name = "Tree_%d_%d" % [tile.x, tile.y]
	root_node.position = tile_to_world(tile)
	add_child(root_node)

	var canopy = Node3D.new()
	canopy.name = "Canopy"
	root_node.add_child(canopy)

	var stump = Node3D.new()
	stump.name = "Stump"
	root_node.add_child(stump)

	# Build tree visual nodes
	var trunk_mesh = MeshInstance3D.new()
	var cyl = CylinderMesh.new()
	cyl.top_radius = 0.20 if type == "pine" else 0.24
	cyl.bottom_radius = 0.23 if type == "pine" else 0.28
	cyl.height = height * 0.44
	cyl.radial_segments = 8
	trunk_mesh.mesh = cyl
	trunk_mesh.material_override = _materials["wood"]
	trunk_mesh.position = Vector3(0, height * 0.22, 0)
	canopy.add_child(trunk_mesh)

	if type == "pine":
		for tier in range(3):
			var cone_node = MeshInstance3D.new()
			var cone_mesh = CylinderMesh.new()
			cone_mesh.top_radius = 0.0
			var rad = height * (0.28 - tier * 0.054)
			cone_mesh.bottom_radius = rad
			cone_mesh.height = height * 0.49
			cone_mesh.radial_segments = 7
			cone_node.mesh = cone_mesh
			cone_node.material_override = _materials[["pine_dark", "pine", "pine_light"][tier]]
			cone_node.position = Vector3(0, height * (0.41 + tier * 0.20) + height * 0.245, 0)
			cone_node.rotation.y = tier * 0.55
			canopy.add_child(cone_node)
	else:
		# Oak canopy spheres
		for i in range(5):
			var angle = i * TAU / 5.0
			var sph_node = MeshInstance3D.new()
			var sph = SphereMesh.new()
			sph.radius = 1.0
			sph.height = 2.0
			sph.radial_segments = 8
			sph.rings = 4
			sph_node.mesh = sph
			sph_node.scale = Vector3(1.30, 1.13, 1.20)
			sph_node.material_override = _materials[["oak", "oak_light", "oak_dark"][i % 3]]
			sph_node.position = Vector3(cos(angle) * 0.98, height * 0.69, sin(angle) * 0.98)
			canopy.add_child(sph_node)
		var top_sph = MeshInstance3D.new()
		var top_mesh = SphereMesh.new()
		top_mesh.radius = 1.0
		top_mesh.height = 2.0
		top_mesh.radial_segments = 8
		top_mesh.rings = 4
		top_sph.mesh = top_mesh
		top_sph.scale = Vector3(1.12, 0.96, 1.07)
		top_sph.material_override = _materials["oak_light"]
		top_sph.position = Vector3(0, height * 0.95, 0)
		canopy.add_child(top_sph)

	# Stump visual (remains visible when felled)
	var stump_mesh = MeshInstance3D.new()
	var stump_cyl = CylinderMesh.new()
	stump_cyl.top_radius = 0.22
	stump_cyl.bottom_radius = 0.26
	stump_cyl.height = 0.32
	stump_cyl.radial_segments = 8
	stump_mesh.mesh = stump_cyl
	stump_mesh.material_override = _materials["wood"]
	stump_mesh.position = Vector3(0, 0.16, 0)
	stump.add_child(stump_mesh)
	stump.visible = false

	trees[tile] = {
		"tile": tile,
		"type": type,
		"height": height,
		"is_stump": false,
		"respawn_timer": 0.0,
		"node": root_node,
		"canopy": canopy,
		"stump": stump
	}

func chop_tree(tile: Vector2i) -> bool:
	if not trees.has(tile):
		return false
	var tree_data = trees[tile]
	if tree_data["is_stump"]:
		return false
	tree_data["is_stump"] = true
	tree_data["canopy"].visible = false
	tree_data["stump"].visible = true
	tree_data["respawn_timer"] = 25.0
	_unblock(tile, "grass")
	tree_state_changed.emit(tile, true)
	return true

func respawn_tree(tile: Vector2i) -> void:
	if not trees.has(tile):
		return
	var tree_data = trees[tile]
	if not tree_data["is_stump"]:
		return
	tree_data["is_stump"] = false
	tree_data["canopy"].visible = true
	tree_data["stump"].visible = false
	tree_data["respawn_timer"] = 0.0
	_block(tile, "tree")
	tree_state_changed.emit(tile, false)

func is_tree_at(tile: Vector2i) -> bool:
	return trees.has(tile) and not trees[tile]["is_stump"]

func get_tree_data(tile: Vector2i) -> Dictionary:
	return trees.get(tile, {})

func _process(delta: float) -> void:
	for tile in trees:
		var tree_data = trees[tile]
		if tree_data["is_stump"]:
			tree_data["respawn_timer"] -= delta
			if tree_data["respawn_timer"] <= 0.0:
				respawn_tree(tile)

func _fences() -> void:
	# North and South outer boundary rails along Willowmere + Forest
	for i in range(-12, 38):
		# Keep gates at Willowmere south/north and Forest north/south
		if (i >= -1 and i <= 1) or (i >= 24 and i <= 26):
			continue
		_fence_tile(Vector2i(i, 12), false)
		_fence_tile(Vector2i(i, -12), false)

	# Western outer boundary rail
	for z in range(-12, 13):
		if z != 3 and z != 4:
			_fence_tile(Vector2i(-12, z), true)

	# Eastern outer boundary rail (far edge of Forest)
	for z in range(-12, 13):
		if z != 3 and z != 4:
			_fence_tile(Vector2i(37, z), true)

	# Internal border fence between Willowmere and Forest (X = 12)
	# Gates at Z = 3 and 4 leave the road wide open between regions
	for z in range(-12, 13):
		if z != 3 and z != 4:
			_fence_tile(Vector2i(12, z), true)

func _fence_tile(tile: Vector2i, vertical: bool) -> void:
	_block(tile, "building")
	var p = tile_to_world(tile)
	_box("wood_light", p + Vector3(0, 0.46, 0), Vector3(0.13, 0.92, 0.13))
	for y in [0.33, 0.72]:
		_box("wood_light", p + Vector3(0, y, 0), Vector3(0.075 if vertical else TILE_SIZE, 0.095, TILE_SIZE if vertical else 0.075))

func _details() -> void:
	# Mossy boulders and herb patches leave the central village streets generous.
	for tile in [Vector2(-8, -1), Vector2(4, -9), Vector2(8, -8), Vector2(-8, 7), Vector2(8, 9)]:
		var p = _point(tile)
		_block(world_to_tile(p), "rock")
		_stamp("sphere", "stone_dark", p + Vector3(0, 0.37, 0), Vector3(0.70, 0.55, 0.60), Vector3(0.1, 0.45, 0.1))
		_stamp("sphere", "stone", p + Vector3(0.32, 0.43, 0.08), Vector3(0.38, 0.38, 0.39))
		_stamp("sphere", "oak_dark", p + Vector3(-0.14, 0.80, 0), Vector3(0.39, 0.08, 0.33))
	for tile in [Vector2(-8.8, -3.4), Vector2(-3.2, -8.9), Vector2(2.7, -4.6), Vector2(3.2, -1.0), Vector2(-3.8, 5.8), Vector2(-7.0, 6.2), Vector2(3.2, 7.8), Vector2(-2.5, 10.5), Vector2(8.0, 7.6), Vector2(10.8, -0.8)]:
		_flower_patch(tile)
	# Small grass blades, grouped into tuft clusters and restricted to open grass.
	for i in range(160):
		var tile = Vector2i(_rng.randi_range(-11, 11), _rng.randi_range(-11, 11))
		if tile_kind(tile) != "grass":
			continue
		var p = tile_to_world(tile) + Vector3(_rng.randf_range(-0.43, 0.43), 0, _rng.randf_range(-0.43, 0.43))
		for j in range(3):
			_stamp("cone", "oak_dark" if i % 2 else "oak_light", p + Vector3((j - 1) * 0.085, 0.13, 0), Vector3(0.055, 0.26 + j * 0.04, 0.04), Vector3(0, i, (j - 1) * -0.18))
	# Path grit catches the light without obscuring the route/grid.
	for i in range(95):
		var tile = Vector2i(_rng.randi_range(-11, 11), _rng.randi_range(-10, 10))
		if tile_kind(tile) != "path":
			continue
		_stamp("sphere", "stone_light", tile_to_world(tile) + Vector3(_rng.randf_range(-0.6, 0.6), 0.027, _rng.randf_range(-0.6, 0.6)), Vector3(0.065, 0.026, 0.045))
	_lantern_post(Vector2(2.5, 4.9))
	_lantern_post(Vector2(-3.6, -3.0))
	_signpost(Vector2(-2.8, 4.9))
	# Garden crates beside the cottage stay entirely in its blocked footprint.
	_barrel(_point(Vector2(-3.7, -4.6)), 0.95)
	_barrel(_point(Vector2(-3.7, -5.5)), 0.75)

func _flower_patch(tile: Vector2) -> void:
	var origin = _point(tile)
	for i in range(11):
		var p = origin + Vector3(_rng.randf_range(-0.62, 0.62), 0, _rng.randf_range(-0.56, 0.56))
		var h = _rng.randf_range(0.19, 0.40)
		_box("oak_dark", p + Vector3(0, h * 0.5, 0), Vector3(0.022, h, 0.022))
		_stamp("sphere", ["flower_pink", "flower_cream", "flower_white"][i % 3], p + Vector3(0, h, 0), Vector3(0.076, 0.047, 0.076))
		_stamp("sphere", "oak", p + Vector3(0.06, h * 0.42, 0), Vector3(0.08, 0.027, 0.04))

func _barrel(p: Vector3, size: float) -> void:
	_stamp("cylinder", "wood_light", p + Vector3(0, size * 0.5, 0), Vector3(size * 0.36, size, size * 0.36))
	_stamp("cylinder", "plank", p + Vector3(0, size + 0.01, 0), Vector3(size * 0.33, 0.025, size * 0.33))
	for y in [0.18, 0.78]:
		_stamp("cylinder", "iron", p + Vector3(0, size * y, 0), Vector3(size * 0.375, size * 0.065, size * 0.375))

func _lantern_post(tile: Vector2) -> void:
	var p = _point(tile)
	_block(world_to_tile(p), "building")
	_stamp("cylinder", "stone", p + Vector3(0, 0.13, 0), Vector3(0.27, 0.26, 0.27))
	_box("wood", p + Vector3(0, 1.55, 0), Vector3(0.16, 3.1, 0.16))
	_box("wood", p + Vector3(-0.32, 2.92, 0), Vector3(0.8, 0.14, 0.14))
	_beam("wood_light", p + Vector3(0, 2.44, 0), p + Vector3(-0.5, 2.91, 0), 0.085)
	_box("iron", p + Vector3(-0.59, 2.75, 0), Vector3(0.035, 0.30, 0.035))
	_lantern(p + Vector3(-0.59, 2.34, 0), 1.0)

func _lantern(p: Vector3, size: float) -> void:
	_box("glow", p, Vector3(0.25, 0.38, 0.25) * size)
	for x in [-0.15, 0.15]:
		for z in [-0.15, 0.15]:
			_box("iron", p + Vector3(x, 0, z) * size, Vector3(0.035, 0.46, 0.035) * size)
	for y in [-0.23, 0.23]:
		_box("iron", p + Vector3(0, y, 0) * size, Vector3(0.36, 0.07, 0.36) * size)
	_stamp("cone", "iron", p + Vector3(0, 0.34, 0) * size, Vector3(0.27, 0.20, 0.27) * size, Vector3(0, PI / 4, 0))

func _signpost(tile: Vector2) -> void:
	var p = _point(tile)
	_block(world_to_tile(p), "building")
	_box("wood", p + Vector3(0, 0.9, 0), Vector3(0.13, 1.8, 0.13))
	_box("plank", p + Vector3(0.12, 1.61, 0), Vector3(1.02, 0.32, 0.10), Vector3(0, 0, -0.04))
	_box("wood_light", p + Vector3(-0.13, 1.16, 0), Vector3(1.12, 0.27, 0.1), Vector3(0, 0, 0.04))
	for x in [-0.24, -0.09, 0.06, 0.21, 0.36]:
		_box("wood", p + Vector3(x, 1.61, 0.061), Vector3(0.03, 0.13, 0.02))

func _flush_batches() -> void:
	for key in _batches:
		var parts: PackedStringArray = key.split(":")
		var instances: Array = _batches[key]
		var multimesh = MultiMesh.new()
		multimesh.transform_format = MultiMesh.TRANSFORM_3D
		multimesh.mesh = _meshes[parts[0]]
		multimesh.instance_count = instances.size()
		for i in range(instances.size()):
			multimesh.set_instance_transform(i, instances[i])
		var node = MultiMeshInstance3D.new()
		node.name = key.replace(":", "_")
		node.multimesh = multimesh
		node.material_override = _materials[parts[1]]
		add_child(node)
	_batches.clear()

func _make_grid() -> void:
	grid_overlay = Node3D.new()
	grid_overlay.name = "TileGrid"
	grid_overlay.visible = false
	add_child(grid_overlay)
	var immediate = ImmediateMesh.new()
	immediate.surface_begin(Mesh.PRIMITIVE_LINES)
	for z in range(-12, 13):
		for x in range(-12, 38):
			var tile = Vector2i(x, z)
			if blocked.has(tile):
				continue
			var p = tile_to_world(tile) + Vector3(0, surface_height(tile) + 0.018, 0)
			var half = TILE_SIZE * 0.5
			var corners = [p + Vector3(-half, 0, -half), p + Vector3(half, 0, -half), p + Vector3(half, 0, half), p + Vector3(-half, 0, half)]
			for i in range(4):
				immediate.surface_add_vertex(corners[i])
				immediate.surface_add_vertex(corners[(i + 1) % 4])
	immediate.surface_end()
	var grid_mesh = MeshInstance3D.new()
	grid_mesh.mesh = immediate
	var mat = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.84, 0.87, 0.64, 0.24)
	grid_mesh.material_override = mat
	grid_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	grid_overlay.add_child(grid_mesh)
