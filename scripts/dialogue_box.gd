# TinyScape — OSRS-Style Dialogue Box with 3D Live Chathead
class_name DialogueBox
extends PanelContainer

signal dialogue_finished

const INK := Color("25382f")
const GOLD := Color("dbc28b")
const TEXT := Color("eee8d9")
const MUTED := Color("b2beb0")

var runner: RefCounted # DialogueRunner
var current_node: Dictionary = {}
var say_sub_index: int = 0
var open_time: float = 0.0
var active_speaker: String = ""

# UI nodes
var chathead_viewport: SubViewport
var chathead_texture_rect: TextureRect
var chathead_camera: Camera3D
var chathead_pivot: Node3D
var name_label: Label
var text_label: Label
var continue_prompt: Label
var choice_container: VBoxContainer
var _title_font: Font
var _body_font: Font

func initialize(p_runner: RefCounted, title_font: Font, body_font: Font) -> void:
	runner = p_runner
	_title_font = title_font
	_body_font = body_font

	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = Vector2(580, 168)
	size = Vector2(580, 168)

	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color("1b2a20")
	panel_style.border_color = Color("53624e")
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(6)
	panel_style.content_margin_left = 12
	panel_style.content_margin_right = 16
	panel_style.content_margin_top = 10
	panel_style.content_margin_bottom = 10
	add_theme_stylebox_override("panel", panel_style)

	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 16)
	add_child(hbox)

	# Left: Chathead square + Nameplate
	var left_vbox = VBoxContainer.new()
	left_vbox.custom_minimum_size = Vector2(148, 148)
	left_vbox.add_theme_constant_override("separation", 4)
	hbox.add_child(left_vbox)

	# Chathead SubViewportContainer & SubViewport
	var vp_container = SubViewportContainer.new()
	vp_container.custom_minimum_size = Vector2(120, 120)
	vp_container.size = Vector2(120, 120)
	vp_container.stretch = true
	left_vbox.add_child(vp_container)

	chathead_viewport = SubViewport.new()
	chathead_viewport.size = Vector2i(256, 256)
	chathead_viewport.transparent_bg = true
	chathead_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp_container.add_child(chathead_viewport)

	_setup_chathead_scene()

	name_label = Label.new()
	name_label.text = "Speaker"
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_override("font", _title_font)
	name_label.add_theme_font_size_override("font_size", 16)
	name_label.add_theme_color_override("font_color", GOLD)
	left_vbox.add_child(name_label)

	# Right: Text / Choices & Continue prompt
	var right_vbox = VBoxContainer.new()
	right_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hbox.add_child(right_vbox)

	text_label = Label.new()
	text_label.add_theme_font_override("font", _body_font)
	text_label.add_theme_font_size_override("font_size", 16)
	text_label.add_theme_color_override("font_color", TEXT)
	text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_vbox.add_child(text_label)

	choice_container = VBoxContainer.new()
	choice_container.add_theme_constant_override("separation", 4)
	choice_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	choice_container.visible = false
	right_vbox.add_child(choice_container)

	continue_prompt = Label.new()
	continue_prompt.text = "Click here to continue"
	continue_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	continue_prompt.add_theme_font_override("font", _body_font)
	continue_prompt.add_theme_font_size_override("font_size", 13)
	continue_prompt.add_theme_color_override("font_color", GOLD)
	right_vbox.add_child(continue_prompt)

func _setup_chathead_scene() -> void:
	var root_3d = Node3D.new()
	chathead_viewport.add_child(root_3d)

	chathead_camera = Camera3D.new()
	chathead_camera.position = Vector3(0.0, 0.05, 0.70)
	chathead_camera.fov = 32.0
	root_3d.add_child(chathead_camera)

	var light = DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-45, 35, 0)
	light.light_color = Color("fff5e0")
	light.light_energy = 1.2
	root_3d.add_child(light)

	chathead_pivot = Node3D.new()
	chathead_pivot.name = "Pivot"
	root_3d.add_child(chathead_pivot)

func open_dialogue(dialogue_id: String, speaker_name: String) -> void:
	current_node = runner.start_dialogue(dialogue_id)
	say_sub_index = 0
	open_time = 0.0
	_render_node(speaker_name)
	show()

func _render_node(default_npc_name: String = "Mabb Truet") -> void:
	open_time = 0.0
	if current_node.is_empty() or current_node.get("type", "") == "end":
		close_dialogue()
		return

	var node_type = current_node.get("type", "end")
	if node_type == "say":
		choice_container.hide()
		text_label.show()
		continue_prompt.show()

		var speaker = current_node.get("speaker", "npc")
		active_speaker = speaker
		name_label.text = "Wanderer" if speaker == "player" else default_npc_name
		_update_chathead_visuals(speaker)

		var lines: Array = current_node.get("text", [])
		if say_sub_index < lines.size():
			text_label.text = lines[say_sub_index]
		else:
			_advance_say(default_npc_name)
	elif node_type == "choice":
		active_speaker = "player"
		name_label.text = "Wanderer"
		_update_chathead_visuals("player")

		text_label.hide()
		continue_prompt.hide()
		choice_container.show()

		for child in choice_container.get_children():
			child.queue_free()

		var prompt = current_node.get("prompt", "")
		if not prompt.is_empty():
			var p_label = Label.new()
			p_label.text = prompt
			p_label.add_theme_font_override("font", _body_font)
			p_label.add_theme_font_size_override("font_size", 14)
			p_label.add_theme_color_override("font_color", MUTED)
			choice_container.add_child(p_label)

		var options: Array = current_node.get("options", [])
		for i in range(options.size()):
			var opt = options[i]
			var btn = Button.new()
			btn.text = "%d. %s" % [i + 1, opt.get("text", "")]
			btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
			btn.add_theme_font_override("font", _body_font)
			btn.add_theme_font_size_override("font_size", 15)
			btn.add_theme_color_override("font_color", TEXT)
			btn.add_theme_color_override("font_hover_color", GOLD)
			btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			var next_id = opt.get("next", "end")
			btn.pressed.connect(func(): _select_option(next_id, default_npc_name))
			choice_container.add_child(btn)

func _update_chathead_visuals(speaker: String) -> void:
	for child in chathead_pivot.get_children():
		child.queue_free()

	var head_mesh = MeshInstance3D.new()
	var box = BoxMesh.new()
	box.size = Vector3(0.28, 0.32, 0.28)
	head_mesh.mesh = box

	var mat = StandardMaterial3D.new()
	mat.roughness = 0.94
	if speaker == "player":
		mat.albedo_color = Color("ce9e7c") # Adventurer skin
		head_mesh.material_override = mat
		chathead_pivot.add_child(head_mesh)

		# Hair / cap
		var cap = MeshInstance3D.new()
		var c_box = BoxMesh.new()
		c_box.size = Vector3(0.30, 0.12, 0.30)
		cap.mesh = c_box
		var cap_mat = StandardMaterial3D.new()
		cap_mat.albedo_color = Color("8b7958")
		cap.material_override = cap_mat
		cap.position = Vector3(0, 0.13, 0)
		chathead_pivot.add_child(cap)
	else:
		mat.albedo_color = Color("b3805e") # Mabb weathered skin
		head_mesh.material_override = mat
		chathead_pivot.add_child(head_mesh)

		# Mabb hair ash
		var hair = MeshInstance3D.new()
		var h_box = BoxMesh.new()
		h_box.size = Vector3(0.30, 0.16, 0.32)
		hair.mesh = h_box
		var h_mat = StandardMaterial3D.new()
		h_mat.albedo_color = Color("8f8b7e")
		hair.material_override = h_mat
		hair.position = Vector3(0, 0.11, -0.02)
		chathead_pivot.add_child(hair)

	chathead_pivot.rotation_degrees = Vector3(4, 15, 0)

func _advance_say(npc_name: String) -> void:
	var lines: Array = current_node.get("text", [])
	say_sub_index += 1
	if say_sub_index < lines.size():
		text_label.text = lines[say_sub_index]
		open_time = 0.0
	else:
		var next_node_id = current_node.get("next", "end")
		say_sub_index = 0
		current_node = runner.go_to_node(next_node_id)
		_render_node(npc_name)

func _select_option(next_node_id: String, npc_name: String) -> void:
	say_sub_index = 0
	current_node = runner.go_to_node(next_node_id)
	_render_node(npc_name)

func close_dialogue() -> void:
	hide()
	current_node.clear()
	dialogue_finished.emit()

func _process(delta: float) -> void:
	if not visible:
		return
	open_time += delta

	# Pulsing continue prompt
	continue_prompt.modulate.a = 0.6 + sin(open_time * 5.0) * 0.4

	# Live chathead bobbing (±3° yaw and nod at ~0.6 Hz)
	if is_instance_valid(chathead_pivot):
		var bob = sin(open_time * TAU * 0.6)
		chathead_pivot.rotation_degrees.x = 4.0 + bob * 2.5
		chathead_pivot.rotation_degrees.y = 15.0 + cos(open_time * TAU * 0.6) * 3.0

func handle_input(event: InputEvent) -> bool:
	if not visible:
		return false

	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			close_dialogue()
			return true

		# 0.25s anti-skip debounce
		if open_time < 0.25:
			return true

		if current_node.get("type", "") == "say":
			if event.keycode == KEY_SPACE or event.keycode == KEY_ENTER:
				_advance_say(name_label.text)
				return true
		elif current_node.get("type", "") == "choice":
			var options: Array = current_node.get("options", [])
			var selected_idx = -1
			match event.keycode:
				KEY_1: selected_idx = 0
				KEY_2: selected_idx = 1
				KEY_3: selected_idx = 2
				KEY_4: selected_idx = 3
			if selected_idx >= 0 and selected_idx < options.size():
				var next_id = options[selected_idx].get("next", "end")
				_select_option(next_id, name_label.text)
				return true
		return true

	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if open_time < 0.25:
			return true
		if current_node.get("type", "") == "say":
			_advance_say(name_label.text)
			return true
		return true

	return true
