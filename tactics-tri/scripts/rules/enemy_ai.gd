class_name EnemyAI
extends RefCounted
## Greedy one-turn planner usable by either team: tries every reachable tile x usable action x
## target, scores expected damage (kills, back/side attacks and pincers weigh extra) or useful
## healing, and otherwise walks toward the closest opponent.

const HOLD_RADIUS := 6


static func plan(state: BattleState, u: BattleUnit) -> Dictionary:
	var reach := state.reachable_for(u)
	var ends: Array = reach["ends"]
	var foes := state.living(1 - u.team)
	var best := {"score": 0.5, "move": u.pos, "skill": "", "target": Vector2i(-1, -1)}
	var holding := u.ai == "hold" and _nearest_dist(u.pos, foes) > HOLD_RADIUS
	var candidates: Array = [u.pos] if holding else ends
	var caution := (8.0 if u.is_lord else 1.5) * (2.0 - float(u.hp) / float(u.max_hp))
	for tile in candidates:
		var tile_bonus: float = state.map.get_h(tile) * 0.3 - threat_count(state, u, tile) * caution
		if state.map.effect_at(tile) == "fire":
			tile_bonus -= 8.0
		for sid in u.all_actions():
			var sk := SkillDB.get_skill(sid)
			if sk["kind"] == "self" or int(sk["tp"]) > u.tp:
				continue
			for t in _candidate_targets(state, u, sk, tile):
				var entries := state.preview(u, sid, t, tile)
				var sc := score_entries(entries)
				if sc <= 0.0:
					continue
				sc += tile_bonus - float(sk["tp"]) * 1.5
				if sc > float(best["score"]):
					best = {"score": sc, "move": tile, "skill": sid, "target": t}
	if best["skill"] == "" and not holding:
		best["move"] = approach_tile(state, u, reach)
		if u.tp >= 1 and u.skills.has("guard") and _nearest_dist(best["move"], foes) <= 2:
			best["skill"] = "guard"
			best["target"] = best["move"]
	return best


static func _candidate_targets(state: BattleState, u: BattleUnit, sk: Dictionary, from: Vector2i) -> Array:
	var out := []
	var reach: int = int(sk["rmax"]) + (Combat.RANGE_BONUS_CAP if sk["height_range"] else 0) + (1 if sk["shape"] == "area1" else 0)
	var wants_ally: bool = sk["kind"] == "heal"
	var near_unit := false
	for o in state.units:
		if not o.alive() or (o.team == u.team) != wants_ally:
			continue
		if Pathing.manhattan(o.pos, from) <= reach:
			near_unit = true
			break
	if not near_unit:
		return out
	for p in state.target_tiles(u, sk["id"], from):
		out.append(p)
	return out


static func score_entries(entries: Array) -> float:
	var s := 0.0
	for e in entries:
		var t: BattleUnit = e["unit"]
		if e["heal"]:
			var missing := t.max_hp - t.hp
			if missing <= 0:
				continue
			var useful := mini(missing, int(e["dmg"]))
			s += useful * (1.4 if missing * 2 > t.max_hp else 0.5)
			continue
		var dmg := mini(int(e["dmg"]), t.hp)
		var p := float(e["hit"]) / 100.0
		s += dmg * p
		if int(e["dmg"]) >= t.hp:
			s += 25.0 * p
		if t.is_lord or t.is_leader:
			s += 6.0
		if e["side"] == "back":
			s += 8.0
		elif e["side"] == "side":
			s += 3.0
		if e.has("pincer"):
			s += float(e["pincer_dmg"]) * float(e["pincer_hit"]) / 100.0
	return s


static func approach_tile(state: BattleState, u: BattleUnit, reach: Dictionary) -> Vector2i:
	var foes := state.living(1 - u.team)
	if foes.is_empty():
		return u.pos
	var full := Pathing.search(state.map, u, state.units, 999)
	var goal := u.pos
	var goal_cost := 1 << 30
	var fallback := u.pos
	var fallback_d := 1 << 30
	for p in full["ends"]:
		var d := _nearest_dist(p, foes)
		var c: int = full["cost"][p]
		if d <= 1 and c < goal_cost:
			goal = p
			goal_cost = c
		if d < fallback_d or (d == fallback_d and c < int(full["cost"].get(fallback, 0))):
			fallback = p
			fallback_d = d
	if goal_cost == 1 << 30:
		goal = fallback
	var path := Pathing.path_to(full, u.pos, goal)
	var ends: Array = reach["ends"]
	var pick := u.pos
	for p in path:
		if reach["cost"].has(p) and ends.has(p):
			pick = p
		elif not reach["cost"].has(p):
			break
	return pick


## Rough count of opponents that could strike `tile` on their next turn.
static func threat_count(state: BattleState, u: BattleUnit, tile: Vector2i) -> int:
	var n := 0
	for f in state.units:
		if not f.alive() or f.team == u.team:
			continue
		var r := 0
		for sid in f.all_actions():
			var sk := SkillDB.get_skill(sid)
			if sk["kind"] == "phys" or sk["kind"] == "mag":
				r = maxi(r, int(sk["rmax"]))
		if Pathing.manhattan(f.pos, tile) <= f.mov + r:
			n += 1
	return n


static func _nearest_dist(p: Vector2i, foes: Array) -> int:
	var best := 1 << 30
	for f in foes:
		best = mini(best, Pathing.manhattan(p, f.pos))
	return best
