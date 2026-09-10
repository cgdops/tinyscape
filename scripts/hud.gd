extends CanvasLayer

signal grid_toggled
signal recenter_requested
signal inspect_requested
signal pause_changed(paused: bool)
signal destination_requested(tile: Vector2i)

const Minimap = preload("res://scripts/minimap.gd")
const WoodcuttingData = preload("res://scripts/woodcutting_data.gd")
const INK := Color("25382f")
const GOLD := Color("dbc28b")
const TEXT := Color("eee8d9")
const MUTED := Color("b2beb0")

var status_label: Label
var tile_label: Label
var travel_label: Label
var woodcut_label: Label
var hint_label: Label
var grid_button: Button
var minimap: Control
var context_menu: PanelContainer
var _context_vbox: VBoxContainer
var pause_screen: Control
var pause_title: Label
var help_text: Label
var resume_button: Button
var _title_font: Font
var _body_font: Font
var _message_time := 0.0
var _root: Control

func initialize(world: Node3D, player: Node3D, camera: Camera3D) -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_title_font = load("res://assets/fonts/Alegreya.ttf")
	_body_font = load("res://assets/fonts/Lato-Regular.ttf")
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	var theme := Theme.new()
	theme.default_font = _body_font
	theme.default_font_size = 17
	_root.theme = theme
	_build_identity()
	_build_map(world, player, camera)
	_build_player_panel()
	_build_actions()
	_build_context_menu()
	_build_pause()

	if player.has_signal("woodcut_progress"):
		player.woodcut_progress.connect(func(_logs: int, _xp: int, _lvl: int, msg: String): show_message(msg, 3.5))

func _style(background := INK, border := Color("687259"), radius := 5) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(radius)
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 14
	style.content_margin_bottom = 14
	return style

func _label(text: String, size := 17, color := TEXT, display := false) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	if display:
		label.add_theme_font_override("font", _title_font)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

func _button(text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.y = 44
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_color_override("font_color", TEXT)
	button.add_theme_color_override("font_hover_color", Color("fff3cb"))
	button.add_theme_stylebox_override("normal", _style(Color("304538")))
	button.add_theme_stylebox_override("hover", _style(Color("455b44"), GOLD))
	button.add_theme_stylebox_override("pressed", _style(Color("23382c"), GOLD))
	button.add_theme_stylebox_override("focus", _style(Color(0, 0, 0, 0), GOLD))
	button.pressed.connect(callback)
	return button

func _build_identity() -> void:
	var panel := HBoxContainer.new()
	panel.position = Vector2(34, 26)
	panel.add_theme_constant_override("separation", 14)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(panel)
	var icon := TextureRect.new()
	icon.texture = load("res://assets/icon.svg")
	icon.custom_minimum_size = Vector2(58, 58)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(icon)
	var titles := VBoxContainer.new()
	titles.add_theme_constant_override("separation", -5)
	titles.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(titles)
	var title := _label("tinyscape", 48, Color("fff1cb"), true)
	title.add_theme_color_override("font_shadow_color", Color(0.1, 0.18, 0.13, 0.7))
	title.add_theme_constant_override("shadow_offset_y", 2)
	titles.add_child(title)
	titles.add_child(_label("A small world. A first adventure.", 16, Color("ebefdc")))

func _build_map(world: Node3D, player: Node3D, camera: Camera3D) -> void:
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	panel.offset_left = -262
	panel.offset_right = -30
	panel.offset_top = 30
	panel.add_theme_stylebox_override("panel", _style(Color("283d32"), Color("8a8865")))
	_root.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 0)
	panel.add_child(column)
	column.add_child(_label("Willowmere", 29, GOLD, true))
	column.add_child(_label("Starter village", 14, MUTED))
	minimap = Minimap.new()
	column.add_child(minimap)
	minimap.initialize(world, player, camera)
	minimap.tile_selected.connect(func(tile: Vector2i): destination_requested.emit(tile))
	var caption := _label("Click the map to travel", 13, MUTED)
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(caption)

func _build_player_panel() -> void:
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	panel.offset_left = 30
	panel.offset_right = 350
	panel.offset_top = -155
	panel.offset_bottom = -30
	panel.add_theme_stylebox_override("panel", _style(Color("263b30")))
	_root.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 5)
	panel.add_child(column)
	var row := HBoxContainer.new()
	column.add_child(row)
	var name_label := _label("Wanderer", 27, TEXT, true)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_label)
	status_label = _label("Idle", 15, GOLD)
	row.add_child(status_label)
	var line := HSeparator.new()
	line.modulate = Color("7c8969")
	column.add_child(line)
	tile_label = _label("Tile  -1, 4", 15, MUTED)
	column.add_child(tile_label)
	woodcut_label = _label("Woodcutting: Lv 1 (0 XP) | Logs: 0", 14, Color("d5e4d1"))
	column.add_child(woodcut_label)
	travel_label = _label("Your journey starts here", 14, MUTED)
	column.add_child(travel_label)

func _build_actions() -> void:
	var column := VBoxContainer.new()
	column.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	column.offset_left = -310
	column.offset_right = 310
	column.offset_top = -110
	column.offset_bottom = -30
	column.add_theme_constant_override("separation", 12)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(column)
	hint_label = _label("Click a tile to begin your adventure", 18, Color("f7edcd"))
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_label.add_theme_color_override("font_shadow_color", Color("273c2f"))
	hint_label.add_theme_constant_override("shadow_offset_y", 2)
	column.add_child(hint_label)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(row)
	grid_button = _button("G   Tile grid", func(): grid_toggled.emit())
	grid_button.tooltip_text = "Show or hide the tile grid (G)"
	row.add_child(grid_button)
	row.add_child(_button("V   Character", func(): inspect_requested.emit()))
	row.add_child(_button("Home   Recenter", func(): recenter_requested.emit()))
	row.add_child(_button("?   Controls", func(): show_pause(true)))
	var footer := VBoxContainer.new()
	footer.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	footer.offset_left = -250
	footer.offset_right = -32
	footer.offset_top = -84
	footer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(footer)
	for text in ["Scroll to zoom   /   Right drag to orbit", "Single-player prototype   v0.1"]:
		var label := _label(text, 13, Color("e4e8d8"))
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		label.add_theme_color_override("font_shadow_color", Color("283e34"))
		label.add_theme_constant_override("shadow_offset_y", 1)
		footer.add_child(label)

func _build_pause() -> void:
	pause_screen = Control.new()
	pause_screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pause_screen.visible = false
	_root.add_child(pause_screen)
	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.07, 0.14, 0.10, 0.72)
	pause_screen.add_child(shade)
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.offset_left = -255
	panel.offset_right = 255
	panel.offset_top = -250
	panel.offset_bottom = 250
	panel.add_theme_stylebox_override("panel", _style(INK, GOLD, 8))
	pause_screen.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 17)
	panel.add_child(column)
	pause_title = _label("A moment of rest", 40, GOLD, true)
	pause_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(pause_title)
	help_text = _label("Left click   Walk to a tile\nMinimap   Click to travel further\nRight drag or Q / E   Orbit camera\nScroll   Zoom in or out\nV   Inspect character\nG   Show the tile grid\nHome   Reset camera\nEsc   Pause or resume", 19, TEXT)
	help_text.add_theme_constant_override("line_spacing", 13)
	column.add_child(help_text)
	column.add_child(_label("Routes avoid trees, buildings and water.\nClick again while walking to change your destination.", 15, MUTED))
	resume_button = _button("Return to Willowmere", hide_pause)
	column.add_child(resume_button)
	column.add_child(_button("Quit game", func(): get_tree().quit()))

func show_pause(controls := false) -> void:
	pause_title.text = "Find your feet" if controls else "A moment of rest"
	pause_screen.show()
	pause_changed.emit(true)
	get_tree().paused = true
	resume_button.grab_focus()

func hide_pause() -> void:
	pause_screen.hide()
	get_tree().paused = false
	pause_changed.emit(false)
	resume_button.release_focus()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_ESCAPE:
				if pause_screen.visible:
					hide_pause()
				else:
					show_pause()
				get_viewport().set_input_as_handled()
			KEY_G:
				if not get_tree().paused:
					grid_toggled.emit()
			KEY_H, KEY_F1:
				show_pause(true)

func _build_context_menu() -> void:
	context_menu = PanelContainer.new()
	context_menu.name = "ContextMenu"
	context_menu.visible = false
	context_menu.mouse_filter = Control.MOUSE_FILTER_STOP
	context_menu.add_theme_stylebox_override("panel", _style(Color("1e2f24"), GOLD, 6))
	_root.add_child(context_menu)
	_context_vbox = VBoxContainer.new()
	_context_vbox.add_theme_constant_override("separation", 4)
	context_menu.add_child(_context_vbox)

func show_context_menu(screen_pos: Vector2, options: Array[Dictionary]) -> void:
	# Clear previous items
	for child in _context_vbox.get_children():
		child.queue_free()

	for opt in options:
		var text: String = opt.get("text", "Option")
		var callback: Callable = opt.get("callback", Callable())
		var btn := Button.new()
		btn.text = text
		btn.custom_minimum_size = Vector2(160, 32)
		btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		btn.add_theme_color_override("font_color", TEXT)
		btn.add_theme_color_override("font_hover_color", GOLD)
		btn.add_theme_stylebox_override("normal", _style(Color("263a2c"), Color("455b44"), 4))
		btn.add_theme_stylebox_override("hover", _style(Color("36503e"), GOLD, 4))
		btn.pressed.connect(func():
			hide_context_menu()
			if callback.is_valid():
				callback.call()
		)
		_context_vbox.add_child(btn)

	context_menu.position = screen_pos
	context_menu.show()

func hide_context_menu() -> void:
	if is_instance_valid(context_menu):
		context_menu.hide()

func update_state(player: Node3D) -> void:
	var state_text = "Idle"
	if player.motion.moving:
		state_text = "Walking"
	elif player.get("chopping"):
		state_text = "Chopping"
	status_label.text = state_text

	tile_label.text = "Tile  %d, %d" % [player.motion.current_tile.x, player.motion.current_tile.y]
	if "woodcut_level" in player:
		var next_xp: int = WoodcuttingData.get_next_level_xp(player.woodcut_level)
		var max_slots: int = WoodcuttingData.MAX_INVENTORY_SLOTS
		var coins_count: int = player.get("coins") if "coins" in player else 0
		woodcut_label.text = "Woodcutting: Lv %d (%d/%d XP) | Logs %d/%d | %dc" % [
			player.woodcut_level,
			player.woodcut_xp,
			next_xp,
			player.logs,
			max_slots,
			coins_count
		]
	travel_label.text = "%d tiles explored" % player.steps if player.steps else "Your journey starts here"
	if _message_time <= 0.0:
		if player.get("chopping"):
			hint_label.text = "Chopping tree at tile %d, %d..." % [player.target_tree_tile.x, player.target_tree_tile.y]
		elif player.motion.moving:
			hint_label.text = "Walking to tile %d, %d" % [player.motion.destination.x, player.motion.destination.y]
		else:
			hint_label.text = "Click a tile to walk, or right-click a tree to Chop"

func show_message(text: String, seconds := 3.0) -> void:
	hint_label.text = text
	_message_time = seconds

func _process(delta: float) -> void:
	_message_time = maxf(0, _message_time - delta)
