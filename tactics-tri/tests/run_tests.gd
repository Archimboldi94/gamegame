extends SceneTree
## Headless rule tests:  godot --headless --path . -s tests/run_tests.gd

var passed := 0
var failed := 0
var _current := ""


func _init() -> void:
	var tests := [
		"test_climb_cost_and_jump_limit", "test_drop_limit", "test_terrain_costs_and_evasion",
		"test_allies_passable_enemies_block", "test_height_damage", "test_ranged_height_range_bonus",
		"test_melee_vertical_reach", "test_facing_sides", "test_facing_bonus_damage_and_hit",
		"test_turn_order_speed", "test_turn_order_wait_cost", "test_turn_order_preview_and_delay",
		"test_tp_gain_and_cap", "test_tp_costs", "test_pincer_follow_up", "test_pincer_requires_opposite",
		"test_lance_line_hits_two", "test_fire_and_ice_terrain", "test_steal_and_dash", "test_knockback",
		"test_vote_initial_and_tally", "test_vote_persuasion", "test_vote_tie_break",
		"test_ai_prefers_back_attack", "test_battle_defs_valid", "test_ai_full_battles", "test_outcome_rules",
	]
	for t in tests:
		_current = t
		call(t)
	print("")
	print("==== RESULT: %d PASS, %d FAIL ====" % [passed, failed])
	quit(1 if failed > 0 else 0)


func check(cond: bool, msg: String) -> void:
	if cond:
		passed += 1
	else:
		failed += 1
		print("FAIL [%s] %s" % [_current, msg])


func eq(a, b, msg: String) -> void:
	check(a == b, "%s (got %s, expected %s)" % [msg, str(a), str(b)])


# ------------------------------------------------------------ helpers

func mk(id: int, cls: String, team: int, pos: Vector2i, facing := 2) -> BattleUnit:
	return BattleUnit.create(id, "U%d" % id, cls, team, pos, facing)


func state_with(map: BattleMap, units: Array) -> BattleState:
	var s := BattleState.new()
	s.setup(map, units, "all", 3)
	s.always_hit = true
	return s


# ------------------------------------------------------------ movement / height

func test_climb_cost_and_jump_limit() -> void:
	var m := BattleMap.flat(5, 1)
	m.set_h(Vector2i(1, 0), 1)
	m.set_h(Vector2i(2, 0), 3)
	eq(Pathing.enter_cost(m, 2, Vector2i(0, 0), Vector2i(1, 0)), 2, "climb 1 level costs grass 1 + 1")
	eq(Pathing.enter_cost(m, 2, Vector2i(1, 0), Vector2i(2, 0)), 2, "climb 2 levels costs 1 + 1")
	eq(Pathing.enter_cost(m, 1, Vector2i(1, 0), Vector2i(2, 0)), -1, "climb 2 with jump 1 blocked")
	eq(Pathing.climb_extra(3), 2, "climb 3 extra = 2")
	var u := mk(0, "lancer", 0, Vector2i(0, 0))  # jump 1, mov 4
	var r := Pathing.search(m, u, [u], u.mov)
	check((r["ends"] as Array).has(Vector2i(1, 0)), "lancer reaches h1 tile")
	check(not (r["ends"] as Array).has(Vector2i(2, 0)), "lancer cannot climb onto h3 tile (dh 2 > jump 1)")
	var t := mk(1, "thief", 0, Vector2i(0, 0))  # jump 3
	var r2 := Pathing.search(m, t, [t], t.mov)
	check((r2["ends"] as Array).has(Vector2i(2, 0)), "thief (jump 3) climbs the h3 tile")
	eq(r2["cost"][Vector2i(2, 0)], 4, "thief path cost 2 + 2")


func test_drop_limit() -> void:
	var m := BattleMap.flat(2, 1)
	m.set_h(Vector2i(0, 0), 4)
	eq(Pathing.enter_cost(m, 1, Vector2i(0, 0), Vector2i(1, 0)), -1, "drop 4 with jump 1 blocked (limit jump+1)")
	eq(Pathing.enter_cost(m, 3, Vector2i(0, 0), Vector2i(1, 0)), 1, "drop 4 with jump 3 allowed and free")


func test_terrain_costs_and_evasion() -> void:
	var m := BattleMap.from_rows(["000", "000"], ["gfw", "srx"])
	eq(m.move_cost(Vector2i(0, 0)), 1, "grass cost")
	eq(m.move_cost(Vector2i(1, 0)), 2, "forest cost")
	eq(m.move_cost(Vector2i(2, 0)), 2, "water slows")
	eq(m.evasion(Vector2i(1, 0)), 15, "forest evasion")
	check(m.evasion(Vector2i(2, 0)) < 0, "water lowers evasion")
	check(not m.is_passable(Vector2i(2, 1)), "wall impassable")
	var a := mk(0, "swordsman", 0, Vector2i(0, 1), 1)
	var t1 := mk(1, "swordsman", 1, Vector2i(1, 0), 0)
	var hit_forest: int = Combat.calc(a, t1, SkillDB.get_skill("slash"), m, Vector2i(0, 0))["hit"]
	t1.pos = Vector2i(0, 0)
	t1.facing = 1
	var hit_grass: int = Combat.calc(a, t1, SkillDB.get_skill("slash"), m, Vector2i(0, 1))["hit"]
	check(hit_forest < hit_grass, "forest lowers hit chance (%d < %d)" % [hit_forest, hit_grass])


func test_allies_passable_enemies_block() -> void:
	var m := BattleMap.flat(5, 1)
	var u := mk(0, "swordsman", 0, Vector2i(0, 0))
	var ally := mk(1, "swordsman", 0, Vector2i(1, 0))
	var r := Pathing.search(m, u, [u, ally], 4)
	check((r["ends"] as Array).has(Vector2i(2, 0)), "can pass through ally")
	check(not (r["ends"] as Array).has(Vector2i(1, 0)), "cannot stop on ally")
	var foe := mk(2, "swordsman", 1, Vector2i(1, 0))
	var r2 := Pathing.search(m, u, [u, foe], 4)
	check(not r2["cost"].has(Vector2i(2, 0)), "enemy blocks passage")


func test_height_damage() -> void:
	var m := BattleMap.flat(3, 1)
	var a := mk(0, "swordsman", 0, Vector2i(0, 0), 1)
	var t := mk(1, "swordsman", 1, Vector2i(1, 0), 3)  # facing the attacker: front
	var sk := SkillDB.get_skill("slash")
	var base: int = Combat.calc(a, t, sk, m, a.pos)["dmg"]
	m.set_h(Vector2i(0, 0), 2)
	var high := Combat.calc(a, t, sk, m, a.pos)
	check(int(high["dmg"]) > base, "higher ground deals more (%d > %d)" % [high["dmg"], base])
	check((high["labels"] as Array).has("高低差 +20%"), "label 高低差 +20%")
	m.set_h(Vector2i(0, 0), 0)
	m.set_h(Vector2i(1, 0), 1)
	var low := Combat.calc(a, t, sk, m, a.pos)
	check(int(low["dmg"]) < base, "lower ground deals less")
	check((low["labels"] as Array).has("高低差 -10%"), "label 高低差 -10%")
	check(is_equal_approx(Combat.height_mod(7), 0.3), "height bonus capped at +30%")
	check(is_equal_approx(Combat.height_mod(-9), -0.3), "height penalty capped at -30%")


func test_ranged_height_range_bonus() -> void:
	eq(Combat.range_bonus(1), 0, "dh 1 no range bonus")
	eq(Combat.range_bonus(2), 1, "dh 2 => +1")
	eq(Combat.range_bonus(5), 2, "dh 5 => capped +2")
	eq(Combat.range_bonus(-3), 0, "lower => no bonus")
	var m := BattleMap.flat(8, 1)
	var sk := SkillDB.get_skill("shoot")
	check(not Combat.can_target(m, sk, Vector2i(0, 0), Vector2i(5, 0)), "flat: distance 5 out of range 4")
	m.set_h(Vector2i(0, 0), 2)
	check(Combat.can_target(m, sk, Vector2i(0, 0), Vector2i(5, 0)), "from +2 height distance 5 in range")
	check(not Combat.can_target(m, sk, Vector2i(0, 0), Vector2i(6, 0)), "from +2 height distance 6 out of range")
	m.set_h(Vector2i(0, 0), 4)
	check(Combat.can_target(m, sk, Vector2i(0, 0), Vector2i(6, 0)), "from +4 height distance 6 in range")
	m.set_h(Vector2i(0, 0), 9)
	check(not Combat.can_target(m, sk, Vector2i(0, 0), Vector2i(7, 0)), "range bonus capped at +2")
	check(not Combat.can_target(m, sk, Vector2i(0, 0), Vector2i(1, 0)), "archer min range 2")


func test_melee_vertical_reach() -> void:
	var m := BattleMap.flat(2, 1)
	m.set_h(Vector2i(1, 0), 3)
	check(not Combat.can_target(m, SkillDB.get_skill("slash"), Vector2i(0, 0), Vector2i(1, 0)), "melee cannot reach 3 levels up")
	m.set_h(Vector2i(1, 0), 2)
	check(Combat.can_target(m, SkillDB.get_skill("slash"), Vector2i(0, 0), Vector2i(1, 0)), "melee reaches 2 levels up")


# ------------------------------------------------------------ facing

func test_facing_sides() -> void:
	var t := Vector2i(5, 5)
	eq(Combat.relative_side(t, 0, Vector2i(5, 4)), "front", "facing north, attacker north => front")
	eq(Combat.relative_side(t, 0, Vector2i(5, 6)), "back", "facing north, attacker south => back")
	eq(Combat.relative_side(t, 0, Vector2i(4, 5)), "side", "facing north, attacker west => side")
	eq(Combat.relative_side(t, 1, Vector2i(3, 5)), "back", "facing east, attacker west => back")
	eq(Combat.relative_side(t, 2, Vector2i(5, 8)), "front", "facing south, ranged from south => front")
	eq(Combat.relative_side(t, 2, Vector2i(6, 6)), "side", "diagonal => side")
	eq(Combat.relative_side(t, 2, Vector2i(5, 1)), "back", "facing south, ranged from far north => back")


func test_facing_bonus_damage_and_hit() -> void:
	var m := BattleMap.flat(3, 3)
	var a := mk(0, "swordsman", 0, Vector2i(1, 2))
	var t := mk(1, "swordsman", 1, Vector2i(1, 1))
	var sk := SkillDB.get_skill("slash")
	t.facing = 2
	var front := Combat.calc(a, t, sk, m, a.pos)
	t.facing = 1
	var side := Combat.calc(a, t, sk, m, a.pos)
	t.facing = 0
	var back := Combat.calc(a, t, sk, m, a.pos)
	eq(front["side"], "front", "front detected")
	eq(side["side"], "side", "side detected")
	eq(back["side"], "back", "back detected")
	check(int(side["dmg"]) > int(front["dmg"]), "side > front damage")
	check(int(back["dmg"]) > int(side["dmg"]), "back > side damage")
	check(int(back["hit"]) > int(front["hit"]), "back attack has higher hit")
	check((back["labels"] as Array).has("背后 +50%"), "back label")
	check((side["labels"] as Array).has("侧面 +20%"), "side label")
	t.guard = true
	var guarded := Combat.calc(a, t, sk, m, a.pos)
	check(int(guarded["dmg"]) < int(back["dmg"]), "guard halves damage")


# ------------------------------------------------------------ turn order

func test_turn_order_speed() -> void:
	var o := TurnOrder.new()
	o.add(1, 10)
	o.add(2, 5)
	var counts := {1: 0, 2: 0}
	var first := o.next_actor()
	eq(first, 1, "faster unit acts first")
	o.end_turn(first, 100)
	counts[first] += 1
	for i in 29:
		var id := o.next_actor()
		counts[id] += 1
		o.end_turn(id, 100)
	eq(counts[1], 20, "speed 10 acts twice as often as speed 5 (fast)")
	eq(counts[2], 10, "speed 5 acts half as often (slow)")


func test_turn_order_wait_cost() -> void:
	eq(TurnOrder.cost_for(true, true), 100, "move+act full cost")
	eq(TurnOrder.cost_for(true, false), 80, "move only cheaper")
	eq(TurnOrder.cost_for(false, false), 60, "pure wait cheapest")
	var a := TurnOrder.new()
	a.add(1, 10)
	a.add(2, 10)
	var x := a.next_actor()
	eq(x, 1, "tie broken by id")
	a.end_turn(1, TurnOrder.cost_for(false, false))  # waits
	var y := a.next_actor()
	a.end_turn(y, 100)
	var z := a.next_actor()
	eq(z, 1, "unit that waited acts again sooner")


func test_turn_order_preview_and_delay() -> void:
	var o := TurnOrder.new()
	o.add(1, 12)
	o.add(2, 9)
	o.add(3, 6)
	var cur := o.next_actor()
	var pv := o.preview(8, cur)
	eq(pv.size(), 8, "preview has 8 entries")
	eq(pv[0], cur, "preview starts with current actor")
	eq(o.ct_of(2) < 100, true, "preview does not mutate real timeline")
	var o2 := TurnOrder.new()
	o2.add(1, 10)
	o2.add(2, 10)
	o2.delay(1, 30)
	eq(o2.next_actor(), 2, "delayed unit loses its place")


# ------------------------------------------------------------ TP

func test_tp_gain_and_cap() -> void:
	var m := BattleMap.flat(4, 4)
	var u := mk(0, "swordsman", 0, Vector2i(0, 0))
	var e := mk(1, "swordsman", 1, Vector2i(3, 3))
	var s := state_with(m, [u, e])
	u.tp = 1
	var r := s.begin_next_turn()
	eq(r["unit"], u, "swordsman first (tie by id)")
	eq(u.tp, 2, "+1 TP at start of turn")
	u.tp = 5
	s.end_turn(2)
	s.begin_next_turn()
	s.end_turn(2)
	s.begin_next_turn()
	eq(u.tp, 5, "TP capped at max 5")
	eq(u.max_tp, 5, "max TP 5")


func test_tp_costs() -> void:
	var m := BattleMap.flat(4, 4)
	var u := mk(0, "swordsman", 0, Vector2i(1, 1))
	var e := mk(1, "swordsman", 1, Vector2i(1, 2))
	var s := state_with(m, [u, e])
	s.current_id = u.id
	u.tp = 1
	check(not s.skill_usable(u, "heavy_slash"), "破军斩 needs 2 TP")
	check(s.skill_usable(u, "guard"), "不动架势 1 TP usable")
	check(s.skill_usable(u, "slash"), "basic attack costs nothing")
	u.tp = 3
	s.execute(u, "heavy_slash", e.pos)
	eq(u.tp, 1, "TP deducted by skill cost")


# ------------------------------------------------------------ pincer

func test_pincer_follow_up() -> void:
	var m := BattleMap.flat(5, 5)
	var a := mk(0, "swordsman", 0, Vector2i(2, 3))
	var b := mk(1, "lancer", 0, Vector2i(2, 1))
	var t := mk(2, "swordsman", 1, Vector2i(2, 2), 3)
	t.max_hp = 200
	t.hp = 200
	var s := state_with(m, [a, b, t])
	s.current_id = a.id
	var pv := s.preview(a, "slash", t.pos)
	eq(pv.size(), 1, "one target")
	check(pv[0].has("pincer") and pv[0]["pincer"] == b, "preview shows pincer partner")
	check(str(pv[0]["labels"]).contains("夹击"), "preview label 夹击")
	var ev := s.execute(a, "slash", t.pos)
	var types := ev.map(func(x): return x["type"])
	check(types.has("damage"), "attack event")
	check(types.has("pincer"), "pincer follow-up event")
	var dealt := 0
	for x in ev:
		dealt += int(x.get("amount", 0))
	eq(t.hp, 200 - dealt, "pincer damage applied")


func test_pincer_requires_opposite() -> void:
	var m := BattleMap.flat(5, 5)
	var a := mk(0, "swordsman", 0, Vector2i(2, 3))
	var b := mk(1, "lancer", 0, Vector2i(3, 2))  # side, not opposite
	var t := mk(2, "swordsman", 1, Vector2i(2, 2))
	var s := state_with(m, [a, b, t])
	check(s.pincer_partner(a, t, a.pos) == null, "ally at side is not a pincer")
	b.pos = Vector2i(2, 1)
	b.team = 1
	check(s.pincer_partner(a, t, a.pos) == null, "enemy on opposite side is not a pincer")
	b.team = 0
	check(s.pincer_partner(a, t, a.pos) == b, "ally exactly opposite is pincer")
	var archer := mk(3, "archer", 0, Vector2i(2, 4))
	s.add_unit(archer)
	a.pos = Vector2i(0, 0)
	check(s.pincer_partner(archer, t, archer.pos) == b, "ranged attack in line also triggers pincer")
	check(s.pincer_partner(archer, t, Vector2i(4, 4)) == null, "diagonal ranged attack does not")


# ------------------------------------------------------------ class skills

func test_lance_line_hits_two() -> void:
	var m := BattleMap.flat(5, 1)
	var l := mk(0, "lancer", 0, Vector2i(0, 0), 1)
	var e1 := mk(1, "swordsman", 1, Vector2i(1, 0))
	var e2 := mk(2, "swordsman", 1, Vector2i(2, 0))
	var e3 := mk(3, "swordsman", 1, Vector2i(3, 0))
	var s := state_with(m, [l, e1, e2, e3])
	s.current_id = l.id
	var pv := s.preview(l, "thrust", Vector2i(1, 0))
	eq(pv.size(), 2, "thrust hits two tiles in line")
	eq(s.preview(l, "pierce", Vector2i(1, 0)).size(), 3, "穿云枪 hits three")
	check(not Combat.can_target(m, SkillDB.get_skill("thrust"), l.pos, Vector2i(2, 0)), "lance targets adjacent tile only")


func test_fire_and_ice_terrain() -> void:
	var m := BattleMap.from_rows(["00000", "00000", "00000"], ["ggggg", "ggwgg", "ggggg"])
	var mage := mk(0, "mage", 0, Vector2i(0, 1), 1)
	var e := mk(1, "swordsman", 1, Vector2i(3, 1))
	var s := state_with(m, [mage, e])
	s.current_id = mage.id
	mage.tp = 5
	var water := Vector2i(2, 1)
	eq(m.move_cost(water), 2, "water cost before freezing")
	s.execute(mage, "frost", water)
	eq(m.effect_at(water), "ice", "frost freezes water")
	eq(m.move_cost(water), 1, "frozen water walkable at cost 1")
	eq(m.effect_at(Vector2i(2, 0)), "ice", "ice spreads in cross")
	s.acted = false
	mage.tp = 5
	e.pos = Vector2i(4, 1)
	s.execute(mage, "flame", Vector2i(4, 1))
	eq(m.effect_at(Vector2i(4, 1)), "fire", "flame ignites ground")
	eq(m.effect_at(Vector2i(3, 1)), "", "fire melts ice instead of burning")
	check(not m.apply_effect(water, "fire"), "water cannot burn")
	s.end_turn(1)
	e.facing = 2
	var r := s.begin_next_turn()
	while r["unit"] != e:
		s.end_turn(1)
		r = s.begin_next_turn()
	check(str(r["events"]).contains("burn"), "burn event reported")
	for i in 30:
		m.tick_effects()
	check(m.effects.is_empty(), "effects expire")


func test_steal_and_dash() -> void:
	var m := BattleMap.flat(6, 1)
	var t := mk(0, "thief", 0, Vector2i(0, 0), 1)
	var e := mk(1, "swordsman", 1, Vector2i(1, 0), 1)
	var s := state_with(m, [t, e])
	s.current_id = t.id
	t.tp = 2
	e.tp = 3
	s.execute(t, "steal", e.pos)
	eq(e.tp, 1, "target lost 2 TP")
	eq(t.tp, 3, "thief: 2 - 1 cost + 2 stolen")
	s.acted = false
	s.moved = true
	s.execute(t, "dash", t.pos)
	check(not s.moved, "疾风步 allows moving again")
	eq(t.bonus_move, 2, "疾风步 +2 movement")


func test_knockback() -> void:
	var m := BattleMap.flat(4, 1)
	m.set_h(Vector2i(2, 0), 3)
	m.set_h(Vector2i(1, 0), 3)
	var l := mk(0, "lancer", 0, Vector2i(0, 0), 1)
	m.set_h(Vector2i(0, 0), 3)
	var e := mk(1, "swordsman", 1, Vector2i(1, 0))
	e.max_hp = 300
	e.hp = 300
	var s := state_with(m, [l, e])
	s.current_id = l.id
	l.tp = 5
	var ev := s.execute(l, "knockback", e.pos)
	eq(e.pos, Vector2i(2, 0), "pushed one tile")
	s.acted = false
	l.pos = Vector2i(1, 0)
	var ev2 := s.execute(l, "knockback", e.pos)
	eq(e.pos, Vector2i(3, 0), "pushed off the ledge")
	check(str(ev2).contains("knockback"), "knockback event")
	check(int(ev2[ev2.size() - 1]["amount"]) > 0, "fall damage from 3 levels")


# ------------------------------------------------------------ vote

func make_vote(leader := {"ren": 1, "zhi": 1, "yong": 1}) -> VoteSystem:
	var v := VoteSystem.new()
	v.setup(StoryData.VOTE["options"], StoryData.VOTE["members"], leader)
	return v


func test_vote_initial_and_tally() -> void:
	var v := make_vote()
	eq(v.member("gelan")["vote"], "B", "葛岚 leans B (勇)")
	eq(v.member("baitang")["vote"], "A", "白棠 leans A (仁)")
	eq(v.member("wenzhou")["vote"], "", "闻舟 undecided -> abstain")
	var t := v.tally()
	eq(t, {"A": 1, "B": 3, "abstain": 1}, "initial tally")
	eq(v.result()["winner"], "B", "majority B")


func test_vote_persuasion() -> void:
	var v := make_vote()
	var r := v.persuade("gelan", "ren", "A")
	check(r["ok"] and not r["success"], "葛岚 unmoved by 仁")
	eq(v.member("gelan")["vote"], "B", "葛岚 stays B")
	check(not v.can_persuade("gelan"), "each member can be persuaded once")
	var r2 := v.persuade("wenzhou", "zhi", "A")
	check(r2["success"], "闻舟 persuaded by 智")
	eq(v.persuasions_left, 0, "two persuasions used")
	var r3 := v.persuade("moqi", "zhi", "A")
	check(not r3["ok"], "no persuasions left")
	var v2 := make_vote()
	v2.persuade("wenzhou", "zhi", "A")
	v2.persuade("moqi", "yong", "A")
	eq(v2.result()["winner"], "A", "two persuasions flip the vote to A (3-2)")
	var v3 := make_vote({"ren": 1, "zhi": 1, "yong": 3})
	v3.members[0]["resolve"] = 4
	check(v3.persuasion_score(v3.members[0], "yong") == 4, "protagonist strong conviction adds +1")
	var already := make_vote().persuade("gelan", "yong", "B")
	check(not already["ok"], "persuading toward current vote is refused without cost")


func test_vote_tie_break() -> void:
	var v := make_vote({"ren": 3, "zhi": 1, "yong": 1})
	v.persuade("moqi", "zhi", "A")  # A2 B2 abstain1
	var res := v.result()
	check(res["tie"], "2-2 tie")
	eq(res["tie_rule"], "leader", "tie broken by 持秤者")
	eq(res["winner"], "A", "仁-leaning leader picks A")
	var vb := make_vote({"ren": 1, "zhi": 1, "yong": 3})
	vb.persuade("moqi", "zhi", "A")
	eq(vb.result()["winner"], "B", "勇-leaning leader picks B")
	var vd := make_vote({"ren": 1, "zhi": 3, "yong": 1})
	vd.persuade("moqi", "zhi", "A")
	var rd := vd.result()
	eq(rd["tie_rule"], "default", "even leader -> default rule")
	eq(rd["winner"], "A", "default tie winner is option A")


# ------------------------------------------------------------ AI / battles

func test_ai_prefers_back_attack() -> void:
	var m := BattleMap.flat(7, 7)
	var ai := mk(10, "swordsman", 1, Vector2i(5, 4))
	var p := mk(0, "swordsman", 0, Vector2i(3, 3), 2)  # facing south toward the AI
	var s := state_with(m, [p, ai])
	s.current_id = ai.id
	var plan := EnemyAI.plan(s, ai)
	eq(plan["skill"] != "", true, "AI attacks")
	eq(Combat.relative_side(p.pos, p.facing, plan["move"]), "back", "AI walks around for a back attack")
	var far := mk(11, "swordsman", 1, Vector2i(6, 0))
	var m2 := BattleMap.flat(12, 12)
	var p2 := mk(0, "swordsman", 0, Vector2i(0, 11))
	var s2 := state_with(m2, [p2, far])
	var plan2 := EnemyAI.plan(s2, far)
	check(Pathing.manhattan(plan2["move"], p2.pos) < Pathing.manhattan(far.pos, p2.pos), "AI approaches when out of reach")


func test_battle_defs_valid() -> void:
	for id in BattleDefs.DEFS:
		var s := BattleDefs.build_state(id)
		eq(s.map.width, 10, "%s width 10" % id)
		eq(s.map.height, 10, "%s height 10" % id)
		var seen := {}
		for u in s.units:
			check(s.map.is_passable(u.pos), "%s: %s on passable tile" % [id, u.name])
			check(not seen.has(u.pos), "%s: %s tile not shared" % [id, u.name])
			seen[u.pos] = true
		eq(s.living(0).size(), 6, "%s: six party members" % id)
		var classes := {}
		for u in s.living(0):
			classes[u.cls] = true
		eq(classes.size(), 6, "%s: six distinct classes" % id)


func test_ai_full_battles() -> void:
	for id in BattleDefs.DEFS:
		for seed in [1, 2]:
			var s := BattleDefs.build_state(id, seed)
			var turns := 0
			while s.outcome() == "" and turns < 600:
				var r := s.begin_next_turn()
				var u = r["unit"]
				if u == null:
					break
				var plan := EnemyAI.plan(s, u)
				if plan["move"] != u.pos:
					var path := s.move_unit(u, plan["move"])
					check(not path.is_empty(), "AI move legal")
				if plan["skill"] != "":
					check(s.is_valid_target(u, plan["skill"], plan["target"]) or SkillDB.get_skill(plan["skill"])["kind"] == "self", "AI target valid")
					s.execute(u, plan["skill"], plan["target"])
				s.end_turn(plan["facing"])
				turns += 1
			check(s.outcome() != "", "%s seed %d resolves (%s after %d turns)" % [id, seed, s.outcome(), turns])


func test_outcome_rules() -> void:
	var s := BattleDefs.build_state("b2A")
	eq(s.outcome(), "", "ongoing")
	for u in s.units:
		if u.is_leader:
			u.hp = 0
	eq(s.outcome(), "win", "defeating the leader wins b2A")
	var s2 := BattleDefs.build_state("b1")
	for u in s2.units:
		if u.is_lord:
			u.hp = 0
	eq(s2.outcome(), "lose", "lord falling loses")
	var s3 := BattleDefs.build_state("b1")
	for u in s3.living(1):
		u.hp = 0
	eq(s3.outcome(), "win", "all enemies defeated wins b1")
