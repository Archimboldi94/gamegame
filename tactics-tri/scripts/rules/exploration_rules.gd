class_name ExplorationRules
extends RefCounted
## Design tiles define scenery/collision only. Movement always uses world pixels.

const TILE := 48
const SPEED := 220.0
const BODY_RADIUS := 10.0
const INTERACTION_RADIUS := 70.0
const OUTDOOR_POINTS := {
	"inn_door": Vector2i(8, 21), "ferry_event": Vector2i(37, 23),
	"bamboo_event": Vector2i(16, 7), "shrine_event": Vector2i(37, 8),
	"explore_spawn": Vector2i(8, 23),
}
const INN_POINTS := {
	"exit": Vector2i(6, 9), "keeper": Vector2i(6, 3), "meng": Vector2i(3, 3),
	"luo": Vector2i(10, 3), "codex": Vector2i(3, 6), "training": Vector2i(10, 6),
	"inn_spawn": Vector2i(6, 8),
}


static func center(cell: Vector2i) -> Vector2:
	return (Vector2(cell) + Vector2(0.5, 0.5)) * TILE


static func movement_velocity(direction: Vector2) -> Vector2:
	return direction.limit_length(1.0) * SPEED


static func in_interaction_radius(player: Vector2, target: Vector2) -> bool:
	return player.distance_squared_to(target) <= INTERACTION_RADIUS * INTERACTION_RADIUS


static func grid(area: String) -> Array[String]:
	var blueprint: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/wuxia/qingyadu_blueprint_v1.3.json"))
	var rows: Array[String] = []
	rows.assign(blueprint["scenes"][area]["terrain_grid"])
	# Blueprint R is drawn one column left of its coordinate table. The GDD table wins.
	var points: Dictionary = OUTDOOR_POINTS if area == "outdoor" else INN_POINTS
	for point: Vector2i in points.values():
		rows[point.y] = rows[point.y].substr(0, point.x) + "." + rows[point.y].substr(point.x + 1)
	return rows


static func is_blocked(rows: Array[String], cell: Vector2i) -> bool:
	if cell.y < 0 or cell.y >= rows.size() or cell.x < 0 or cell.x >= rows[0].length():
		return true
	return rows[cell.y][cell.x] in ["#", "H", "~"]


## Uses the same solid cells as the runtime StaticBody2D shapes, with player clearance.
static func safe_position(rows: Array[String], point: Vector2) -> bool:
	if not point.is_finite():
		return false
	var lo := Vector2i(((point - Vector2.ONE * BODY_RADIUS) / TILE).floor())
	var hi := Vector2i(((point + Vector2.ONE * BODY_RADIUS) / TILE).floor())
	for y in range(lo.y, hi.y + 1):
		for x in range(lo.x, hi.x + 1):
			if is_blocked(rows, Vector2i(x, y)):
				return false
	return true


static func valid_spawn(area: String, point: Vector2) -> Vector2:
	var rows := grid(area)
	if safe_position(rows, point):
		# Indoor NPCs and furniture also have solid feet.
		var occupied := false
		if area == "inn":
			for key in ["keeper", "meng", "luo", "codex", "training"]:
				if point.distance_to(center(INN_POINTS[key])) < 30:
					occupied = true
		if not occupied:
			return point
	return center(OUTDOOR_POINTS["explore_spawn"] if area == "outdoor" else INN_POINTS["inn_spawn"])
