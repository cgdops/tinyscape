# TinyScape — Quest Journal UI Panel
class_name QuestJournal
extends PanelContainer

const INK := Color("25382f")
const GOLD := Color("dbc28b")
const TEXT := Color("eee8d9")
const MUTED := Color("858a78")

var game_state: RefCounted # GameState
var player: Node3D
var _title_font: Font
var _body_font: Font

var list_vbox: VBoxContainer

func initialize(p_game_state: RefCounted, p_player: Node3D, title_font: Font, body_font: Font) -> void:
	game_state = p_game_state
	player = p_player
	_title_font = title_font
	_body_font = body_font

	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = Vector2(480, 360)
	size = Vector2(480, 360)

	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color("1e2f24")
	panel_style.border_color = Color("53624e")
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(6)
	panel_style.content_margin_left = 20
	panel_style.content_margin_right = 20
	panel_style.content_margin_top = 16
	panel_style.content_margin_bottom = 16
	add_theme_stylebox_override("panel", panel_style)

	var main_vbox = VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 12)
	add_child(main_vbox)

	var header = HBoxContainer.new()
	main_vbox.add_child(header)

	var title = Label.new()
	title.text = "Quest Journal"
	title.add_theme_font_override("font", _title_font)
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", GOLD)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)

	var close_hint = Label.new()
	close_hint.text = "J / Esc to close"
	close_hint.add_theme_font_override("font", _body_font)
	close_hint.add_theme_font_size_override("font_size", 13)
	close_hint.add_theme_color_override("font_color", MUTED)
	header.add_child(close_hint)

	var sep = HSeparator.new()
	sep.modulate = Color("687259")
	main_vbox.add_child(sep)

	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_vbox.add_child(scroll)

	list_vbox = VBoxContainer.new()
	list_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list_vbox.add_theme_constant_override("separation", 14)
	scroll.add_child(list_vbox)

func toggle_journal() -> void:
	if visible:
		hide()
	else:
		refresh_journal()
		show()

func refresh_journal() -> void:
	for child in list_vbox.get_children():
		child.queue_free()

	var active_quests: Array[Dictionary] = []
	var completed_quests: Array[Dictionary] = []

	for q_id in QuestData.QUESTS:
		var state = game_state.get_quest_state(q_id)
		if state == "unstarted":
			continue
		var q_data = QuestData.get_quest_info(q_id)
		var item = {
			"id": q_id,
			"name": q_data.get("display_name", q_id),
			"state": state,
			"journal": QuestData.get_journal_line(q_id, state)
		}
		if state == "complete":
			completed_quests.append(item)
		else:
			active_quests.append(item)

	if active_quests.is_empty() and completed_quests.is_empty():
		var empty_lbl = Label.new()
		empty_lbl.text = "You have not undertaken any quests yet.\nSpeak with the villagers of Willowmere."
		empty_lbl.add_theme_font_override("font", _body_font)
		empty_lbl.add_theme_font_size_override("font_size", 15)
		empty_lbl.add_theme_color_override("font_color", MUTED)
		empty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		list_vbox.add_child(empty_lbl)
		return

	# Render Active Quests
	if not active_quests.is_empty():
		var act_header = Label.new()
		act_header.text = "Active Quests"
		act_header.add_theme_font_override("font", _title_font)
		act_header.add_theme_font_size_override("font_size", 18)
		act_header.add_theme_color_override("font_color", GOLD)
		list_vbox.add_child(act_header)

		for item in active_quests:
			_add_quest_card(item, false)

	# Render Completed Quests (dimmed)
	if not completed_quests.is_empty():
		var comp_header = Label.new()
		comp_header.text = "Completed"
		comp_header.add_theme_font_override("font", _title_font)
		comp_header.add_theme_font_size_override("font_size", 18)
		comp_header.add_theme_color_override("font_color", MUTED)
		list_vbox.add_child(comp_header)

		for item in completed_quests:
			_add_quest_card(item, true)

func _add_quest_card(item: Dictionary, completed: bool) -> void:
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 2)
	list_vbox.add_child(vbox)

	var name_lbl = Label.new()
	name_lbl.text = item["name"]
	name_lbl.add_theme_font_override("font", _title_font)
	name_lbl.add_theme_font_size_override("font_size", 16)
	name_lbl.add_theme_color_override("font_color", MUTED if completed else GOLD)
	vbox.add_child(name_lbl)

	var desc_lbl = Label.new()
	desc_lbl.text = item["journal"]
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_lbl.add_theme_font_override("font", _body_font)
	desc_lbl.add_theme_font_size_override("font_size", 14)
	desc_lbl.add_theme_color_override("font_color", MUTED if completed else TEXT)
	vbox.add_child(desc_lbl)
