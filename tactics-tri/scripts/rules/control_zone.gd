class_name ControlZone
extends RefCounted
## Pure five-cell geometry and reaction eligibility. Resolution belongs to BattleState.


static func cells(u: BattleUnit, map: BattleMap) -> Array:
	var out := []
	if not u.alive() or not SkillDB.has_skill(u.basic):
		return out
	for offset in range(-2, 3):
		var p: Vector2i = u.pos + BattleMap.DIRS[posmod(u.facing + offset, 8)]
		if map.is_passable(p) and not Pathing.closed_corner(map, u.pos, p):
			out.append(p)
	return out


static func can_react(source: BattleUnit, target: BattleUnit, map: BattleMap, target_pos: Vector2i) -> bool:
	return source != target and source.team != target.team and source.alive() and target.alive() and source.rp > 0 and cells(source, map).has(target_pos) and Combat.can_target(map, SkillDB.get_skill(source.basic), source.pos, target_pos)


static func leaving_sources(mover: BattleUnit, from: Vector2i, to: Vector2i, units: Array, map: BattleMap) -> Array:
	var out := []
	for source in units:
		if can_react(source, mover, map, from) and not cells(source, map).has(to):
			out.append(source)
	out.sort_custom(func(a: BattleUnit, b: BattleUnit): return a.spd > b.spd if a.spd != b.spd else a.id < b.id)
	return out
