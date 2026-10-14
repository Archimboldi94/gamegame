class_name Pathing
extends RefCounted
## Movement rules on a height map.
## - Climbing up by dh costs ceil(dh / 2) extra movement and is impossible if dh > jump.
## - Dropping down is free but impossible if the drop exceeds jump + DROP_EXTRA.
## - Units may pass through allies but never through enemies, and cannot end on an occupied tile.
## - Deep water / river is impassable unless the unit is flying; fords and bridges are walkable.

const DROP_EXTRA := 1


static func climb_extra(dh: int) -> int:
	return (dh + 1) / 2 if dh > 0 else 0


## Movement cost to step from `from` to the adjacent tile `to`, or -1 if blocked by terrain/height.
static func enter_cost(map: BattleMap, jump: int, from: Vector2i, to: Vector2i, flying := false) -> int:
	if not map.is_passable(to, flying):
		return -1
	var dh := map.get_h(to) - map.get_h(from)
	if dh > jump:
		return -1
	if -dh > jump + DROP_EXTRA:
		return -1
	return map.move_cost(to, flying) + climb_extra(dh)


## Dijkstra flood fill. Returns {"cost": {pos: int}, "prev": {pos: pos}, "ends": [pos...]}
static func search(map: BattleMap, unit: BattleUnit, units: Array, max_cost: int) -> Dictionary:
	var occ := {}
	for o in units:
		if o != unit and o.alive():
			occ[o.pos] = o
	var cost := {unit.pos: 0}
	var prev := {}
	var open: Array = [unit.pos]
	while not open.is_empty():
		var bi := 0
		for i in range(1, open.size()):
			if cost[open[i]] < cost[open[bi]]:
				bi = i
		var cur: Vector2i = open[bi]
		open.remove_at(bi)
		for d in BattleMap.DIRS:
			var nx: Vector2i = cur + d
			if not map.in_bounds(nx):
				continue
			var o = occ.get(nx)
			if o != null and o.team != unit.team:
				continue
			var c := enter_cost(map, unit.jump, cur, nx, unit.flying)
			if c < 0:
				continue
			var nc: int = int(cost[cur]) + c
			if nc > max_cost:
				continue
			if not cost.has(nx) or nc < int(cost[nx]):
				cost[nx] = nc
				prev[nx] = cur
				if not open.has(nx):
					open.append(nx)
	var ends := []
	for p in cost:
		if not occ.has(p):
			ends.append(p)
	return {"cost": cost, "prev": prev, "ends": ends}


static func path_to(result: Dictionary, start: Vector2i, goal: Vector2i) -> Array:
	var path: Array = []
	if not result["cost"].has(goal):
		return path
	var cur := goal
	path.append(cur)
	var guard := 0
	while cur != start and guard < 1000:
		cur = result["prev"][cur]
		path.push_front(cur)
		guard += 1
	return path


static func manhattan(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)
