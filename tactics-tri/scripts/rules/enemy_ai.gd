class_name EnemyAI
extends RefCounted
## Greedy one-turn planner usable by either team: tries every reachable tile x usable action x
## target, scores expected damage (kills, back/side attacks and pincers weigh extra) or useful
## healing, and otherwise walks toward the closest opponent.
## GDD path: expected ZoC opportunity damage is subtracted so AI avoids pointless zone exits.

const HOLD_RADIUS := 6


static func plan(state: BattleState, u: BattleUnit) -> Dictionary:
	var reach := state.reachable_for(u)
	var ends: Array = reach["ends"]
	var foes := state.living(1 - u.team)
	var best := {"score": 0.5, "move": u.pos, "skill": "", "target": Vector2i(-1, -1)}
	var holding := u.ai == "hold" and _nearest_dist(u.pos, foes, u.use_gdd_rules) > HOLD_RADIUS
	var candidates: Array = [u.pos] if holding else ends
	var caution := (8.0 if u.is_lord else 1.5) * (2.0 - float(u.hp) / float(u.max_hp))
	var risk_weight := 1.25
	if foes.size() <= 1:
		risk_weight = 0.55  # finish the last foe instead of forever kiting
	elif float(u.hp) >= float(u.max_hp) * 0.7 and foes.size() <= 2:
		risk_weight = 0.9
	for tile in candidates:
		var risk := path_risk(state, u, tile, reach)
		var tile_bonus: float = state.map.get_h(tile) * 0.3 - threat_count(state, u, tile) * caution - risk * risk_weight
		if state.map.effect_at(tile) == "fire":
			tile_bonus -= 8.0
		if u.use_gdd_rules and state.map.get_terrain(tile) == "trap" and not state.trap_spent(tile):
			tile_bonus -= 7.0
		for sid in u.all_actions():
			var sk: Dictionary = u.skill(sid)
			if sk["kind"] == "self" or sk["kind"] == "move" or not state.skill_usable(u, sid):
				continue
			if u.use_gdd_rules and int(reach["cost"][tile]) + int(sk.get("ap", 0)) > u.ap:
				continue
			for t in _candidate_targets(state, u, sk, tile):
				var entries := state.preview(u, sid, t, tile)
				var sc := score_entries(entries)
				if sc <= 0.0:
					continue
				sc += tile_bonus - float(sk["tp"]) * 1.5
				# Refined arts already bake branch stats into u.skill(); nudge AI to prefer them.
				if u.use_gdd_rules and String(u.skill_branches.get(sid, "")) != "":
					sc += 1.25
				# Only accept lethal ZoC risk when the attack itself is expected to finish the fight.
				if risk >= float(u.hp) * 0.6 and sc < 30.0:
					continue
				if sc > float(best["score"]):
					best = {"score": sc, "move": tile, "skill": sid, "target": t}
	if best["skill"] == "" and not holding:
		best["move"] = approach_tile(state, u, reach)
		if u.tp >= 1 and u.skills.has("guard") and _nearest_dist(best["move"], foes, u.use_gdd_rules) <= 2:
			best["skill"] = "guard"
			best["target"] = best["move"]
	if u.use_gdd_rules:
		best = _gdd_support(state, u, reach, best, foes, holding)
		best = _gdd_mission(state, u, reach, best)
	return best




## Prefer rest / guard / lightfoot when attacks are weak or unreachable.
static func _gdd_support(state: BattleState, u: BattleUnit, reach: Dictionary, best: Dictionary, foes: Array, holding: bool) -> Dictionary:
	var score := float(best["score"])
	var current_dist := _nearest_dist(u.pos, foes, true) if not foes.is_empty() else 999
	# Lightfoot when it closes distance and a walk-in attack is not already planned.
	# 燕行步 is ZoC-immune; 踏雪步 pays normal opportunity risk but lands with 护势.
	if (best["skill"] == "" or score < 6.0) and not holding and not foes.is_empty():
		for sid in u.all_actions():
			var sk: Dictionary = u.skill(sid)
			if sk["shape"] != "leap":
				continue
			if not state.skill_usable(u, sid):
				continue
			var immune := bool(sk.get("opportunity_immune", false))
			for tile in state.target_tiles(u, sid, u.pos):
				var leap_dist := _nearest_dist(tile, foes, true)
				if leap_dist >= current_dist:
					continue
				var path := Pathing.path_to(state.lightfoot_reach(u, sk, u.pos), u.pos, tile)
				var risk := 0.0
				if not immune:
					for e in state.path_reactions(u, path):
						risk += float(e["dmg"]) * float(e["hit"]) / 100.0
					# Skip suicidal 踏雪步; allow mild risk when closing in or landing with 护势.
					if risk >= float(u.hp) * 0.45:
						continue
				var leap_score := 5.5 + float(current_dist - leap_dist) * 3.5
				if leap_dist > 1:
					leap_score += 1.0 # still better than idling far away
				if not immune:
					leap_score -= risk * 0.35
					if bool(sk.get("landing_guard", false)):
						leap_score += 1.2
				if leap_score > score:
					best = {"score": leap_score, "move": u.pos, "skill": sid, "target": tile}
					score = leap_score
	# Rest / guard from the current tile so approach does not spend the AP first.
	# Do not turtle forever when we already outnumber a wounded last foe.
	var finish := foes.size() == 1 and float(foes[0].hp) <= float(foes[0].max_hp) * 0.55
	if score < 12.0 and not finish:
		var threatened := threat_count(state, u, u.pos) > 0 or current_dist <= 2
		var low_hp := float(u.hp) <= float(u.max_hp) * 0.45
		var need_qi := u.qi <= u.max_qi - 4
		for sid in ["守关式", "防御", "调息"]:
			if not u.all_actions().has(sid) or not state.skill_usable(u, sid):
				continue
			var sk: Dictionary = u.skill(sid)
			if int(sk.get("ap", 0)) > u.ap or u.qi < int(sk.get("qi", 0)):
				continue
			var support := 0.0
			if sid == "调息" and need_qi:
				support = 7.5 + float(u.max_qi - u.qi) * 0.45
			elif sid != "调息" and (threatened or low_hp) and not u.guard and not u.block:
				support = 10.0 if low_hp else 6.5
				if sid == "守关式":
					support += 1.0
			if support > score:
				best = {"score": support, "move": u.pos, "skill": sid, "target": u.pos}
				score = support
	return best


## Expected opportunity damage along the cheapest reachable path to `to`.
static func path_risk(state: BattleState, u: BattleUnit, to: Vector2i, reach: Dictionary = {}) -> float:
	if not u.use_gdd_rules or to == u.pos:
		return 0.0
	var r: Dictionary = reach if not reach.is_empty() else state.reachable_for(u)
	if not (r.get("ends", []) as Array).has(to):
		return 0.0
	var path := Pathing.path_to(r, u.pos, to)
	var expected := 0.0
	for e in state.path_reactions(u, path):
		var p := float(e["hit"]) / 100.0
		var dmg := mini(int(e["dmg"]), u.hp)
		expected += float(dmg) * p
		if int(e["dmg"]) >= u.hp:
			expected += 50.0 * p
	return expected


static func _candidate_targets(state: BattleState, u: BattleUnit, sk: Dictionary, from: Vector2i) -> Array:
	var out := []
	var reach: int = int(sk["rmax"]) + (Combat.RANGE_BONUS_CAP if sk["height_range"] else 0) + (1 if sk["shape"] == "area1" else 0)
	var wants_ally: bool = sk["kind"] == "heal"
	var near_unit := false
	for o in state.units:
		if not o.alive() or (o.team == u.team) != wants_ally:
			continue
		if (Pathing.chebyshev(o.pos, from) if u.use_gdd_rules else Pathing.manhattan(o.pos, from)) <= reach:
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
		var d := _nearest_dist(p, foes, u.use_gdd_rules)
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
	if not u.use_gdd_rules:
		return pick
	# Prefer a same-distance, lower-risk approach when the greedy path exits ZoC for nothing.
	var best_d := _nearest_dist(pick, foes, true)
	var best_risk := path_risk(state, u, pick, reach)
	var best_cost: int = int(reach["cost"].get(pick, 0))
	for tile in ends:
		var d := _nearest_dist(tile, foes, true)
		if d > best_d:
			continue
		var risk := path_risk(state, u, tile, reach)
		var cost: int = int(reach["cost"][tile])
		var better := false
		if d < best_d:
			better = risk < float(u.hp) # never prefer a closer lethal exit
		elif risk + 0.01 < best_risk or (absf(risk - best_risk) < 0.01 and cost < best_cost):
			better = true
		if better:
			pick = tile
			best_d = d
			best_risk = risk
			best_cost = cost
	# If every approach is lethal from opportunity, stay put.
	if best_risk >= float(u.hp) and pick != u.pos:
		return u.pos
	return pick


## Rough count of opponents that could strike `tile` on their next turn.
static func threat_count(state: BattleState, u: BattleUnit, tile: Vector2i) -> int:
	var n := 0
	for f in state.units:
		if not f.alive() or f.team == u.team:
			continue
		var r := 0
		for sid in f.all_actions():
			var sk: Dictionary = f.skill(sid)
			if sk["kind"] == "phys" or sk["kind"] == "mag":
				r = maxi(r, int(sk["rmax"]))
		var dist := Pathing.chebyshev(f.pos, tile) if u.use_gdd_rules else Pathing.manhattan(f.pos, tile)
		var reach: int = (f.max_ap if f.use_gdd_rules else f.mov) + r
		if dist <= reach:
			n += 1
	return n


static func _nearest_dist(p: Vector2i, foes: Array, gdd := false) -> int:
	var best := 1 << 30
	for f in foes:
		best = mini(best, Pathing.chebyshev(p, f.pos) if gdd else Pathing.manhattan(p, f.pos))
	return best

## B2 pickup+evacuate, and B3 ledger once the leader is down.
static func _gdd_mission(state: BattleState, u: BattleUnit, reach: Dictionary, best: Dictionary) -> Dictionary:
	if u.team != BattleUnit.PLAYER:
		return best
	if state.win_type == "leader_pickup":
		if not state.leader_fallen():
			return best
		return _pickup_bias(state, u, reach, best, 46.0, false)
	if state.win_type != "pickup_evacuate":
		return best
	return _pickup_bias(state, u, reach, best, 28.0, true)


static func _pickup_bias(state: BattleState, u: BattleUnit, reach: Dictionary, best: Dictionary, take_score: float, need_exit: bool) -> Dictionary:
	var score := float(best["score"])
	var ends: Array = reach.get("ends", [u.pos])
	var cost: Dictionary = reach.get("cost", {})
	if not state.chest_taken():
		var chest: Vector2i = state.mission_chest()
		var pickup_ap := int(state.mission.get("pickup_ap", 2))
		var saw_adjacent := false
		# Already adjacent with enough leftover AP after standing still / moving here.
		for tile in ends:
			var spent := int(cost.get(tile, 0 if tile == u.pos else 999))
			if spent > u.ap:
				continue
			var d: Vector2i = tile - chest
			if maxi(absi(d.x), absi(d.y)) != 1:
				continue
			saw_adjacent = true
			if u.ap - spent < pickup_ap:
				# Move adjacent this turn; pick up next action.
				var approach := 14.0 - float(spent) * 0.2
				if approach > score and best.get("skill", "") == "":
					best = {"score": approach, "move": tile, "skill": "", "target": Vector2i(-1, -1)}
					score = approach
				continue
			var pick_score := take_score - float(spent) * 0.15
			if pick_score > score:
				best = {"score": pick_score, "move": tile, "skill": "__take_chest__", "target": tile}
				score = pick_score
		# A wiped field used to idle forever if the chest was more than one move away.
		if not saw_adjacent and state.living(1 - u.team).is_empty():
			var best_tile := u.pos
			var best_d := absi(u.pos.x - chest.x) + absi(u.pos.y - chest.y)
			for tile in ends:
				var step := absi(tile.x - chest.x) + absi(tile.y - chest.y)
				if step < best_d:
					best_d = step
					best_tile = tile
			var chase := 24.0 - float(best_d) * 0.2
			if best_tile != u.pos and chase > score:
				best = {"score": chase, "move": best_tile, "skill": "", "target": Vector2i(-1, -1)}
	elif need_exit:
		var exit_tile: Vector2i = state.mission_exit()
		if ends.has(exit_tile):
			var spent := int(cost.get(exit_tile, 0 if exit_tile == u.pos else 999))
			var evacuate := 40.0 - float(spent) * 0.1
			if evacuate > score:
				best = {"score": evacuate, "move": exit_tile, "skill": "", "target": Vector2i(-1, -1)}
		else:
			# Closest reachable tile toward the exit.
			var best_tile = best["move"]
			var best_d := 999
			for tile in ends:
				var d := absi(tile.x - exit_tile.x) + absi(tile.y - exit_tile.y)
				if d < best_d:
					best_d = d
					best_tile = tile
			var chase := 18.0 - float(best_d) * 1.5
			if chase > score and best.get("skill", "") == "":
				best = {"score": chase, "move": best_tile, "skill": "", "target": Vector2i(-1, -1)}
	return best

