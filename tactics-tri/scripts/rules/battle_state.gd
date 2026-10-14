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
var turn_count := 0
var always_hit := false  # tests


func setup(p_map: BattleMap, p_units: Array, p_win_type := "all", seed := 1) -> void:
	map = p_map
	units = p_units
	win_type = p_win_type
	rng.seed = seed
	order = TurnOrder.new()
	for u in units:
		order.add(u.id, u.spd)


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
		u.bonus_move = 0
		u.gain_tp(1)
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
		return {"unit": u, "events": events}
	return {"unit": null, "events": events}


func end_turn(facing: int) -> void:
	var u := current()
	if u == null:
		return
	u.facing = facing
	order.end_turn(u.id, TurnOrder.cost_for(moved, acted))
	current_id = -1


func turn_preview(n := 8) -> Array:
	return order.preview(n, current_id)


# ------------------------------------------------------------------ movement

func reachable_for(u: BattleUnit) -> Dictionary:
	return Pathing.search(map, u, units, u.mov + u.bonus_move)


func can_move(u: BattleUnit) -> bool:
	return u.id == current_id and not moved


func move_unit(u: BattleUnit, to: Vector2i) -> Array:
	if to == u.pos:
		moved = true
		return [u.pos]
	var r := reachable_for(u)
	if not (r["ends"] as Array).has(to):
		return []
	var path := Pathing.path_to(r, u.pos, to)
	if path.size() >= 2:
		u.facing = Combat.dir_toward(path[path.size() - 2], path[path.size() - 1], u.facing)
	u.pos = to
	moved = true
	return path


func can_undo_move() -> bool:
	return moved and not acted


func undo_move() -> void:
	var u := current()
	if u == null or not can_undo_move():
		return
	u.pos = move_origin
	u.facing = origin_facing
	moved = false


# ------------------------------------------------------------------ actions

func skill_usable(u: BattleUnit, sid: String) -> bool:
	var sk := SkillDB.get_skill(sid)
	return u.tp >= int(sk["tp"])


func target_tiles(u: BattleUnit, sid: String, from: Vector2i) -> Array:
	var sk := SkillDB.get_skill(sid)
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
	if sk["kind"] == "self":
		return []
	var out := []
	for p in Combat.affected_tiles(sk, from, tile):
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
		if sk["kind"] == "phys" and PINCER_SHAPES.has(sk["shape"]) and p == tile:
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
	var sk := SkillDB.get_skill(sid)
	if sk["kind"] == "self":
		return true
	if not Combat.can_target(map, sk, u.pos, tile):
		return false
	if not preview(u, sid, tile).is_empty():
		return true
	return sk["effect"] == "fire" or sk["effect"] == "ice"


func _roll(hit: int) -> bool:
	return always_hit or rng.randi_range(1, 100) <= hit


func execute(u: BattleUnit, sid: String, tile: Vector2i) -> Array:
	var sk := SkillDB.get_skill(sid)
	var events := []
	u.tp -= int(sk["tp"])
	acted = true
	if sk["kind"] == "self":
		match sk["effect"]:
			"guard":
				u.guard = true
				events.append({"type": "buff", "unit": u, "text": "守势"})
			"dash":
				u.bonus_move += DASH_MOVE
				moved = false
				move_origin = u.pos
				events.append({"type": "buff", "unit": u, "text": "疾风"})
		return events
	var from := u.pos
	if tile != from:
		u.facing = Combat.dir_toward(from, tile, u.facing)
	var entries := preview(u, sid, tile, from)
	for e in entries:
		var t: BattleUnit = e["unit"]
		if e["heal"]:
			events.append({"type": "heal", "unit": t, "by": u, "amount": t.heal(e["dmg"])})
			continue
		if not _roll(e["hit"]):
			events.append({"type": "miss", "unit": t, "by": u})
			continue
		var dealt := t.take_damage(e["dmg"])
		events.append({"type": "damage", "unit": t, "by": u, "amount": dealt, "side": e["side"], "killed": not t.alive()})
		if not t.alive():
			order.remove(t.id)
			continue
		match sk["effect"]:
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
		if t.alive() and e.has("pincer"):
			events.append_array(_pincer(e["pincer"], t))
	if sk["effect"] == "fire" or sk["effect"] == "ice":
		var changed := []
		for p in Combat.affected_tiles(sk, from, tile):
			if map.apply_effect(p, sk["effect"]):
				changed.append(p)
		events.append({"type": "terrain", "tiles": changed, "effect": sk["effect"]})
	return events


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
	var blocked := not map.is_passable(dest) or unit_at(dest) != null or map.get_h(dest) > map.get_h(t.pos)
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
