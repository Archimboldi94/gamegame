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
	if not map.in_bounds(from) or chebyshev(from, to) != 1 or not map.is_passable(to, flying):
		return -1
	if closed_corner(map, from, to, flying):
		return -1
	var dh := map.get_h(to) - map.get_h(from)
	if dh > jump:
		return -1
	if -dh > jump + DROP_EXTRA:
		return -1
	return map.move_cost(to, flying) + climb_extra(dh)


## Only a pair of solid side cells seals a diagonal; one obstacle permits passing its edge.
static func closed_corner(map: BattleMap, from: Vector2i, to: Vector2i, flying := false) -> bool:
	var d := to - from
	return d.x != 0 and d.y != 0 and not map.is_passable(from + Vector2i(d.x, 0), flying) and not map.is_passable(from + Vector2i(0, d.y), flying)


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
			if o != null and (unit.use_gdd_rules or o.team != unit.team):
				continue
			var c := enter_cost(map, unit.jump, cur, nx, unit.flying)
			if c < 0:
				continue
			var nc: int = int(cost[cur]) + c
			if nc > max_cost:
				continue
			var better := not cost.has(nx) or nc < int(cost[nx])
			if not better and nc == int(cost.get(nx, -1)):
				# Prefer orthogonal last-steps so facing stays cardinal when possible.
				var old_d: Vector2i = nx - prev[nx]
				var new_d: Vector2i = nx - cur
				better = (new_d.x == 0 or new_d.y == 0) and not (old_d.x == 0 or old_d.y == 0)
			if better:
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


## Lightfoot pays a fixed skill cost; distance counts steps, not terrain AP.
## Low obstacles may be crossed by Yanxing, but are never valid landings.
static func lightfoot_search(map: BattleMap, unit: BattleUnit, units: Array, from: Vector2i, distance: int, cross_low: bool) -> Dictionary:
	var occupied := {}
	for other in units:
		if other != unit and other.alive():
			occupied[other.pos] = true
	var cost := {from: 0}
	var prev := {}
	var queue: Array = [from]
	var ends := []
	while not queue.is_empty():
		var p: Vector2i = queue.pop_front()
		if p != from and map.is_passable(p, unit.flying):
			ends.append(p)
		if int(cost[p]) >= distance:
			continue
		for d in BattleMap.DIRS:
			var next: Vector2i = p + d
			if cost.has(next) or occupied.has(next) or not _lightfoot_passable(map, next, unit.flying, cross_low):
				continue
			if cross_low:
				if d.x != 0 and d.y != 0 and not _lightfoot_passable(map, p + Vector2i(d.x, 0), unit.flying, true) and not _lightfoot_passable(map, p + Vector2i(0, d.y), unit.flying, true):
					continue
			elif enter_cost(map, unit.jump, p, next, unit.flying) < 0:
				continue
			cost[next] = int(cost[p]) + 1
			prev[next] = p
			queue.append(next)
	return {"cost": cost, "prev": prev, "ends": ends}


static func _lightfoot_passable(map: BattleMap, p: Vector2i, flying: bool, cross_low: bool) -> bool:
	return map.in_bounds(p) and (map.is_passable(p, flying) or (cross_low and bool(Terrain.info(map.get_terrain(p)).get("leap_over", false))))


static func manhattan(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)


static func chebyshev(a: Vector2i, b: Vector2i) -> int:
	return maxi(absi(a.x - b.x), absi(a.y - b.y))
