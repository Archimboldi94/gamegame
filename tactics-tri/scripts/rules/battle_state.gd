class_name BattleState
extends RefCounted
## Complete battle simulation without any scene dependency. The battle scene only renders
## what this object reports, and the AI / tests drive it directly.

const FROST_DELAY := 25
const KNOCK_COLLIDE_DMG := 8
const FALL_DMG_PER_LEVEL := 5
const STEAL_TP := 2
const DASH_MOVE := 2
const PINCER_SHAPES := ["single", "line2", "line3"]
const NO_TARGET := Vector2i(-999, -999)

var map: BattleMap
var units: Array = []
var order := TurnOrder.new()
var rng := RandomNumberGenerator.new()
var win_type := "all"  # "all" = defeat every enemy, "leader" = defeat the enemy leader
var current_id := -1
var moved := false
var acted := false
var move_origin := Vector2i.ZERO
var origin_facing := 2
var last_target := NO_TARGET  # tile of the last attack/skill aimed away from the actor this turn
var turn_count := 0
var always_hit := false  # tests
var gdd_mode := false
var last_round_number := 0


func setup(p_map: BattleMap, p_units: Array, p_win_type := "all", seed := 1) -> void:
	map = p_map
	units = p_units
	win_type = p_win_type
	rng.seed = seed
	order = TurnOrder.new()
	gdd_mode = false
	for u in units:
		if u.use_gdd_rules:
			gdd_mode = true
		order.add(u.id, u.spd)
	if gdd_mode:
		order.use_rounds = true
		last_round_number = 0


func add_unit(u: BattleUnit) -> void:
	units.append(u)
	order.add(u.id, u.spd)


func unit_by_id(id: int) -> BattleUnit:
	for u in units:
		if u.id == id:
			return u
	return null


func unit_at(p: Vector2i) -> BattleUnit:
	for u in units:
		if u.alive() and u.pos == p:
			return u
	return null


func living(team: int) -> Array:
	var out := []
	for u in units:
		if u.team == team and u.alive():
			out.append(u)
	return out


func current() -> BattleUnit:
	return unit_by_id(current_id)


# ------------------------------------------------------------------ turns

## Advances the timeline to the next living unit and starts its turn (TP +1, guard reset,
## burning ground damage). Returns {"unit": BattleUnit or null, "events": [...]}.
func begin_next_turn() -> Dictionary:
	var events := []
	while true:
		var id := order.next_actor()
		if id < 0:
			return {"unit": null, "events": events}
		var u := unit_by_id(id)
		if u == null or not u.alive():
			order.remove(id)
			continue
		turn_count += 1
		map.tick_effects()
		u.guard = false
		u.block = false
		u.bonus_move = 0
		u.gain_tp(1)
		if gdd_mode:
			if order.round_number != last_round_number:
				last_round_number = order.round_number
				for other in units:
					if other.alive():
						other.rp = 1
			u.qi_blocked = u.ap_penalty > 0
			u.ap = maxi(0, u.max_ap - mini(2, u.ap_penalty))
			u.ap_penalty = 0
			u.qi = mini(u.max_qi, u.qi + 1 + int(SkillDB.get_inner(u.inner).get("start_qi", 0)))
			u.used_skills.clear()
		if map.effect_at(u.pos) == "fire":
			var burn := u.take_damage(maxi(3, u.max_hp / 10))
			events.append({"type": "burn", "unit": u, "amount": burn, "killed": not u.alive()})
			if not u.alive():
				order.remove(id)
				if outcome() != "":
					return {"unit": null, "events": events}
				continue
		current_id = id
		moved = false
		acted = false
		move_origin = u.pos
		origin_facing = u.facing
		last_target = NO_TARGET
		return {"unit": u, "events": events}
	return {"unit": null, "events": events}


## Facing the unit will keep after its turn: toward the last attack/skill target if there was one,
## otherwise whatever its last movement step left it with.
func auto_facing(u: BattleUnit) -> int:
	if last_target != NO_TARGET and last_target != u.pos:
		return Combat.dir_toward(u.pos, last_target, u.facing)
	return u.facing


## Ends the current unit's turn. There is no facing choice: the unit auto-faces (see auto_facing).
func end_turn() -> void:
	var u := current()
	if u == null:
		return
	if u.use_gdd_rules:
		var inner := SkillDB.get_inner(u.inner)
		if u.alive() and inner.has("end_guard_ap") and u.ap >= int(inner["end_guard_ap"]) and not u.used_skills.get("inner_end", false):
			u.gain_guard()
			u.used_skills["inner_end"] = true
		u.qi_blocked = false
	u.facing = auto_facing(u)
	order.end_turn(u.id, TurnOrder.cost_for(moved, acted))
	current_id = -1


func turn_preview(n := 8) -> Array:
	return order.preview(n, current_id)


# ------------------------------------------------------------------ movement

func reachable_for(u: BattleUnit) -> Dictionary:
	var budget := u.ap if u.use_gdd_rules else (u.mov + u.bonus_move)
	return Pathing.search(map, u, units, budget)


func can_move(u: BattleUnit) -> bool:
	if u.id != current_id:
		return false
	if u.use_gdd_rules:
		return u.ap > 0
	return not moved


func move_unit(u: BattleUnit, to: Vector2i) -> Array:
	if to == u.pos:
		moved = true
		return [u.pos]
	var r := reachable_for(u)
	if not (r["ends"] as Array).has(to):
		return []
	var path := Pathing.path_to(r, u.pos, to)
	var events: Array = []
	if u.use_gdd_rules:
		# Stepwise AP spend + opportunity attacks (at most one reactor per step).
		for i in range(1, path.size()):
			var from: Vector2i = path[i - 1]
			var step_to: Vector2i = path[i]
			var step_cost := Pathing.enter_cost(map, u.jump, from, step_to, u.flying)
			if step_cost < 0 or u.ap < step_cost:
				path = path.slice(0, i)
				break
			u.ap -= step_cost
			var reactors := ControlZone.leaving_sources(u, from, step_to, units, map)
			if not reactors.is_empty():
				events.append_array(_resolve_reaction(reactors[0], u, true))
			if not u.alive():
				path = path.slice(0, i)  # died before leaving
				break
			u.pos = step_to
			u.facing = Combat.dir_toward(from, step_to, u.facing)
		moved = true
		u.facing = auto_facing(u)
		return path
	if path.size() >= 2:
		u.facing = Combat.dir_toward(path[path.size() - 2], path[path.size() - 1], u.facing)
	u.pos = to
	moved = true
	u.facing = auto_facing(u)
	return path


func can_undo_move() -> bool:
	if gdd_mode:
		return false  # AP spent / reactions make undo unsafe in Phase A
	return moved and not acted


## Read-only path risk, sharing geometry and reactor priority with actual movement.
## A reactor can spend its RP only once across the entire path.
func path_reactions(u: BattleUnit, path: Array, immune := false, initial_facing := -1) -> Array:
	var out := []
	var spent := {}
	if not u.use_gdd_rules or immune:
		return out
	for i in range(1, path.size()):
		var sources := ControlZone.leaving_sources(u, path[i - 1], path[i], units, map)
		for source in sources:
			if spent.has(source.id):
				continue
			spent[source.id] = true
			# The mover faces the preceding step when the reaction happens.
			var subject := BattleUnit.new()
			subject.pos = path[i - 1]
			subject.facing = (u.facing if initial_facing < 0 else initial_facing) if i == 1 else Combat.dir_toward(path[i - 2], path[i - 1])
			subject.def = u.def
			subject.eva = u.eva
			subject.guard = u.guard
			subject.block = u.block
			var e := Combat.gdd_calc(source, subject, SkillDB.get_skill(source.basic), map, source.pos, true)
			e.merge({"source": source, "from": path[i - 1], "to": path[i], "step": i})
			out.append(e)
			break
	return out


## Auto-counter eligibility on hit/miss, including knockback and free retreat.
## All values are conditional on surviving any preceding reactions.
func counter_preview(u: BattleUnit, sid: String, target: BattleUnit) -> Dictionary:
	var sk := SkillDB.get_skill(sid)
	if not u.use_gdd_rules or sk["shape"] != "single" or not ControlZone.can_react(target, u, map, u.pos):
		return {}
	var attack := Combat.calc(u, target, sk, map, u.pos)
	var branches := []
	var forecast := {}
	for landed in [true, false]:
		if landed and int(attack["dmg"]) >= target.hp:
			continue
		var defender := BattleUnit.new()
		defender.pos = target.pos
		defender.facing = target.facing
		defender.team = target.team
		defender.basic = target.basic
		defender.atk = target.atk
		defender.acc = target.acc
		var subject := BattleUnit.new()
		subject.pos = u.pos
		subject.facing = Combat.dir_toward(u.pos, target.pos, u.facing)
		subject.team = u.team
		subject.def = u.def
		subject.eva = u.eva
		subject.guard = u.guard
		subject.block = u.block
		if landed and sk.get("effect") == "wuxia_push":
			var dest := target.pos + Vector2i(signi(target.pos.x - u.pos.x), signi(target.pos.y - u.pos.y))
			if Pathing.enter_cost(map, target.jump, target.pos, dest, target.flying) >= 0 and unit_at(dest) == null:
				defender.pos = dest
		if sk.get("effect") == "retreat":
			var path := retreat_path(u, target.pos)
			if not path.is_empty():
				var dest: Vector2i = path[1]
				var sources := ControlZone.leaving_sources(u, u.pos, dest, units, map)
				if not bool(sk.get("retreat_safe", false)) and not sources.is_empty() and sources[0] == target:
					continue  # target spent its RP on retreat's opportunity attack
				subject.pos = dest
		if not ControlZone.can_react(defender, subject, map, subject.pos):
			continue
		branches.append("命中后" if landed else "落空后")
		forecast = Combat.gdd_calc(defender, subject, SkillDB.get_skill(target.basic), map, defender.pos, true)
	if not branches.is_empty():
		forecast["condition"] = "双方存活时" if branches.size() == 2 else branches[0] + "且双方存活时"
	return forecast


func undo_move() -> void:
	var u := current()
	if u == null or not can_undo_move():
		return
	u.pos = move_origin
	u.facing = origin_facing
	moved = false


# ------------------------------------------------------------------ actions

func skill_usable(u: BattleUnit, sid: String) -> bool:
	if not SkillDB.has_skill(sid):
		return false
	var sk := SkillDB.get_skill(sid)
	if u.use_gdd_rules:
		if not u.alive() or not u.all_actions().has(sid):
			return false
		if bool(sk.get("once", false)) and u.used_skills.get(sid, false):
			return false
		return u.ap >= int(sk.get("ap", 0)) and u.qi >= int(sk.get("qi", 0))
	return u.tp >= int(sk["tp"])


func target_tiles(u: BattleUnit, sid: String, from: Vector2i) -> Array:
	var sk := SkillDB.get_skill(sid)
	if sk["shape"] == "leap":
		return lightfoot_reach(u, sk, from)["ends"]
	if sk["shape"] == "self":
		return [from]
	var out := []
	var reach: int = int(sk["rmax"]) + (Combat.RANGE_BONUS_CAP if sk["height_range"] else 0)
	for y in range(from.y - reach, from.y + reach + 1):
		for x in range(from.x - reach, from.x + reach + 1):
			var p := Vector2i(x, y)
			if Combat.can_target(map, sk, from, p):
				out.append(p)
	return out


func lightfoot_reach(u: BattleUnit, sk: Dictionary, from: Vector2i) -> Dictionary:
	return Pathing.lightfoot_search(map, u, units, from, int(sk["rmax"]), bool(sk.get("cross_low", false)))


func pincer_partner(att: BattleUnit, tgt: BattleUnit, from: Vector2i) -> BattleUnit:
	var d := tgt.pos - from
	if d == Vector2i.ZERO or (d.x != 0 and d.y != 0):
		return null
	var step := Vector2i(signi(d.x), signi(d.y))
	var b := unit_at(tgt.pos + step)
	if b != null and b != att and b.team == att.team:
		return b
	return null


## One entry per affected unit: Combat.calc result + "unit" (+ "pincer", "pincer_dmg", "pincer_hit").
func preview(u: BattleUnit, sid: String, tile: Vector2i, from := Vector2i(-999, -999)) -> Array:
	if from == Vector2i(-999, -999):
		from = u.pos
	var sk := SkillDB.get_skill(sid)
	if sk["kind"] == "self" or sk["shape"] == "leap":
		return []
	var out := []
	for p in Combat.affected_tiles(sk, from, tile, map):
		var t := unit_at(p)
		if t == u and p != from:
			t = null
		if p == from and t == null:
			t = u
		if t == null or (t == u and sk["kind"] != "heal"):
			continue
		if sk["kind"] == "heal":
			if t.team != u.team:
				continue
		elif t.team == u.team:
			continue
		var e := Combat.calc(u, t, sk, map, from)
		e["unit"] = t
		if not u.use_gdd_rules and sk["kind"] == "phys" and PINCER_SHAPES.has(sk["shape"]) and p == tile:
			var partner := pincer_partner(u, t, from)
			if partner != null:
				var fsk := SkillDB.get_skill(partner.basic)
				var f := Combat.calc(partner, t, fsk, map, partner.pos)
				e["pincer"] = partner
				e["pincer_dmg"] = f["dmg"]
				e["pincer_hit"] = f["hit"]
				(e["labels"] as Array).append("夹击：%s追击" % partner.name)
		out.append(e)
	return out


func is_valid_target(u: BattleUnit, sid: String, tile: Vector2i) -> bool:
	if u.use_gdd_rules and not skill_usable(u, sid):
		return false
	var sk := SkillDB.get_skill(sid)
	if sk["shape"] == "leap":
		return (lightfoot_reach(u, sk, u.pos)["ends"] as Array).has(tile)
	if sk["kind"] == "self":
		return tile == u.pos
	if not Combat.can_target(map, sk, u.pos, tile):
		return false
	if not preview(u, sid, tile).is_empty():
		return true
	return sk["effect"] == "fire" or sk["effect"] == "ice"


func _roll(hit: int) -> bool:
	return always_hit or rng.randi_range(1, 100) <= hit


func execute(u: BattleUnit, sid: String, tile: Vector2i) -> Array:
	# Validate everything before mutating resources, usage limits, facing or turn flags.
	if u.use_gdd_rules and (not skill_usable(u, sid) or not is_valid_target(u, sid, tile)):
		return []
	var sk := SkillDB.get_skill(sid)
	var events := []
	if u.use_gdd_rules:
		u.ap -= int(sk.get("ap", 0))
		u.qi -= int(sk.get("qi", 0))
		if bool(sk.get("once", false)):
			u.used_skills[sid] = true
	else:
		u.tp -= int(sk["tp"])
	acted = true
	if sk["kind"] == "self" or sk.get("shape") == "leap":
		match sk.get("effect", ""):
			"guard":
				if u.use_gdd_rules:
					u.gain_block()
				else:
					u.gain_guard()
				events.append({"type": "buff", "unit": u, "text": "格挡" if u.use_gdd_rules else "守势"})
			"shield":
				u.gain_guard()
				events.append({"type": "buff", "unit": u, "text": "护势"})
			"rest":
				u.qi = mini(u.max_qi, u.qi + 4)
				events.append({"type": "buff", "unit": u, "text": "调息 +4内力"})
			"dash":
				u.bonus_move += DASH_MOVE
				moved = false
				move_origin = u.pos
				origin_facing = u.facing
				events.append({"type": "buff", "unit": u, "text": "疾风"})
			"leap":
				var path := Pathing.path_to(lightfoot_reach(u, sk, u.pos), u.pos, tile)
				for i in range(1, path.size()):
					var old := u.pos
					var dest: Vector2i = path[i]
					if not bool(sk.get("opportunity_immune", false)):
						var reactors := ControlZone.leaving_sources(u, old, dest, units, map)
						if not reactors.is_empty():
							events.append_array(_resolve_reaction(reactors[0], u, true))
					if not u.alive():
						break
					u.pos = dest
					u.facing = Combat.dir_toward(old, dest, u.facing)
					events.append({"type": "leap", "unit": u, "from": old, "to": dest})
				if u.alive() and u.pos == tile and bool(sk.get("landing_guard", false)):
					u.gain_guard()
					events.append({"type": "buff", "unit": u, "text": "护势"})
		return events
	var from := u.pos
	if tile != from:
		last_target = tile
		u.facing = Combat.dir_toward(from, tile, u.facing)
	var entries := preview(u, sid, tile, from)
	for e in entries:
		var t: BattleUnit = e["unit"]
		if e["heal"]:
			events.append({"type": "heal", "unit": t, "by": u, "amount": t.heal(e["dmg"])})
			continue
		if not _roll(e["hit"]):
			events.append({"type": "miss", "unit": t, "by": u})
			if sk.get("effect", "") == "retreat" and u.use_gdd_rules:
				events.append_array(_retreat(u, sk, tile))
			if u.use_gdd_rules and sk["shape"] == "single" and t.pos == tile and t.alive() and e.get("side", "") != "back" and ControlZone.can_react(t, u, map, u.pos):
				events.append_array(_resolve_reaction(t, u, false))
			continue
		var dealt := t.take_damage(e["dmg"])
		if u.use_gdd_rules:
			t.guard = false
			t.block = false
		events.append({"type": "damage", "unit": t, "by": u, "amount": dealt, "side": e["side"], "killed": not t.alive()})
		if not t.alive():
			order.remove(t.id)
			if sk.get("effect", "") == "retreat" and u.use_gdd_rules:
				events.append_array(_retreat(u, sk, tile))
			continue
		match sk.get("effect", ""):
			"steal":
				var amount := mini(STEAL_TP, t.tp)
				t.tp -= amount
				u.gain_tp(amount)
				events.append({"type": "steal", "unit": t, "by": u, "amount": amount})
			"ice":
				order.delay(t.id, FROST_DELAY)
				events.append({"type": "delay", "unit": t, "amount": FROST_DELAY})
			"knockback":
				events.append_array(_knockback(t, from))
			"wuxia_push":
				events.append_array(_wuxia_push(t, from))
			"seal":
				t.ap_penalty = 2
				events.append({"type": "buff", "unit": t, "text": "气脉受阻：下次行动 -2AP"})
			"retreat":
				events.append_array(_retreat(u, sk, tile))
		if t.alive() and e.has("pincer"):
			events.append_array(_pincer(e["pincer"], t))
		# Auto-counter after a direct single-target attack (GDD).
		if u.use_gdd_rules and sk["shape"] == "single" and t.alive() and e.get("side", "") != "back":
			if ControlZone.can_react(t, u, map, u.pos):
				events.append_array(_resolve_reaction(t, u, false))
	if sk.get("effect", "") == "fire" or sk.get("effect", "") == "ice":
		var changed := []
		for p in Combat.affected_tiles(sk, from, tile):
			if map.apply_effect(p, sk["effect"]):
				changed.append(p)
		events.append({"type": "terrain", "tiles": changed, "effect": sk["effect"]})
	return events


func _retreat(u: BattleUnit, sk: Dictionary, target: Vector2i) -> Array:
	var path := retreat_path(u, target)
	if path.is_empty():
		return []
	var dest: Vector2i = path[1]
	u.used_skills["retreat"] = true
	var events := []
	if not bool(sk.get("retreat_safe", false)):
		var reactors := ControlZone.leaving_sources(u, u.pos, dest, units, map)
		if not reactors.is_empty():
			events.append_array(_resolve_reaction(reactors[0], u, true))
	if u.alive():
		var old := u.pos
		u.pos = dest
		events.append({"type": "retreat", "unit": u, "from": old, "to": dest})
	return events


func retreat_path(u: BattleUnit, target: Vector2i) -> Array:
	if not u.alive() or u.used_skills.get("retreat", false):
		return []
	var dest := u.pos + Vector2i(signi(u.pos.x - target.x), signi(u.pos.y - target.y))
	if Pathing.enter_cost(map, u.jump, u.pos, dest, u.flying) < 0 or unit_at(dest) != null:
		return []
	return [u.pos, dest]


## GDD forced movement: eight directions, no collision or falling bonus damage, no ZoC.
func _wuxia_push(t: BattleUnit, from: Vector2i) -> Array:
	var step := Vector2i(signi(t.pos.x - from.x), signi(t.pos.y - from.y))
	var dest := t.pos + step
	if Pathing.enter_cost(map, t.jump, t.pos, dest, t.flying) < 0 or unit_at(dest) != null:
		return []
	var old := t.pos
	t.pos = dest
	return [{"type": "knockback", "unit": t, "from": old, "to": dest, "amount": 0, "killed": false}]


func _pincer(partner: BattleUnit, t: BattleUnit) -> Array:
	if not partner.alive() or not t.alive():
		return []
	var f := Combat.calc(partner, t, SkillDB.get_skill(partner.basic), map, partner.pos)
	partner.facing = Combat.dir_toward(partner.pos, t.pos, partner.facing)
	if not _roll(f["hit"]):
		return [{"type": "pincer", "unit": t, "by": partner, "amount": 0, "hit": false, "killed": false}]
	var dealt := t.take_damage(f["dmg"])
	if not t.alive():
		order.remove(t.id)
	return [{"type": "pincer", "unit": t, "by": partner, "amount": dealt, "hit": true, "killed": not t.alive()}]


func _knockback(t: BattleUnit, from: Vector2i) -> Array:
	var dir := t.pos - from
	if dir.x != 0 and dir.y != 0:
		return []
	dir = Vector2i(signi(dir.x), signi(dir.y))
	var dest := t.pos + dir
	var blocked := not map.is_passable(dest, t.flying) or unit_at(dest) != null or map.get_h(dest) > map.get_h(t.pos)
	if blocked:
		var d := t.take_damage(KNOCK_COLLIDE_DMG)
		if not t.alive():
			order.remove(t.id)
		return [{"type": "collide", "unit": t, "amount": d, "killed": not t.alive()}]
	var drop := map.get_h(t.pos) - map.get_h(dest)
	var old := t.pos
	t.pos = dest
	var ev := {"type": "knockback", "unit": t, "from": old, "to": dest, "amount": 0, "killed": false}
	if drop >= 2:
		ev["amount"] = t.take_damage((drop - 1) * FALL_DMG_PER_LEVEL)
		ev["killed"] = not t.alive()
		if not t.alive():
			order.remove(t.id)
	return [ev]



func _resolve_reaction(reactor: BattleUnit, target: BattleUnit, opportunity: bool) -> Array:
	if not ControlZone.can_react(reactor, target, map, target.pos):
		return []
	reactor.rp = 0
	var sk := SkillDB.get_skill(reactor.basic)
	var e: Dictionary
	if reactor.use_gdd_rules:
		e = Combat.gdd_calc(reactor, target, sk, map, reactor.pos, true)
	else:
		e = Combat.calc(reactor, target, sk, map, reactor.pos)
	var tag := "opportunity" if opportunity else "counter"
	if not _roll(int(e["hit"])):
		return [{"type": tag, "unit": target, "by": reactor, "amount": 0, "hit": false, "killed": false}]
	var dealt := target.take_damage(int(e["dmg"]))
	if reactor.use_gdd_rules:
		target.guard = false
		target.block = false
	if not target.alive():
		order.remove(target.id)
	return [{"type": tag, "unit": target, "by": reactor, "amount": dealt, "hit": true, "killed": not target.alive(), "side": e["side"]}]


# ------------------------------------------------------------------ outcome

func lord_alive() -> bool:
	for u in units:
		if u.is_lord and not u.alive():
			return false
	return true


func outcome() -> String:
	if not lord_alive() or living(BattleUnit.PLAYER).is_empty():
		return "lose"
	if win_type == "leader":
		for u in units:
			if u.team == BattleUnit.ENEMY and u.is_leader and not u.alive():
				return "win"
	if living(BattleUnit.ENEMY).is_empty():
		return "win"
	return ""
