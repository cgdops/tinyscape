extends Camera3D

var target: Node3D
var yaw := 0.63
var pitch := 0.83
var zoom := 24.0
var orbiting := false
var inspecting := false
var _focus := Vector3.ZERO
var _initialized := false

func _ready() -> void:
	projection = Camera3D.PROJECTION_ORTHOGONAL
	near = 0.1
	far = 180.0
	current = true

func reset_view() -> void:
	inspecting = false
	yaw = 0.63
	pitch = 0.83
	zoom = 24.0
	_initialized = false

func toggle_character_view() -> void:
	if inspecting:
		reset_view()
	else:
		inspecting = true
		zoom = 7.5
		pitch = 0.42
		yaw = 0.45

func _process(delta: float) -> void:
	if target == null:
		return
	if Input.is_physical_key_pressed(KEY_Q):
		yaw += delta * 1.2
	if Input.is_physical_key_pressed(KEY_E):
		yaw -= delta * 1.2
	var desired := target.position + Vector3(0, 0.6, -4.5 * zoom / 24.0)
	if inspecting:
		desired = target.position + Vector3(0, 0.9, 0)
	if not _initialized:
		_focus = desired
		_initialized = true
	else:
		_focus = _focus.lerp(desired, 1.0 - exp(-3.0 * delta))
	size = lerpf(size, zoom, 1.0 - exp(-10.0 * delta))
	position = _focus + Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch)) * 42.0
	look_at(_focus)

var _rmb_down_pos := Vector2.ZERO
var _rmb_dragged := false

func _input(event: InputEvent) -> void:
	# Always release drag even when the pointer ends over an interface panel.
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and not event.pressed:
		orbiting = false

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		orbiting = false

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		match event.button_index:
			MOUSE_BUTTON_RIGHT:
				if event.pressed:
					_rmb_down_pos = event.position
					_rmb_dragged = false
					orbiting = true
				else:
					orbiting = false
			MOUSE_BUTTON_WHEEL_UP:
				if event.pressed:
					zoom = clampf(zoom - 1.5, 6.0, 34.0)
			MOUSE_BUTTON_WHEEL_DOWN:
				if event.pressed:
					zoom = clampf(zoom + 1.5, 6.0, 34.0)
	if event is InputEventMouseMotion and orbiting:
		if event.position.distance_to(_rmb_down_pos) > 5.0:
			_rmb_dragged = true
		yaw -= event.relative.x * 0.006
		pitch = clampf(pitch + event.relative.y * 0.004, 0.50, 1.22)
	if event is InputEventKey and event.pressed and event.keycode == KEY_HOME:
		reset_view()
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_V:
		toggle_character_view()
