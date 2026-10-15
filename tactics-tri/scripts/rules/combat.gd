class_name Combat
extends RefCounted
## Damage / hit / range formulas. All functions are static and side-effect free.

const SIDE_DMG := 0.2
const BACK_DMG := 0.5
const SIDE_HIT := 10
const BACK_HIT := 30
const HEIGHT_DMG_STEP := 0.1  # per height level of difference
const HEIGHT_DMG_CAP := 3     # levels counted at most (so ±30%)
const HEIGHT_HIT_STEP := 3
const RANGE_BONUS_CAP := 2    # ranged: +1 range per 2 height above target, at most +2
const MELEE_REACH := 2        # melee attacks cannot reach targets more than 2 levels apart
const BASE_HIT := 90
const DEF_FACTOR := 0.5


## Which side of the target the attack comes from: "front", "side" or "back".
static func relative_side(target_pos: Vector2i, target_facing: int, attacker_pos: Vector2i) -> String:
	var delta := posmod(dir_toward(target_pos, attacker_pos, target_facing) - target_facing, 8)
	if delta <= 1 or delta == 7:
		return "front"
	if delta >= 3 and delta <= 5:
		return "back"
	return "side"


static func height_mod(dh: int) -> float:
	return clampi(dh, -HEIGHT_DMG_CAP, HEIGHT_DMG_CAP) * HEIGHT_DMG_STEP


static func range_bonus(dh: int) -> int:
	if dh <= 0:
		return 0
	return mini(dh / 2, RANGE_BONUS_CAP)


static func max_range(skill: Dictionary, dh: int) -> int:
	var r: int = skill["rmax"]
	if skill["height_range"]:
		r += range_bonus(dh)
	return r


static func dir_toward(from: Vector2i, to: Vector2i, fallback := 4) -> int:
	var d := to - from
	if d == Vector2i.ZERO:
		return fallback
	return posmod(roundi(Vector2(d).angle() / (PI / 4.0)) + 2, 8)


static func can_target(map: BattleMap, skill: Dictionary, from: Vector2i, tile: Vector2i) -> bool:
	if not map.in_bounds(tile):
		return false
	var shape: String = skill["shape"]
	if shape == "self":
		return tile == from
	if bool(skill.get("gdd", false)):
		var dist8 := Pathing.chebyshev(from, tile)
		if dist8 < int(skill["rmin"]) or dist8 > int(skill["rmax"]):
			return false
		if shape == "leap":
			return true  # landing/path/occupancy checked by BattleState
		var d := tile - from
		if shape == "line" and d.x != 0 and d.y != 0 and absi(d.x) != absi(d.y):
			return false
		var step := Vector2i(signi(d.x), signi(d.y))
		var prev := from
		for i in range(1, dist8 + 1):
			var p := from + step * i
			if not map.is_passable(p) or Pathing.closed_corner(map, prev, p):
				return false
			prev = p
		return true
	var dist := Pathing.manhattan(from, tile)
	var dh := map.get_h(from) - map.get_h(tile)
	if shape == "line2" or shape == "line3":
		return dist == 1 and absi(dh) <= MELEE_REACH
	if dist < int(skill["rmin"]) or dist > max_range(skill, dh):
		return false
	if int(skill["rmax"]) == 1 and skill["kind"] != "heal" and absi(dh) > MELEE_REACH:
		return false
	return true


static func affected_tiles(skill: Dictionary, from: Vector2i, tile: Vector2i, map: BattleMap = null) -> Array:
	match skill["shape"]:
		"self":
			return [from]
		"arc3":
			if from == tile:
				return []
			var facing := dir_toward(from, tile)
			var out := []
			for offset in [-1, 0, 1]:
				var p: Vector2i = from + BattleMap.DIRS[posmod(facing + offset, 8)]
				if map == null or can_target(map, skill, from, p):
					out.append(p)
			return out
		"line":
			var step := Vector2i(signi(tile.x - from.x), signi(tile.y - from.y))
			if step == Vector2i.ZERO:
				return []
			var out := []
			var prev := from
			for i in range(1, int(skill["rmax"]) + 1):
				var p := from + step * i
				if map != null and (not map.is_passable(p) or Pathing.closed_corner(map, prev, p)):
					break
				out.append(p)
				prev = p
			return out
		"line2", "line3":
			var n := 2 if skill["shape"] == "line2" else 3
			var dir := tile - from
			var out := []
			for i in range(1, n + 1):
				out.append(from + dir * i)
			return out
		"area1":
			var out2 := [tile]
			# Classic AoE stays a plus-shape (orthogonal only), even though move uses 8 dirs.
			for d in [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]:
				out2.append(tile + d)
			return out2
	return [tile]


## Full preview of one hit. Returns dmg, hit (0-100), side, mult, labels (Chinese tags) and heal flag.
static func calc(att: BattleUnit, tgt: BattleUnit, skill: Dictionary, map: BattleMap, from: Vector2i) -> Dictionary:
	if att.use_gdd_rules:
		return gdd_calc(att, tgt, skill, map, from)
	var kind: String = skill["kind"]
	var power: float = skill["power"]
	var res := {"dmg": 0, "hit": 100, "side": "front", "labels": [], "heal": false, "mult": 1.0}
	if kind == "heal":
		res["heal"] = true
		res["dmg"] = roundi(att.mag * power + 4)
		return res
	var dh := map.get_h(from) - map.get_h(tgt.pos)
	var side := relative_side(tgt.pos, tgt.facing, from)
	res["side"] = side
	var labels: Array = res["labels"]
	var mult := 1.0
	var hit_mod := 0
	if side == "back":
		mult += BACK_DMG
		hit_mod += BACK_HIT
		labels.append("背后 +%d%%" % roundi(BACK_DMG * 100))
	elif side == "side":
		mult += SIDE_DMG
		hit_mod += SIDE_HIT
		labels.append("侧面 +%d%%" % roundi(SIDE_DMG * 100))
	var hm := height_mod(dh)
	if hm > 0.0:
		labels.append("高低差 +%d%%" % roundi(hm * 100))
	elif hm < 0.0:
		labels.append("高低差 -%d%%" % roundi(-hm * 100))
	mult += hm
	if tgt.guard:
		mult *= 0.5
		labels.append("守势 -50%")
	var a_stat := att.atk if kind == "phys" else att.mag
	var d_stat := tgt.def if kind == "phys" else tgt.res
	var raw := maxf(1.0, a_stat * power - d_stat * DEF_FACTOR)
	res["mult"] = mult
	res["dmg"] = maxi(1, roundi(raw * mult))
	if kind == "mag":
		res["hit"] = 100
	else:
		var hit := BASE_HIT + int(skill["hit_bonus"]) - tgt.eva - map.evasion(tgt.pos) + hit_mod
		hit += clampi(dh, -HEIGHT_DMG_CAP, HEIGHT_DMG_CAP) * HEIGHT_HIT_STEP
		res["hit"] = clampi(hit, 5, 100)
	return res


## B1 data gives weapon/skill power plus the unit's strength. No side damage multiplier.
static func gdd_calc(att: BattleUnit, tgt: BattleUnit, skill: Dictionary, map: BattleMap, from: Vector2i, reaction := false) -> Dictionary:
	var side := relative_side(tgt.pos, tgt.facing, from)
	var side_hit := 10 if side == "back" else (5 if side == "side" else 0)
	var hit_parts := {"base": int(skill.get("base_hit", 90)), "accuracy": att.acc, "evasion": -tgt.eva,
		"side": side_hit, "terrain": -map.evasion(tgt.pos), "reaction": -10 if reaction else 0}
	var hit := int(hit_parts["base"]) + att.acc - tgt.eva - map.evasion(tgt.pos) + side_hit
	if reaction:
		hit -= 10
	var armor := maxi(0, tgt.def + (2 if tgt.block else 0) - int(skill.get("pierce", 0)))
	var power := att.atk + int(skill["power"])
	var damage := maxi(1, power - armor)
	if tgt.guard:
		damage = maxi(1, floori(damage * 0.75))
	var labels := []
	if side_hit > 0:
		labels.append(("背后" if side == "back" else "侧面") + " 命中+%d%%" % side_hit)
	if tgt.guard:
		labels.append("护势 -25%（一击）")
	if tgt.block:
		labels.append("格挡 护甲+2（一击）")
	return {"dmg": damage, "hit": clampi(hit, 10, 95), "hit_parts": hit_parts, "side": side, "labels": labels, "heal": false, "mult": 0.75 if tgt.guard else 1.0}
