# TinyScape — 28-Slot Inventory Bag Window (4x7 Grid)
class_name BagWindow
extends PanelContainer

signal item_examined(item: Dictionary)
signal item_dropped(index: int, item: Dictionary)

const INK := Color("25382f")
const GOLD := Color("dbc28b")
const TEXT := Color("eee8d9")
const MUTED := Color("b2beb0")
const HIGHLIGHT := Color("fff6e4")

var player: Node3D
var _title_font: Font
var _body_font: Font
var grid_container: GridContainer
var slots: Array[PanelContainer] = []

var context_menu_callback: Callable

func initialize(p_player: Node3D, title_font: Font, body_font: Font, p_context_callback: Callable = Callable()) -> void:
	player = p_player
	_title_font = title_font
	_body_font = body_font
	context_menu_callback = p_context_callback
	name = "BagWindow"
	visible = false

	# Dimensions: 4 columns x 7 rows
	custom_minimum_size = Vector2(240, 360)

	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color("1e2f24")
	panel_style.border_color = Color("53624e")
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(6)
	panel_style.content_margin_left = 12
	panel_style.content_margin_right = 12
	panel_style.content_margin_top = 10
	panel_style.content_margin_bottom = 10
	add_theme_stylebox_override("panel", panel_style)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	add_child(vbox)

	# Header: "Rucksack" + count
	var header_hbox = HBoxContainer.new()
	vbox.add_child(header_hbox)

	var title_lbl = Label.new()
	title_lbl.text = "Rucksack"
	title_lbl.add_theme_font_override("font", _title_font)
	title_lbl.add_theme_font_size_override("font_size", 18)
	title_lbl.add_theme_color_override("font_color", GOLD)
	title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_hbox.add_child(title_lbl)

	var count_lbl = Label.new()
	count_lbl.name = "CountLabel"
	count_lbl.text = "0/28"
	count_lbl.add_theme_font_override("font", _body_font)
	count_lbl.add_theme_font_size_override("font_size", 14)
	count_lbl.add_theme_color_override("font_color", MUTED)
	header_hbox.add_child(count_lbl)

	# 4x7 Slots Grid
	grid_container = GridContainer.new()
	grid_container.columns = 4
	grid_container.add_theme_constant_override("h_separation", 6)
	grid_container.add_theme_constant_override("v_separation", 6)
	vbox.add_child(grid_container)

	_create_slots()
	refresh()

func _create_slots() -> void:
	slots.clear()
	for child in grid_container.get_children():
		child.queue_free()

	for i in range(28):
		var slot = PanelContainer.new()
		slot.custom_minimum_size = Vector2(48, 42)
		slot.mouse_filter = Control.MOUSE_FILTER_PASS

		var slot_style = StyleBoxFlat.new()
		slot_style.bg_color = Color("14221a")
		slot_style.border_color = Color("2e4235")
		slot_style.set_border_width_all(1)
		slot_style.set_corner_radius_all(4)
		slot.add_theme_stylebox_override("panel", slot_style)

		var icon_rect = TextureRect.new()
		icon_rect.name = "Icon"
		icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon_rect.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		icon_rect.size_flags_vertical = Control.SIZE_EXPAND_FILL
		icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(icon_rect)

		var idx = i
		slot.mouse_entered.connect(func(): _on_slot_hover(slot, idx, true))
		slot.mouse_exited.connect(func(): _on_slot_hover(slot, idx, false))
		slot.gui_input.connect(func(ev): _on_slot_gui_input(ev, idx))

		grid_container.add_child(slot)
		slots.append(slot)

func _on_slot_hover(slot: PanelContainer, slot_index: int, hovered: bool) -> void:
	var style = slot.get_theme_stylebox("panel").duplicate() as StyleBoxFlat
	if hovered:
		style.border_color = HIGHLIGHT
		style.set_border_width_all(2)
	else:
		style.border_color = Color("2e4235")
		style.set_border_width_all(1)
	slot.add_theme_stylebox_override("panel", style)

func _on_slot_gui_input(event: InputEvent, slot_index: int) -> void:
	if not (event is InputEventMouseButton and event.pressed):
		return
	if not is_instance_valid(player):
		return
	if slot_index >= player.inventory.size():
		return
	var item = player.inventory[slot_index]

	if event.button_index == MOUSE_BUTTON_RIGHT:
		var mouse_pos = get_global_mouse_position()
		var options: Array[Dictionary] = [
			{
				"text": "Examine " + item.get("name", "Item"),
				"callback": func(): item_examined.emit(item)
			},
			{
				"text": "Drop " + item.get("name", "Item"),
				"callback": func(): item_dropped.emit(slot_index, item)
			},
			{
				"text": "Cancel",
				"callback": Callable()
			}
		]
		if context_menu_callback.is_valid():
			context_menu_callback.call(mouse_pos, options)

func refresh() -> void:
	if not is_instance_valid(player):
		return

	var inv: Array = player.inventory
	var count_lbl: Label = find_child("CountLabel", true, false) as Label
	if count_lbl:
		count_lbl.text = "%d/28" % inv.size()
		if inv.size() >= 28:
			count_lbl.add_theme_color_override("font_color", Color("e6b85b"))
		else:
			count_lbl.add_theme_color_override("font_color", MUTED)

	for i in range(28):
		var slot = slots[i]
		var icon_rect: TextureRect = slot.get_node("Icon") as TextureRect
		if i < inv.size():
			var item = inv[i]
			var item_type: String = item.get("type", "oak")
			var tex = IconGenerator.get_icon_texture(self, item_type)
			icon_rect.texture = tex
			slot.tooltip_text = "%s (Value: %d coins)" % [item.get("name", "Log"), item.get("value", 4)]
		else:
			icon_rect.texture = null
			slot.tooltip_text = "Empty slot"
