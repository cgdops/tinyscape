extends Camera3D

const MIN_ZOOM := 3.5
const MAX_ZOOM := 40.0
const DEFAULT_ZOOM := 24.0
const DEFAULT_YAW := 0.63
const DEFAULT_PITCH := 0.83
const MAX_PITCH := 1.22
const ZOOM_FACTOR := 1.12

var target: Node3D
var yaw: float = DEFAULT_YAW
var pitch: float = DEFAULT_PITCH
var zoom: float = DEFAULT_ZOOM
var orbiting: bool = false

var _target_pitch: float = DEFAULT_PITCH
var _prev_zoom: float = DEFAULT_ZOOM
var _prev_pitch: float = DEFAULT_PITCH
var _is_close_preset: bool = false

var _focus: Vector3 = Vector3.ZERO
var _initialized: bool = false

func _ready() -> void:
	projection = Camera3D.PROJECTION_ORTHOGONAL
	near = 0.1
	far = 180.0
	current = true

func min_pitch_for_size(s: float) -> float:
	# R5: 0.28 rad at size <= 6.0, 0.50 rad at size >= 20.0, linear between
	if s <= 6.0:
		return 0.28
	elif s >= 20.0:
		return 0.50
	var t := (s - 6.0) / (20.0 - 6.0)
	return lerpf(0.28, 0.50, t)

func reset_view() -> void:
	# R8: Home still resets fully. Yaw 0.63, pitch 0.83, zoom 24.0, eased rather than snapped
	yaw = DEFAULT_YAW
	_target_pitch = DEFAULT_PITCH
	zoom = DEFAULT_ZOOM
	_is_close_preset = false

func toggle_character_view() -> void:
	# R7: V becomes a preset, not a mode. Keep the key. Pressing V eases zoom to 4.0
	# and pitch to 0.35, leaving yaw untouched. Pressing V again returns to previous zoom & pitch.
	if _is_close_preset:
		zoom = _prev_zoom
		_target_pitch = _prev_pitch
		_is_close_preset = false
	else:
		_prev_zoom = zoom
		_prev_pitch = _target_pitch
		zoom = 4.0
		_target_pitch = 0.35
		_is_close_preset = true

func _process(delta: float) -> void:
	if target == null:
		return
	if Input.is_physical_key_pressed(KEY_Q):
		yaw += delta * 1.2
	if Input.is_physical_key_pressed(KEY_E):
		yaw -= delta * 1.2

	# R2: The character stays framed while zooming. Focus point does not scale with zoom.
	# Chest height target: target.position + Vector3(0, 0.9, 0)
	var desired := target.position + Vector3(0, 0.9, 0)
	if not _initialized:
		_focus = desired
		_initialized = true
	else:
		_focus = _focus.lerp(desired, 1.0 - exp(-3.0 * delta))

	# R9: Zoom smoothing preserved
	size = lerpf(size, zoom, 1.0 - exp(-10.0 * delta))

	# R5: Pitch easing and clamping based on size
	var min_p := min_pitch_for_size(size)
	if not orbiting:
		# If current target pitch is below the allowed min pitch for current size, ease up
		if _target_pitch < min_p:
			_target_pitch = min_p
		pitch = lerpf(pitch, _target_pitch, 1.0 - exp(-10.0 * delta))
	pitch = clampf(pitch, min_p, MAX_PITCH)

	position = _focus + Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch)) * 42.0
	look_at(_focus)

const DRAG_THRESHOLD: float = 6.0

var rmb_down_pos := Vector2.ZERO
var rmb_dragged := false

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and not event.pressed:
		orbiting = false

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		orbiting = false
		rmb_dragged = true # Suppress context menu if focus lost mid-press

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		match event.button_index:
			MOUSE_BUTTON_RIGHT:
				if event.pressed:
					rmb_down_pos = event.position
					rmb_dragged = false
					orbiting = true
				else:
					orbiting = false
			MOUSE_BUTTON_WHEEL_UP:
				# R3: Proportional zoom steps. Zoom in: zoom /= 1.12
				if event.pressed:
					zoom = clampf(zoom / ZOOM_FACTOR, MIN_ZOOM, MAX_ZOOM)
					_is_close_preset = false
			MOUSE_BUTTON_WHEEL_DOWN:
				# R3: Proportional zoom steps. Zoom out: zoom *= 1.12
				if event.pressed:
					zoom = clampf(zoom * ZOOM_FACTOR, MIN_ZOOM, MAX_ZOOM)
					_is_close_preset = false
	if event is InputEventMouseMotion and orbiting:
		if event.position.distance_to(rmb_down_pos) >= DRAG_THRESHOLD:
			rmb_dragged = true
		yaw -= event.relative.x * 0.006
		var min_p := min_pitch_for_size(size)
		pitch = clampf(pitch + event.relative.y * 0.004, min_p, MAX_PITCH)
		_target_pitch = pitch
	if event is InputEventKey and event.pressed and event.keycode == KEY_HOME:
		reset_view()
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_V:
		toggle_character_view()