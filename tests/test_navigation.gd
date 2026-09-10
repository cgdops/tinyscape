extends SceneTree

const Navigation = preload("res://scripts/navigation.gd")
const Movement = preload("res://scripts/movement.gd")
var checks := 0
var failures := 0

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)

func _initialize() -> void:
	var nav = Navigation.new()
	var blocked: Array[Vector2i] = [Vector2i(2, 1), Vector2i(2, 2), Vector2i(2, 3)]
	nav.configure(Rect2i(0, 0, 6, 6), blocked)
	check(nav.is_walkable(Vector2i(0, 0)), "Open tile must be walkable")
	check(not nav.is_walkable(Vector2i(-1, 0)), "Outside map must be blocked")
	check(nav.find_path(Vector2i.ZERO, Vector2i(2, 2)).is_empty(), "Solid destination must be rejected")
	check(nav.find_path(Vector2i.ZERO, Vector2i(20, 2)).is_empty(), "Outside destination must be rejected")
	var path: Array[Vector2i] = nav.find_path(Vector2i(0, 2), Vector2i(4, 2))
	check(not path.is_empty(), "Must route around wall")
	if not path.is_empty():
		check(path.back() == Vector2i(4, 2), "Path must reach requested destination")
		var previous := Vector2i(0, 2)
		for point in path:
			check(not blocked.has(point), "Path cannot enter obstacle")
			var step := point - previous
			check(absi(step.x) <= 1 and absi(step.y) <= 1, "Path steps must be adjacent tiles")
			if step.x != 0 and step.y != 0:
				check(nav.is_walkable(previous + Vector2i(step.x, 0)) and nav.is_walkable(previous + Vector2i(0, step.y)), "Diagonal cannot clip wall corner")
			previous = point
	var pocket: Array[Vector2i] = [Vector2i(1, 0), Vector2i(0, 1)]
	nav.configure(Rect2i(0, 0, 5, 5), pocket)
	check(nav.find_path(Vector2i.ZERO, Vector2i(1, 1)).is_empty(), "Cannot escape diagonally through two blocked neighbors")
	nav.configure(Rect2i(0, 0, 8, 8), [])
	var motion = Movement.new(Vector2i.ZERO, 2.0)
	check(motion.request_destination(nav, Vector2i(3, 0)), "Accept reachable destination")
	motion.advance(0.2)
	check(motion.moving and motion.position.is_equal_approx(Vector2(0.4, 0)), "Move at exact speed along first edge")
	check(motion.current_tile == Vector2i.ZERO, "Current tile changes only on arrival")
	check(motion.request_destination(nav, Vector2i(0, 3)), "Accept mid-edge reroute")
	motion.advance(0.2)
	check(motion.position.is_equal_approx(Vector2(0.8, 0)), "Reroute must finish current edge without sideways drift")
	motion.advance(10.0)
	check(motion.current_tile == Vector2i(0, 3) and motion.position == Vector2(0, 3), "Arrival snaps exactly to destination")
	check(not motion.moving, "Arrival transitions to idle")
	check(motion.request_destination(nav, motion.current_tile), "Click current tile is a valid no-op")
	check(not motion.moving, "Click current tile does not start walking")
	var fast = Movement.new(Vector2i.ZERO, 3.2)
	var slow = Movement.new(Vector2i.ZERO, 3.2)
	fast.request_destination(nav, Vector2i(6, 5))
	slow.request_destination(nav, Vector2i(6, 5))
	fast.advance(1.0)
	for index in 100:
		slow.advance(0.01)
	check(fast.position.distance_to(slow.position) < 0.0001, "Movement must be frame-rate independent")
	var before: Vector2i = slow.destination
	check(not slow.request_destination(nav, Vector2i(99, 99)), "Invalid reroute rejected")
	check(slow.destination == before and slow.moving, "Invalid click preserves valid route")
	print("Navigation tests: %s checks, %s failures" % [checks, failures])
	quit(1 if failures else 0)
