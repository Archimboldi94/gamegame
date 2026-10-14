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
	var d := attacker_pos - target_pos
	var f: Vector2i = BattleUnit.DIRS[target_facing]
	var proj := d.x * f.x + d.y * f.y
	var lat := absi(d.x * f.y - d.y * f.x)
	if proj > lat:
		return "front"
	if -proj > lat:
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


static func dir_toward(from: Vector2i, to: Vector2i, fallback := 2) -> int:
	var d := to - from
	if d == Vector2i.ZERO:
		return fallback
	if absi(d.x) >= absi(d.y):
		return 1 if d.x > 0 else 3
	return 2 if d.y > 0 else 0


static func can_target(map: BattleMap, skill: Dictionary, from: Vector2i, tile: Vector2i) -> bool:
	if not map.in_bounds(tile):
		return false
	var shape: String = skill["shape"]
	if shape == "self":
		return tile == from
	var dist := Pathing.manhattan(from, tile)
	var dh := map.get_h(from) - map.get_h(tile)
	if shape == "line2" or shape == "line3":
		return dist == 1 and absi(dh) <= MELEE_REACH
	if dist < int(skill["rmin"]) or dist > max_range(skill, dh):
		return false
	if int(skill["rmax"]) == 1 and skill["kind"] != "heal" and absi(dh) > MELEE_REACH:
		return false
	return true


static func affected_tiles(skill: Dictionary, from: Vector2i, tile: Vector2i) -> Array:
	match skill["shape"]:
		"self":
			return [from]
		"line2", "line3":
			var n := 2 if skill["shape"] == "line2" else 3
			var dir := tile - from
			var out := []
			for i in range(1, n + 1):
				out.append(from + dir * i)
			return out
		"area1":
			var out2 := [tile]
			for d in BattleMap.DIRS:
				out2.append(tile + d)
			return out2
	return [tile]


## Full preview of one hit. Returns dmg, hit (0-100), side, mult, labels (Chinese tags) and heal flag.
static func calc(att: BattleUnit, tgt: BattleUnit, skill: Dictionary, map: BattleMap, from: Vector2i) -> Dictionary:
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
