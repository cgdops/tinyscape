extends CanvasLayer

signal grid_toggled
signal recenter_requested
signal inspect_requested
signal pause_changed(paused: bool)
signal destination_requested(tile: Vector2i)

const Minimap = preload("res://scripts/minimap.gd")
const WoodcuttingData = preload("res://scripts/woodcutting_data.gd")
const DialogueBox = preload("res://scripts/dialogue_box.gd")
const QuestJournal = preload("res://scripts/quest_journal.gd")
const MessageLog = preload("res://scripts/message_log.gd")
const BagWindow = preload("res://scripts/bag_window.gd")

const INK := Color("25382f")
const GOLD := Color("dbc28b")
const TEXT := Color("eee8d9")
const MUTED := Color("b2beb0")
const HIGHLIGHT := Color("fff6e4")

var status_label: Label
var tile_label: Label
var travel_label: Label
var woodcut_label: Label
var minimap: Control
var context_menu: PanelContainer
var _context_vbox: VBoxContainer
var pause_screen: Control
var pause_title: Label
var help_text: Label
var resume_button: Button
var dialogue_box: PanelContainer
var quest_journal: PanelContainer

# UI Shell components
var message_log: PanelContainer
var bag_window: PanelContainer
var menu_bar: HBoxContainer
var bag_button: Button
var journal_button: Button
var character_button: Button
var settings_button: Button
var grid_button: Button
var recenter_button: Button

var _title_font: Font
var _body_font: Font
var _root: Control
var _player: Node3D

func initialize(world: Node3D, player: Node3D, camera: Camera3D, game_state: RefCounted = null, dialogue_runner: RefCounted = null) -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_player = player
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

	# R1: _build_identity() deleted. Top-left is clear.
	_build_map(world, player, camera)
	_build_player_panel()
	_build_message_log()
	_build_menu_bar()
	_build_bag_window(player)
	_build_context_menu()
	_build_dialogue_ui(dialogue_runner)
	_build_journal_ui(game_state, player)
	_build_pause()

	if player.has_signal("woodcut_progress"):
		player.woodcut_progress.connect(func(_logs: int, _xp: int, _lvl: int, msg: String): show_message(msg))

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
	panel.offset_top = -295
	panel.offset_bottom = -170
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

func _build_message_log() -> void:
	message_log = MessageLog.new()
	message_log.initialize(_title_font, _body_font)
	message_log.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	message_log.offset_left = 30
	message_log.offset_right = 490
	message_log.offset_top = -160
	message_log.offset_bottom = -30
	_root.add_child(message_log)

func _build_menu_bar() -> void:
	# Menu bar: bottom-right above footer text
	var bar_container = PanelContainer.new()
	bar_container.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	bar_container.offset_left = -330
	bar_container.offset_right = -30
	bar_container.offset_top = -80
	bar_container.offset_bottom = -30

	var bar_style = StyleBoxFlat.new()
	bar_style.bg_color = Color("1e2f24")
	bar_style.border_color = GOLD
	bar_style.set_border_width_all(1)
	bar_style.set_corner_radius_all(6)
	bar_style.content_margin_left = 8
	bar_style.content_margin_right = 8
	bar_style.content_margin_top = 4
	bar_style.content_margin_bottom = 4
	bar_container.add_theme_stylebox_override("panel", bar_style)
	_root.add_child(bar_container)

	menu_bar = HBoxContainer.new()
	menu_bar.add_theme_constant_override("separation", 6)
	bar_container.add_child(menu_bar)

	bag_button = _menu_bar_button("Bag (B)", func(): toggle_bag())
	bag_button.tooltip_text = "Open or close your rucksack (B)"
	menu_bar.add_child(bag_button)

	journal_button = _menu_bar_button("Journal (J)", func(): toggle_journal())
	journal_button.tooltip_text = "Open or close the quest journal (J)"
	menu_bar.add_child(journal_button)

	character_button = _menu_bar_button("Character (V)", func(): inspect_requested.emit())
	character_button.tooltip_text = "Toggle character close-up inspect view (V)"
	menu_bar.add_child(character_button)

	settings_button = _menu_bar_button("Settings (Esc)", func(): show_pause(true))
	settings_button.tooltip_text = "Open pause & game controls (Esc)"
	menu_bar.add_child(settings_button)

	# Footer secondary controls (G / Home)
	var footer_row = HBoxContainer.new()
	footer_row.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	footer_row.offset_left = -330
	footer_row.offset_right = -30
	footer_row.offset_top = -26
	footer_row.offset_bottom = -6
	footer_row.add_theme_constant_override("separation", 12)
	_root.add_child(footer_row)

	grid_button = Button.new()
	grid_button.text = "G  Grid"
	grid_button.flat = true
	grid_button.add_theme_font_size_override("font_size", 12)
	grid_button.add_theme_color_override("font_color", MUTED)
	grid_button.pressed.connect(func(): grid_toggled.emit())
	footer_row.add_child(grid_button)

	recenter_button = Button.new()
	recenter_button.text = "Home  Recenter"
	recenter_button.flat = true
	recenter_button.add_theme_font_size_override("font_size", 12)
	recenter_button.add_theme_color_override("font_color", MUTED)
	recenter_button.pressed.connect(func(): recenter_requested.emit())
	footer_row.add_child(recenter_button)

func _menu_bar_button(text: String, callback: Callable) -> Button:
	var btn = Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(65, 36)
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn.add_theme_font_size_override("font_size", 13)
	btn.add_theme_color_override("font_color", TEXT)
	btn.add_theme_color_override("font_hover_color", GOLD)

	var norm_style = _style(Color("263a2c"), Color("455b44"), 4)
	norm_style.content_margin_left = 6
	norm_style.content_margin_right = 6
	norm_style.content_margin_top = 4
	norm_style.content_margin_bottom = 4
	btn.add_theme_stylebox_override("normal", norm_style)

	var hover_style = _style(Color("36503e"), GOLD, 4)
	hover_style.content_margin_left = 6
	hover_style.content_margin_right = 6
	hover_style.content_margin_top = 4
	hover_style.content_margin_bottom = 4
	btn.add_theme_stylebox_override("hover", hover_style)

	var pressed_style = _style(Color("1b2a20"), GOLD, 4)
	pressed_style.content_margin_left = 6
	pressed_style.content_margin_right = 6
	pressed_style.content_margin_top = 4
	pressed_style.content_margin_bottom = 4
	btn.add_theme_stylebox_override("pressed", pressed_style)

	btn.pressed.connect(callback)
	return btn

func _build_bag_window(player: Node3D) -> void:
	bag_window = BagWindow.new()
	bag_window.initialize(player, _title_font, _body_font, func(pos, opts): show_context_menu(pos, opts))
	bag_window.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	bag_window.offset_left = -270
	bag_window.offset_right = -30
	bag_window.offset_top = -455
	bag_window.offset_bottom = -95

	bag_window.item_examined.connect(func(item: Dictionary):
		show_message("%s: A freshly cut log from the woods. Worth %dc." % [item.get("name", "Log"), item.get("value", 4)])
	)
	bag_window.item_dropped.connect(func(index: int, item: Dictionary):
		if is_instance_valid(_player) and index < _player.inventory.size():
			_player.inventory.remove_at(index)
			bag_window.refresh()
			show_message("You drop the %s." % item.get("name", "item"))
	)

	_root.add_child(bag_window)

func toggle_bag() -> void:
	if not is_instance_valid(bag_window):
		return
	var will_open = not bag_window.visible
	if will_open:
		# Mutually exclusive: close journal
		if is_instance_valid(quest_journal):
			quest_journal.hide()
		bag_window.refresh()
		bag_window.show()
	else:
		bag_window.hide()
	_update_menu_bar_states()

func toggle_journal() -> void:
	if not is_instance_valid(quest_journal):
		return
	var will_open = not quest_journal.visible
	if will_open:
		# Mutually exclusive: close bag
		if is_instance_valid(bag_window):
			bag_window.hide()
		quest_journal.toggle_journal()
	else:
		quest_journal.hide()
	_update_menu_bar_states()

func _update_menu_bar_states() -> void:
	if is_instance_valid(bag_button):
		var is_open = is_instance_valid(bag_window) and bag_window.visible
		bag_button.button_pressed = is_open
		# Warm outline indicator if bag full
		if is_instance_valid(_player) and _player.inventory.size() >= WoodcuttingData.MAX_INVENTORY_SLOTS and not is_open:
			var alert_style = bag_button.get_theme_stylebox("normal").duplicate() as StyleBoxFlat
			alert_style.border_color = Color("e6b85b")
			alert_style.set_border_width_all(2)
			bag_button.add_theme_stylebox_override("normal", alert_style)
		else:
			var norm = _style(Color("263a2c"), Color("455b44"), 4)
			norm.content_margin_left = 6
			norm.content_margin_right = 6
			norm.content_margin_top = 4
			norm.content_margin_bottom = 4
			bag_button.add_theme_stylebox_override("normal", norm)

	if is_instance_valid(journal_button):
		journal_button.button_pressed = is_instance_valid(quest_journal) and quest_journal.visible

func _build_dialogue_ui(runner: RefCounted) -> void:
	if runner == null:
		return
	dialogue_box = DialogueBox.new()
	dialogue_box.initialize(runner, _title_font, _body_font)
	dialogue_box.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	dialogue_box.offset_left = -340
	dialogue_box.offset_right = 340
	dialogue_box.offset_top = -192
	dialogue_box.offset_bottom = -24
	_root.add_child(dialogue_box)

func _build_journal_ui(game_state: RefCounted, player: Node3D) -> void:
	if game_state == null:
		return
	quest_journal = QuestJournal.new()
	quest_journal.initialize(game_state, player, _title_font, _body_font)
	quest_journal.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	quest_journal.offset_left = -240
	quest_journal.offset_right = 240
	quest_journal.offset_top = -180
	quest_journal.offset_bottom = 180
	_root.add_child(quest_journal)

func is_dialogue_open() -> bool:
	return is_instance_valid(dialogue_box) and dialogue_box.visible

func is_journal_open() -> bool:
	return is_instance_valid(quest_journal) and quest_journal.visible

func is_bag_open() -> bool:
	return is_instance_valid(bag_window) and bag_window.visible

func open_dialogue(dialogue_id: String, speaker_name: String) -> void:
	if is_instance_valid(dialogue_box):
		if is_instance_valid(context_menu):
			context_menu.hide()
		if is_instance_valid(quest_journal):
			quest_journal.hide()
		if is_instance_valid(bag_window):
			bag_window.hide()
		_update_menu_bar_states()
		dialogue_box.open_dialogue(dialogue_id, speaker_name)

func _build_pause() -> void:
	pause_screen = Control.new()
	pause_screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pause_screen.visible = false
	_root.add_child(pause_screen)
	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.1, 0.16, 0.12, 0.62)
	pause_screen.add_child(shade)
	var card := PanelContainer.new()
	card.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	card.offset_left = -280
	card.offset_right = 280
	card.offset_top = -200
	card.offset_bottom = 200
	card.add_theme_stylebox_override("panel", _style(Color("22362b"), GOLD, 8))
	pause_screen.add_child(card)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	card.add_child(column)
	pause_title = _label("Game Paused", 34, GOLD, true)
	pause_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(pause_title)
	help_text = _label("• Left click ground: travel\n• Left click object: chop / talk / deposit\n• Right click: context actions\n• Right drag: orbit camera\n• Mouse wheel: zoom\n• B: Rucksack | J: Quest Journal | V: Character View\n• G: Tile grid | Home: Reset camera | Esc: Close window / Pause", 15, TEXT)
	help_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(help_text)
	resume_button = _button("Resume adventure", func(): hide_pause())
	column.add_child(resume_button)

func show_pause(is_help := false) -> void:
	if is_dialogue_open():
		return
	if is_instance_valid(context_menu):
		context_menu.hide()
	pause_title.text = "Controls & Exploration" if is_help else "Game Paused"
	resume_button.text = "Back to adventure" if is_help else "Resume adventure"
	pause_screen.visible = true
	get_tree().paused = true
	pause_changed.emit(true)

func hide_pause() -> void:
	pause_screen.visible = false
	get_tree().paused = false
	pause_changed.emit(false)

func _unhandled_input(event: InputEvent) -> void:
	# 1. Dialogue box consumes input first
	if is_dialogue_open():
		if dialogue_box.handle_input(event):
			get_viewport().set_input_as_handled()
			return

	# 2. Esc closes topmost open window (Bag, Journal, then Pause) per R6
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			if is_instance_valid(context_menu) and context_menu.visible:
				context_menu.hide()
				get_viewport().set_input_as_handled()
				return
			if is_bag_open():
				toggle_bag()
				get_viewport().set_input_as_handled()
				return
			if is_journal_open():
				toggle_journal()
				get_viewport().set_input_as_handled()
				return
			if pause_screen.visible:
				hide_pause()
			else:
				show_pause()
			get_viewport().set_input_as_handled()
			return
		elif event.keycode == KEY_B:
			if not get_tree().paused:
				toggle_bag()
				get_viewport().set_input_as_handled()
				return
		elif event.keycode == KEY_J:
			if not get_tree().paused:
				toggle_journal()
				get_viewport().set_input_as_handled()
				return
		elif event.keycode == KEY_G:
			if not get_tree().paused:
				grid_toggled.emit()
				get_viewport().set_input_as_handled()
				return
		elif event.keycode == KEY_H or event.keycode == KEY_F1:
			show_pause(true)
			get_viewport().set_input_as_handled()
			return

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
	if is_instance_valid(bag_window) and bag_window.visible:
		bag_window.refresh()
	_update_menu_bar_states()

func show_message(text: String, _seconds: float = 3.0) -> void:
	if is_instance_valid(message_log):
		message_log.add_message(text)
