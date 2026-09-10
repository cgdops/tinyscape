extends RefCounted

var grid := AStarGrid2D.new()

func configure(region: Rect2i, blocked: Array[Vector2i]) -> void:
	grid.region = region
	grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	grid.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	grid.default_estimate_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	grid.update()
	grid.fill_solid_region(region, false)
	for tile in blocked:
		if grid.is_in_boundsv(tile):
			grid.set_point_solid(tile)

func is_walkable(tile: Vector2i) -> bool:
	return grid.is_in_boundsv(tile) and not grid.is_point_solid(tile)

func set_walkable(tile: Vector2i, walkable: bool) -> void:
	if grid.is_in_boundsv(tile):
		grid.set_point_solid(tile, not walkable)

## Returns adjacent tile centers, excluding the starting tile.
func find_path(from: Vector2i, to: Vector2i) -> Array[Vector2i]:
	if not is_walkable(from) or not is_walkable(to):
		return []
	var path := grid.get_id_path(from, to)
	if not path.is_empty():
		path.pop_front()
	return path
