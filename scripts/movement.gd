extends RefCounted

signal tile_reached(tile: Vector2i)

var current_tile: Vector2i
var position: Vector2
var moving := false
var destination: Vector2i
var direction := Vector2.DOWN
var speed: float
var _next_tile: Vector2i
var _path: Array[Vector2i] = []

func _init(start := Vector2i.ZERO, tiles_per_second := 3.0) -> void:
	current_tile = start
	position = Vector2(start)
	destination = start
	_next_tile = start
	speed = tiles_per_second

func request_destination(navigation: RefCounted, target: Vector2i) -> bool:
	if not navigation.is_walkable(target):
		return false
	# Retarget from the committed edge's endpoint so a click never cuts a corner.
	var origin := _next_tile if moving else current_tile
	var replacement: Array[Vector2i] = navigation.find_path(origin, target)
	if replacement.is_empty() and origin != target:
		return false
	_path = replacement
	destination = target
	if not moving:
		_start_next_edge()
	return true

func advance(delta: float) -> void:
	var distance_left := maxf(delta, 0.0) * speed
	while moving and distance_left > 0.0:
		var target := Vector2(_next_tile)
		var gap := position.distance_to(target)
		if distance_left + 0.000001 >= gap:
			position = target
			current_tile = _next_tile
			distance_left = maxf(0.0, distance_left - gap)
			tile_reached.emit(current_tile)
			_start_next_edge()
		else:
			position = position.move_toward(target, distance_left)
			distance_left = 0.0

func remaining_path() -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if moving:
		result.append(_next_tile)
	result.append_array(_path)
	return result

func _start_next_edge() -> void:
	moving = not _path.is_empty()
	if moving:
		_next_tile = _path.pop_front()
		direction = (Vector2(_next_tile) - position).normalized()
