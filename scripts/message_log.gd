# TinyScape — Scrolling Message Log Component
class_name MessageLog
extends PanelContainer

const INK := Color("25382f")
const GOLD := Color("dbc28b")
const TEXT := Color("eee8d9")
const MUTED := Color("b2beb0")

var scroll_container: ScrollContainer
var v_box: VBoxContainer
var _title_font: Font
var _body_font: Font

var _messages: Array[Dictionary] = [] # Array of { "raw": String, "count": int, "label": Label }
const MAX_LINES: int = 100

func initialize(title_font: Font, body_font: Font) -> void:
	_title_font = title_font
	_body_font = body_font
	name = "MessageLog"
	mouse_filter = Control.MOUSE_FILTER_PASS

	# Dimensions: roughly 460 px wide, ~130 px tall (6 lines)
	custom_minimum_size = Vector2(460, 130)
	size = Vector2(460, 130)

	var style = StyleBoxFlat.new()
	style.bg_color = Color("1e2f24")
	style.border_color = Color("455b44")
	style.set_border_width_all(1)
	style.set_corner_radius_all(5)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	add_theme_stylebox_override("panel", style)

	scroll_container = ScrollContainer.new()
	scroll_container.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll_container.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(scroll_container)

	v_box = VBoxContainer.new()
	v_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v_box.add_theme_constant_override("separation", 2)
	scroll_container.add_child(v_box)

func add_message(text: String) -> void:
	if text.strip_edges().is_empty():
		return

	# Check for repeat collapse: Willow logs (x4)
	if not _messages.is_empty():
		var last = _messages[_messages.size() - 1]
		if last["raw"] == text:
			last["count"] += 1
			var lbl: Label = last["label"]
			lbl.text = "%s (×%d)" % [text, last["count"]]
			_update_dimming()
			_scroll_to_bottom()
			return

	var label = Label.new()
	label.text = text
	label.add_theme_font_override("font", _body_font)
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", TEXT)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v_box.add_child(label)

	_messages.append({
		"raw": text,
		"count": 1,
		"label": label
	})

	if _messages.size() > MAX_LINES:
		var oldest = _messages.pop_front()
		if is_instance_valid(oldest.get("label")):
			oldest["label"].queue_free()

	_update_dimming()
	_scroll_to_bottom()

func _update_dimming() -> void:
	var count = _messages.size()
	for i in range(count):
		var entry = _messages[i]
		var lbl: Label = entry.get("label")
		if not is_instance_valid(lbl):
			continue
		# Older lines dim slightly toward top
		var dist_from_bottom: float = float(count - 1 - i)
		var alpha: float = clampf(1.0 - (dist_from_bottom * 0.08), 0.45, 1.0)
		lbl.modulate.a = alpha

func _scroll_to_bottom() -> void:
	call_deferred("_do_scroll_bottom")

func _do_scroll_bottom() -> void:
	if is_instance_valid(scroll_container):
		var vbar = scroll_container.get_v_scroll_bar()
		if vbar:
			scroll_container.scroll_vertical = int(vbar.max_value)
