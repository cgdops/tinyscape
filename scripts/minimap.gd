extends Control

signal tile_selected(tile: Vector2i)

var world: Node3D
var player: Node3D
var camera: Camera3D
var _map_image: ImageTexture
const MAP_RECT := Rect2(14, 30, 176, 176)

var active_region: Rect2i = Rect2i(-12, -12, 25, 25)

func initialize(level: Node3D, hero: Node3D, view: Camera3D) -> void:
	world = level
	player = hero
	camera = view
	custom_minimum_size = Vector2(204, 216)
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_refresh_map_texture()

func _refresh_map_texture() -> void:
	var img := Image.create(25, 25, false, Image.FORMAT_RGB8)
	for y in 25:
		for x in 25:
			var tile := Vector2i(active_region.position.x + x, active_region.position.y + y)
			var color := Color("697e4d")
			match world.tile_kind(tile):
				"water": color = Color("579b9f")
				"path", "bridge": color = Color("bfa97d")
				"building": color = Color("815944")
				"tree": color = Color("344f3e")
				"rock": color = Color("909083")
			img.set_pixel(x, y, color)
	_map_image = ImageTexture.create_from_image(img)
	queue_redraw()

func _process(_delta: float) -> void:
	if player and player.motion:
		var hero_x = player.motion.current_tile.x
		var target_reg = Rect2i(13, -12, 25, 25) if hero_x >= 13 else Rect2i(-12, -12, 25, 25)
		if target_reg != active_region:
			active_region = target_reg
			_refresh_map_texture()
	queue_redraw()

func _point(tile: Vector2) -> Vector2:
	var rel_x = (tile.x - active_region.position.x + 0.5) / 25.0
	var rel_y = (tile.y - active_region.position.y + 0.5) / 25.0
	return MAP_RECT.position + Vector2(rel_x, rel_y) * MAP_RECT.size

func _draw() -> void:
	if _map_image == null:
		return
	draw_rect(Rect2(10, 26, 184, 184), Color("9b875e"), false, 1.0)
	draw_texture_rect(_map_image, MAP_RECT, false)
	var font := ThemeDB.fallback_font
	draw_string(font, Vector2(90, 20), "N", HORIZONTAL_ALIGNMENT_CENTER, 24, 13, Color("ead6a8"))
	if player.motion:
		var route: Array[Vector2i] = player.motion.remaining_path()
		var previous := _point(player.motion.position)
		for tile in route:
			var point := _point(Vector2(tile))
			draw_line(previous, point, Color("ebd59e"), 2.0, true)
			previous = point
		var dot := _point(player.motion.position)
		draw_circle(dot, 5.5, Color("263a30"))
		draw_circle(dot, 3.5, Color("ffedb7"))

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if MAP_RECT.has_point(event.position):
			var tile := Vector2i(((event.position - MAP_RECT.position) / MAP_RECT.size * 25.0).floor()) + active_region.position
			tile_selected.emit(tile)
		accept_event()
