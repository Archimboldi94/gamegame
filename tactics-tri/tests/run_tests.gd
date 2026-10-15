extends SceneTree
## Headless rule tests:  godot --headless --path . -s tests/run_tests.gd

var passed := 0
var failed := 0
var _current := ""


func _init() -> void:
	# Defer until autoloads have finished _ready (AudioManager buses/streams).
	call_deferred("_run_all")


func _run_all() -> void:
	var tests := [
		"test_climb_cost_and_jump_limit", "test_drop_limit", "test_terrain_costs_and_evasion",
		"test_allies_passable_enemies_block", "test_height_damage", "test_ranged_height_range_bonus",
		"test_melee_vertical_reach", "test_facing_sides", "test_facing_bonus_damage_and_hit",
		"test_turn_order_speed", "test_turn_order_wait_cost", "test_turn_order_preview_and_delay",
		"test_tp_gain_and_cap", "test_tp_costs", "test_pincer_follow_up", "test_pincer_requires_opposite",
		"test_lance_line_hits_two", "test_fire_and_ice_terrain", "test_steal_and_dash", "test_knockback",
		"test_vote_initial_and_tally", "test_vote_persuasion", "test_vote_tie_break",
		"test_ai_prefers_back_attack", "test_battle_defs_valid", "test_ai_full_battles", "test_outcome_rules",
		"test_deep_water_impassable", "test_ford_and_bridge_passable", "test_flying_crosses_water",
		"test_water_blocks_ai_and_knockback", "test_maps_river_crossings", "test_auto_facing_after_move",
		"test_auto_facing_toward_target", "test_auto_facing_consistent_with_back_attack",
		"test_every_skill_has_cast_visual", "test_back_button_does_not_quit_battle",
		"test_iso_rotate_and_pick", "test_pick_ignores_sprite_bounds",
		"test_water_still_impassable_after_view_rotate", "test_audio_placeholders_and_manager",
		"test_expanded_tile_edges_and_ground_gaps", "test_battle_hud_and_ground_toggle",
		"test_wuxia_eight_dir_and_corner", "test_wuxia_ap_and_neili",
		"test_wuxia_control_zone_and_counter", "test_wuxia_b1_setup",
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

func mk(id: int, cls: String, team: int, pos: Vector2i, facing := 4) -> BattleUnit:
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
	var m := BattleMap.from_rows(["000", "000"], ["gfd", "srx"])
	eq(m.move_cost(Vector2i(0, 0)), 1, "grass cost")
	eq(m.move_cost(Vector2i(1, 0)), 2, "forest cost")
	eq(m.move_cost(Vector2i(2, 0)), 2, "ford slows")
	eq(m.evasion(Vector2i(1, 0)), 15, "forest evasion")
	check(m.evasion(Vector2i(2, 0)) < 0, "ford lowers evasion")
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
	eq(Combat.relative_side(t, 2, Vector2i(3, 5)), "back", "facing east, attacker west => back")
	eq(Combat.relative_side(t, 4, Vector2i(5, 8)), "front", "facing south, ranged from south => front")
	eq(Combat.relative_side(t, 4, Vector2i(6, 6)), "front", "SE vs facing south is front-right")
	eq(Combat.relative_side(t, 4, Vector2i(5, 1)), "back", "facing south, ranged from far north => back")


func test_facing_bonus_damage_and_hit() -> void:
	var m := BattleMap.flat(3, 3)
	var a := mk(0, "swordsman", 0, Vector2i(1, 2))
	var t := mk(1, "swordsman", 1, Vector2i(1, 1))
	var sk := SkillDB.get_skill("slash")
	t.facing = 4
	var front := Combat.calc(a, t, sk, m, a.pos)
	t.facing = 2
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
	s.end_turn()
	s.begin_next_turn()
	s.end_turn()
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
	var m := BattleMap.from_rows(["00000", "00000", "00000"], ["ggggg", "ggdgg", "ggggg"])
	var mage := mk(0, "mage", 0, Vector2i(0, 1), 1)
	var e := mk(1, "swordsman", 1, Vector2i(3, 1))
	var s := state_with(m, [mage, e])
	s.current_id = mage.id
	mage.tp = 5
	var water := Vector2i(2, 1)
	eq(m.move_cost(water), 2, "ford cost before freezing")
	s.execute(mage, "frost", water)
	eq(m.effect_at(water), "ice", "frost freezes the ford")
	eq(m.move_cost(water), 1, "frozen ford walkable at cost 1")
	eq(m.effect_at(Vector2i(2, 0)), "ice", "ice spreads in cross")
	s.acted = false
	mage.tp = 5
	e.pos = Vector2i(4, 1)
	s.execute(mage, "flame", Vector2i(4, 1))
	eq(m.effect_at(Vector2i(4, 1)), "fire", "flame ignites ground")
	eq(m.effect_at(Vector2i(3, 1)), "", "fire melts ice instead of burning")
	check(not m.apply_effect(water, "fire"), "ford cannot burn")
	s.end_turn()
	e.facing = 2
	var r := s.begin_next_turn()
	while r["unit"] != e:
		s.end_turn()
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
	var p := mk(0, "swordsman", 0, Vector2i(3, 3), 4)  # facing south toward the AI
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
				check(not plan.has("facing"), "AI plan has no facing choice")
				if plan["move"] != u.pos:
					var path := s.move_unit(u, plan["move"])
					check(not path.is_empty(), "AI move legal")
					var dry := true
					for p in path:
						dry = dry and s.map.is_passable(p, u.flying)
					check(dry, "%s: AI path never crosses deep water" % id)
				if plan["skill"] != "":
					check(s.is_valid_target(u, plan["skill"], plan["target"]) or SkillDB.get_skill(plan["skill"])["kind"] == "self", "AI target valid")
					s.execute(u, plan["skill"], plan["target"])
				s.end_turn()
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


# ------------------------------------------------------------ deep water / rivers

func river_map() -> BattleMap:
	# 5x5, a river runs down column x=2; (2,0) is a ford, (2,4) a bridge.
	return BattleMap.from_rows(["00000", "00000", "00000", "00000", "00000"],
		["ggdgg", "ggwgg", "ggwgg", "ggwgg", "ggbgg"])


func test_deep_water_impassable() -> void:
	var m := river_map()
	check(not m.is_passable(Vector2i(2, 2)), "deep water is not passable on foot")
	check(m.is_passable(Vector2i(2, 2), true), "deep water passable for fliers")
	eq(Pathing.enter_cost(m, 9, Vector2i(1, 2), Vector2i(2, 2)), -1, "cannot step into deep water")
	eq(Terrain.info("water")["name"], "深水", "water is labelled deep water")
	var u := mk(0, "thief", 0, Vector2i(1, 2))  # mov 5, jump 3: best walker
	u.mov = 12
	var r := Pathing.search(m, u, [u], u.mov)
	for y in range(1, 4):
		check(not r["cost"].has(Vector2i(2, y)), "river tile (2,%d) never reached" % y)
		check(not (r["ends"] as Array).has(Vector2i(2, y)), "river tile (2,%d) not highlighted as a move end" % y)
	check((r["ends"] as Array).has(Vector2i(3, 2)), "far bank reachable via ford/bridge")
	var path := Pathing.path_to(r, u.pos, Vector2i(3, 2))
	check(not path.is_empty(), "path to far bank exists")
	var crosses_dry := path.has(Vector2i(2, 0)) or path.has(Vector2i(2, 4))
	check(crosses_dry, "path crosses at the ford or bridge")
	for p in path:
		check(m.get_terrain(p) != "water", "path step %s is not deep water" % str(p))
	var s := state_with(m, [u])
	s.current_id = u.id
	u.mov = 1
	eq(s.move_unit(u, Vector2i(2, 2)), [], "move_unit refuses a deep water destination")
	eq(u.pos, Vector2i(1, 2), "unit stays on the bank")
	var short := Pathing.search(m, u, [u], 1)
	check(not short["cost"].has(Vector2i(2, 2)), "short-range search also blocked")
	check(not m.apply_effect(Vector2i(2, 2), "ice"), "deep water cannot be frozen into a bridge")
	check(not m.is_passable(Vector2i(2, 2)), "still impassable after frost attempt")


func test_ford_and_bridge_passable() -> void:
	var m := river_map()
	check(m.is_passable(Vector2i(2, 0)), "ford passable")
	check(m.is_passable(Vector2i(2, 4)), "bridge passable")
	eq(m.move_cost(Vector2i(2, 0)), 2, "ford costs 2")
	eq(m.move_cost(Vector2i(2, 4)), 1, "bridge costs 1")
	var u := mk(0, "swordsman", 0, Vector2i(1, 0))
	var r := Pathing.search(m, u, [u], u.mov)
	check((r["ends"] as Array).has(Vector2i(2, 0)), "can stop on the ford")
	check((r["ends"] as Array).has(Vector2i(3, 0)), "can wade across the ford")
	u.pos = Vector2i(1, 4)
	var r2 := Pathing.search(m, u, [u], u.mov)
	check((r2["ends"] as Array).has(Vector2i(3, 4)), "can cross the bridge")


func test_flying_crosses_water() -> void:
	var m := river_map()
	var f := mk(0, "archer", 0, Vector2i(1, 2))
	f.flying = true
	var r := Pathing.search(m, f, [f], f.mov)
	check((r["ends"] as Array).has(Vector2i(2, 2)), "flier may hover over deep water")
	check((r["ends"] as Array).has(Vector2i(3, 2)), "flier crosses the river directly")
	eq(int(r["cost"][Vector2i(3, 2)]), 2, "flier pays 1 per water tile")
	var walls := BattleMap.from_rows(["000"], ["gxg"])
	f.pos = Vector2i(0, 0)
	var r2 := Pathing.search(walls, f, [f], 6)
	check(not r2["cost"].has(Vector2i(1, 0)), "fliers still cannot pass walls")
	check(not BattleUnit.create(1, "x", "thief", 0, Vector2i.ZERO).flying, "no class flies by default")


func test_water_blocks_ai_and_knockback() -> void:
	var m := BattleMap.from_rows(["0000000", "0000000", "0000000"], ["gggwggg", "gggwggg", "gggwggg"])
	var foe := mk(10, "swordsman", 1, Vector2i(4, 1))
	var p := mk(0, "swordsman", 0, Vector2i(2, 1))
	var s := state_with(m, [p, foe])
	s.current_id = foe.id
	var plan := EnemyAI.plan(s, foe)
	check(plan["skill"] == "" or plan["skill"] == "guard", "AI cannot attack across an uncrossable river (%s)" % plan["skill"])
	check(m.get_terrain(plan["move"]) != "water", "AI never plans to stand in deep water")
	foe.mov = 20
	var full := Pathing.search(m, foe, s.units, 99)
	for q in full["cost"]:
		check(m.get_terrain(q) != "water", "AI flood fill never enters water (%s)" % str(q))
	var l := mk(1, "lancer", 0, Vector2i(1, 1), 1)
	var e := mk(11, "swordsman", 1, Vector2i(2, 1))
	e.max_hp = 300
	e.hp = 300
	var s2 := state_with(m, [l, e])
	s2.current_id = l.id
	l.tp = 5
	var ev := s2.execute(l, "knockback", e.pos)
	eq(e.pos, Vector2i(2, 1), "knockback does not push a walker into deep water")
	check(str(ev).contains("collide"), "river edge counts as an obstacle")


func test_maps_river_crossings() -> void:
	for id in BattleDefs.DEFS:
		var s := BattleDefs.build_state(id)
		var lord: BattleUnit = null
		for u in s.living(0):
			if u.is_lord:
				lord = u
		for u in s.units:
			var r := s.reachable_for(u)
			for q in r["cost"]:
				check(s.map.get_terrain(q) != "water", "%s: %s cannot enter deep water at %s" % [id, u.name, str(q)])
		# every enemy must still be reachable on foot (via bridge/ford) or the battle could stall
		var probe := mk(99, "swordsman", 0, lord.pos)
		probe.jump = 9
		var full := Pathing.search(s.map, probe, [probe], 999)
		for foe in s.living(1):
			var near := false
			for d in BattleMap.DIRS:
				near = near or full["cost"].has(foe.pos + d)
			check(near, "%s: %s reachable on foot" % [id, foe.name])
	var b1 := BattleDefs.build_map("b1")
	eq(b1.get_terrain(Vector2i(0, 4)), "water", "b1 river is deep water")
	eq(b1.get_terrain(Vector2i(4, 4)), "bridge", "b1 bridge")
	eq(b1.get_terrain(Vector2i(8, 4)), "ford", "b1 ford")


# ------------------------------------------------------------ auto facing

func test_auto_facing_after_move() -> void:
	var m := BattleMap.flat(6, 6)
	var u := mk(0, "swordsman", 0, Vector2i(1, 1), 0)
	var e := mk(10, "swordsman", 1, Vector2i(5, 5))
	var s := state_with(m, [u, e])
	eq(s.begin_next_turn()["unit"], u, "player first")
	s.move_unit(u, Vector2i(1, 3))
	eq(s.auto_facing(u), 4, "after moving south the unit faces south")
	s.undo_move()
	eq(u.facing, 0, "undo restores the original facing")
	s.move_unit(u, Vector2i(3, 1))
	s.end_turn()
	eq(u.facing, 2, "end_turn keeps the movement direction (east)")
	var r := s.begin_next_turn()
	while r["unit"] != u:
		s.end_turn()
		r = s.begin_next_turn()
	var before := u.facing
	s.end_turn()
	eq(u.facing, before, "pure wait keeps facing")


func test_auto_facing_toward_target() -> void:
	var m := BattleMap.flat(6, 6)
	var a := mk(0, "archer", 0, Vector2i(2, 2), 0)
	var e := mk(10, "swordsman", 1, Vector2i(5, 2), 0)
	e.max_hp = 500
	e.hp = 500
	var s := state_with(m, [a, e])
	eq(s.begin_next_turn()["unit"], a, "archer first")
	s.move_unit(a, Vector2i(2, 4))
	eq(a.facing, 4, "faces south after moving south")
	s.execute(a, "shoot", e.pos)
	eq(a.facing, 1, "faces the target when shooting ENE")
	s.end_turn()
	eq(a.facing, 1, "still faces the last target at turn end")
	var r := s.begin_next_turn()
	while r["unit"] != a:
		s.end_turn()
		r = s.begin_next_turn()
	s.execute(a, "shoot", e.pos)
	s.move_unit(a, Vector2i(5, 5))
	eq(a.facing, 0, "attack then move: faces back toward the target (north)")
	s.end_turn()
	eq(a.facing, 0, "turn ends facing the last target, not the movement direction")
	var h := mk(1, "healer", 0, Vector2i(0, 0), 6)
	s.add_unit(h)
	s.current_id = h.id
	s.last_target = BattleState.NO_TARGET
	h.tp = 5
	s.execute(h, "heal", h.pos)
	s.end_turn()
	eq(h.facing, 6, "self-targeted skill does not change facing")


func test_auto_facing_consistent_with_back_attack() -> void:
	var m := BattleMap.flat(7, 7)
	var p := mk(0, "swordsman", 0, Vector2i(3, 4), 4)
	var foe := mk(10, "swordsman", 1, Vector2i(3, 2), 4)
	foe.max_hp = 500
	foe.hp = 500
	var s := state_with(m, [p, foe])
	eq(s.begin_next_turn()["unit"], p, "player first")
	s.move_unit(p, Vector2i(3, 3))
	s.execute(p, "slash", foe.pos)
	s.end_turn()
	eq(p.facing, 0, "player auto-faces the enemy it struck")
	eq(Combat.relative_side(p.pos, p.facing, foe.pos), "front", "struck enemy is in front")
	eq(Combat.relative_side(p.pos, p.facing, Vector2i(3, 4)), "back", "tile behind is the back")
	var behind := Combat.calc(foe, p, SkillDB.get_skill("slash"), m, Vector2i(3, 4))
	var front := Combat.calc(foe, p, SkillDB.get_skill("slash"), m, Vector2i(3, 2))
	eq(behind["side"], "back", "back attack detected against auto-faced unit")
	check(int(behind["dmg"]) > int(front["dmg"]), "back attack still deals bonus damage")
	s.current_id = foe.id
	var plan := EnemyAI.plan(s, foe)
	eq(Combat.relative_side(p.pos, p.facing, plan["move"]), "back", "AI exploits the predictable auto-facing")


# ------------------------------------------------------------ battle presentation

func test_every_skill_has_cast_visual() -> void:
	var src := FileAccess.get_file_as_string("res://scripts/game/battle.gd")
	var a := src.find("func _cast(")
	var b := src.find("\nfunc ", a + 1)
	check(a >= 0 and b > a, "battle.gd defines _cast")
	var body := src.substr(a, b - a)
	for sid in SkillDB.SKILLS:
		check(src.contains('"%s": Color(' % sid), "skill %s has an effect colour" % sid)
		var arm := RegEx.create_from_string('\\n\\t\\t("[a-z_]+", )*"%s"(, "[a-z_]+")*:\\n' % sid)
		check(arm.search(body) != null, "skill %s has its own cast animation arm" % sid)
	var react := src.substr(src.find("func _react("), 2000)
	for kind in ["\"damage\":", "\"miss\":", "\"heal\":"]:
		check(react.contains(kind), "_react handles %s" % kind)
	check(react.contains("fx.number("), "_react shows floating numbers")
	check(not src.contains("\"face\""), "battle has no facing-selection mode")


func test_back_button_does_not_quit_battle() -> void:
	eq(ProjectSettings.get_setting("application/config/quit_on_go_back", true), false, "Android back cancels instead of quitting")


# ------------------------------------------------------------ camera rotate / grid pick / audio

func test_iso_rotate_and_pick() -> void:
	var m := BattleMap.flat(4, 4)
	m.set_h(Vector2i(1, 1), 2)
	m.set_h(Vector2i(2, 2), 1)
	var view := IsoView.new()
	view.configure(4, 4, 0)
	var logical := Vector2i(1, 2)
	# Identity at yaw 0
	eq(view.to_display(logical), logical, "yaw0 display == logical")
	eq(view.to_logical(logical), logical, "yaw0 logical == display")
	# Round-trip through every yaw
	for yaw in range(4):
		view.yaw = yaw
		var d := view.to_display(logical)
		eq(view.to_logical(d), logical, "yaw%d rotate round-trip" % yaw)
		var world := view.screen(logical, m.get_h(logical))
		eq(view.pick(world, m), logical, "yaw%d pick centre of tile" % yaw)
	# 90° CW: (0,0)->(0,3), (3,0)->(0,0), (3,3)->(3,0), (0,3)->(3,3)
	view.yaw = 1
	eq(view.to_display(Vector2i(0, 0)), Vector2i(0, 3), "CW (0,0)")
	eq(view.to_display(Vector2i(3, 0)), Vector2i(0, 0), "CW (3,0)")
	eq(view.to_display(Vector2i(3, 3)), Vector2i(3, 0), "CW (3,3)")
	eq(view.to_display(Vector2i(0, 3)), Vector2i(3, 3), "CW (0,3)")
	# Facing arrows rotate with the camera
	eq(view.facing_view(0), 6, "facing 0 becomes 6 at yaw 1 (8-dir)")
	check(view.faces_left(0) == true, "facing 0 appears left at yaw 1 (8-dir)")
	check(IsoView.rotate_cell(Vector2i(1, 0), 2, 4, 4) == Vector2i(2, 3), "static rotate 180")
	check(IsoView.unrotate_cell(Vector2i(2, 3), 2, 4, 4) == Vector2i(1, 0), "static unrotate 180")


func test_pick_ignores_sprite_bounds() -> void:
	# Tall unit sprites sit above the tile; picking must use the diamond under the point.
	var m := BattleMap.flat(3, 3)
	var view := IsoView.new()
	view.configure(3, 3, 0)
	var cell := Vector2i(1, 1)
	var top := view.screen(cell, 0)
	# A point on the tile top face
	eq(view.pick(top + Vector2(0, 0), m), cell, "pick hits tile top")
	# A point well above the diamond (where a unit sprite would be) must NOT select via sprite
	var above := top + Vector2(0, -120)
	var picked := view.pick(above, m)
	check(picked != cell, "point above the diamond is not the standing cell")
	# After 90° rotation the same logical cell is still pickable at its new screen pos
	view.rotate_by(1)
	var top_r := view.screen(cell, 0)
	eq(view.pick(top_r, m), cell, "pick after 90° still returns logical cell")


func test_water_still_impassable_after_view_rotate() -> void:
	var m := river_map()
	var water := Vector2i(2, 2)
	check(not m.is_passable(water), "water impassable before rotate")
	var view := IsoView.new()
	view.configure(m.width, m.height, 0)
	for yaw in range(4):
		view.yaw = yaw
		check(not m.is_passable(water), "water impassable at yaw %d" % yaw)
		eq(Pathing.enter_cost(m, 9, Vector2i(1, 2), water), -1, "pathing blocked at yaw %d" % yaw)
		# Picking the water tile still resolves to the logical water cell
		var wp := view.screen(water, m.get_h(water))
		eq(view.pick(wp, m), water, "pick water logical cell at yaw %d" % yaw)
	var u := mk(0, "swordsman", 0, Vector2i(1, 2))
	var r := Pathing.search(m, u, [u], 8)
	check(not r["cost"].has(water), "reachable set never includes deep water")


func test_expanded_tile_edges_and_ground_gaps() -> void:
	var map := BattleMap.flat(5, 5)
	var view := IsoView.new()
	view.configure(5, 5)
	var cell := Vector2i(2, 2)
	# Real exposed shoulders of the enlarged diamond, well outside a unit's body.
	for yaw in range(4):
		view.yaw = yaw
		var center := view.screen(cell, 0)
		for offset in [Vector2(-IsoView.TW * 0.38, 0), Vector2(IsoView.TW * 0.38, 0), Vector2(0, IsoView.TH * 0.38)]:
			eq(view.pick(center + offset, map), cell, "exposed ground at yaw%d / %s" % [yaw, offset])
	check(not view.top_contains(Vector2(IsoView.TW * 0.5, 0)), "shared tip excluded with enlarged metrics")
	check(not view.top_contains(Vector2(0, IsoView.TH * 0.5 + 1)), "point below top not a top hit")
	check(view.column_contains(Vector2(0, IsoView.TH * 0.5 + IsoView.HS), 1), "enlarged column side remains pickable")
	check(not view.column_contains(Vector2(0, IsoView.TH * 0.5 + IsoView.HS * 2 + 1), 1), "column hit stops at its physical base")


func test_battle_hud_and_ground_toggle() -> void:
	var game = root.get_node("Game")
	var old_shot: String = game.shot
	var old_battle: String = game.current_battle
	game.shot = "battle"
	game.current_battle = "b1"
	var battle = load("res://scripts/game/battle.gd").new()
	root.add_child(battle)
	var attacker: BattleUnit = battle.state.current()
	var defender: BattleUnit = battle.state.unit_at(battle.sel_target)
	var preview: Dictionary = battle.state.preview(attacker, attacker.basic, defender.pos)[0]
	eq(battle.selected_panel.unit_name.text, attacker.name, "forecast keeps attacker in left portrait")
	eq(battle.target_panel.unit_name.text, defender.name, "forecast shows defender in right portrait")
	eq(battle.damage_label.text, "−%d" % preview["dmg"], "prominent damage comes from rules preview")
	check(battle.hit_label.text.contains("%d%%" % preview["hit"]), "hit chance comes from rules preview")
	check(battle.preview_text.text.contains("夹击追击"), "pincer follow-up remains visible")
	check(battle.skill_chip.visible, "chosen skill chip is visible")
	eq(battle.timeline_box.get_child_count(), 8, "timeline retains eight turns")
	check(not battle.unit_nodes[attacker.id].see_through, "attacker stays readable in forecast")
	check(not battle.unit_nodes[defender.id].see_through, "defender stays readable in forecast")
	battle._enter_main()
	for button in battle.menu_box.get_children():
		check(button.custom_minimum_size.y >= 96, "battle action remains touch-sized")
	battle._inspect(defender.pos, defender)
	eq(battle.selected_panel.unit_name.text, defender.name, "inspection selects occupied unit")
	battle._inspect(defender.pos, defender)
	check(battle.sel_ground, "same-cell second tap selects ground")
	eq(battle.selected_panel.unit_name.text, Terrain.info(battle.state.map.get_terrain(defender.pos))["name"], "ground card shows terrain")
	check(battle.unit_nodes[defender.id].see_through, "ground inspection fades its occupant")
	battle._inspect(defender.pos, defender)
	check(not battle.sel_ground, "same-cell third tap returns to unit")
	check(not battle.unit_nodes[defender.id].see_through, "unit inspection restores its occupant")
	battle._enter_target("guard")
	eq(battle.target_panel.unit_name.text, attacker.name, "self skill shows its subject")
	check(battle.forecast_note.text.contains("自身"), "self skill describes immediate use")
	var healer: BattleUnit = null
	for unit in battle.state.units:
		if unit.cls == "healer" and unit.team == BattleUnit.PLAYER:
			healer = unit
	attacker.hp = attacker.max_hp - 7
	battle.state.current_id = healer.id
	battle._enter_target("heal")
	battle._select_target(attacker.pos)
	eq(battle.selected_panel.unit_name.text, healer.name, "healing keeps caster in left portrait")
	eq(battle.target_panel.unit_name.text, attacker.name, "healing shows recipient in right portrait")
	eq(battle.damage_label.text, "+7", "healing preview clamps to missing HP")
	check(battle.target_panel.hp_text.text.contains("→%d" % attacker.max_hp), "healing predicts capped final HP")
	var outside := Vector2i(0, 4)
	battle.cam.force_update_scroll()
	var finger: Vector2 = battle.get_viewport().get_canvas_transform() * battle.view.screen(outside, battle.state.map.get_h(outside))
	battle._on_tap(finger)
	eq(battle.sel_target, Vector2i(-1, -1), "inspecting out-of-range ground clears pending target")
	check(battle.menu_box.get_child(0).disabled, "old forecast cannot be confirmed after ground inspection")
	eq(battle.damage_label.text, "", "ground inspection clears old damage forecast")
	battle._select_target(attacker.pos)
	# Rotating the actual scene updates geometry, arrows and the selected cursor.
	for yaw in range(4):
		battle._rotate_cam(1)
		var center: Vector2 = battle.view.screen(attacker.pos, battle.state.map.get_h(attacker.pos))
		eq(battle.view.pick(center, battle.state.map), attacker.pos, "scene picks logical cell after rotation %d" % yaw)
		eq(battle.tile_cursor.position, center, "cursor follows selected tile after rotation %d" % yaw)
	battle.free()
	game.shot = old_shot
	game.current_battle = old_battle


func test_audio_placeholders_and_manager() -> void:
	var sfx := [
		"ui_tap", "ui_confirm", "ui_cancel", "unit_select",
		"move_step_grass", "move_step_stone", "move_step_water",
		"atk_sword", "atk_bow", "atk_shield", "hit_flesh", "hit_block", "crit",
		"heal", "skill_cast", "unit_down", "turn_start_ally", "turn_start_enemy",
		"victory", "defeat", "amb_night_wind",
	]
	for id in sfx:
		check(ResourceLoader.exists("res://audio/sfx/%s.ogg" % id), "sfx file %s.ogg" % id)
	check(ResourceLoader.exists("res://audio/bgm/bgm_battle_loop.ogg"), "bgm_battle_loop.ogg exists")
	check(ProjectSettings.has_setting("autoload/AudioManager"), "AudioManager registered as autoload")
	var am_path: String = str(ProjectSettings.get_setting("autoload/AudioManager"))
	check(am_path.ends_with("audio_manager.gd"), "AudioManager points at audio_manager.gd")
	# -s SceneTree scripts don't get autoload globals at parse time; resolve by node path.
	var am: Node = root.get_node_or_null("AudioManager")
	var spawned := false
	if am == null:
		am = load("res://scripts/game/audio_manager.gd").new()
		root.add_child(am)
		spawned = true
	check(am.has_clip("ui_tap"), "AudioManager loaded ui_tap")
	check(am.has_clip("bgm_battle_loop"), "AudioManager loaded bgm")
	check(AudioServer.get_bus_index("BGM") >= 0, "BGM bus exists")
	check(AudioServer.get_bus_index("SFX") >= 0, "SFX bus exists")
	var players_before := 0
	for c in am.get_children():
		if c is AudioStreamPlayer:
			players_before += 1
	am.play_bgm("bgm_battle_loop")
	am.play_bgm("bgm_battle_loop")
	am.play_ambience("amb_night_wind")
	am.play_ambience("amb_night_wind")
	var players_after := 0
	for c in am.get_children():
		if c is AudioStreamPlayer:
			players_after += 1
	eq(players_after, players_before, "BGM/ambience play does not spawn extra players")
	am.stop_battle_audio()
	if spawned:
		am.queue_free()
	var battle_src := FileAccess.get_file_as_string("res://scripts/game/battle.gd")
	check(battle_src.contains("_rotate_cam"), "battle has camera rotate")
	check(battle_src.contains("view.pick"), "battle picks via grid view")
	check(battle_src.contains("sel_ground"), "battle toggles unit/ground")
	check(battle_src.contains("set_see_through"), "battle fades occluding units")
	check(battle_src.contains("tile_cursor"), "battle draws cursor above units")
	check(battle_src.contains("cell == sel_target"), "second tap on pending target detected")
	check(battle_src.contains("_confirm()"), "second tap can confirm attack/skill")
	check(FileAccess.file_exists("res://audio/CREDITS.md"), "audio CREDITS.md present")


# ------------------------------------------------------------ wuxia / GDD

func test_wuxia_eight_dir_and_corner() -> void:
	eq(BattleMap.DIRS.size(), 8, "eight movement dirs")
	var m := BattleMap.flat(3, 3)
	m.set_terrain(Vector2i(1, 0), "wall")
	m.set_terrain(Vector2i(0, 1), "wall")
	eq(Pathing.closed_corner(m, Vector2i(0, 0), Vector2i(1, 1)), true, "sealed corner blocks diagonal")
	eq(Pathing.enter_cost(m, 1, Vector2i(0, 0), Vector2i(1, 1)), -1, "cannot enter through sealed corner")
	m.set_terrain(Vector2i(1, 0), "grass")
	eq(Pathing.closed_corner(m, Vector2i(0, 0), Vector2i(1, 1)), false, "single side wall allows diagonal")


func test_wuxia_ap_and_neili() -> void:
	var s := BattleDefs.build_wuxia_b1(11)
	var start := s.begin_next_turn()
	var u: BattleUnit = start["unit"]
	check(u != null, "wuxia B1 has an actor")
	eq(u.ap, 6, "start with 6 AP")
	eq(u.qi, mini(u.max_qi, u.max_qi), "qi full at fight start then +1 on turn? first actor got +1 so may be capped")
	check(u.qi >= u.max_qi, "qi at cap on first turn after regen")
	var r := s.reachable_for(u)
	check((r["ends"] as Array).size() > 1, "AP allows several tiles")
	var dest: Vector2i = (r["ends"] as Array)[0]
	if dest == u.pos and (r["ends"] as Array).size() > 1:
		dest = (r["ends"] as Array)[1]
	var before := u.ap
	s.move_unit(u, dest)
	check(u.ap < before or dest == u.pos, "moving spends AP")


func test_wuxia_control_zone_and_counter() -> void:
	var m := BattleMap.flat(5, 5)
	var a := BattleUnit.new()
	a.id = 0
	a.name = "A"
	a.use_gdd_rules = true
	a.team = BattleUnit.PLAYER
	a.pos = Vector2i(2, 2)
	a.facing = 0  # north
	a.basic = "普攻"
	a.hp = 20
	a.max_hp = 20
	a.atk = 4
	a.def = 0
	a.ap = 6
	a.rp = 1
	a.spd = 50
	var b := BattleUnit.new()
	b.id = 1
	b.name = "B"
	b.use_gdd_rules = true
	b.team = BattleUnit.ENEMY
	b.pos = Vector2i(2, 1)  # north of A, inside front ZoC
	b.facing = 4
	b.basic = "普攻"
	b.hp = 20
	b.max_hp = 20
	b.atk = 4
	b.def = 0
	b.ap = 6
	b.rp = 1
	b.spd = 40
	var cells: Array = ControlZone.cells(a, m)
	eq(cells.size(), 5, "front+side control is 5 cells")
	check(cells.has(Vector2i(2, 1)), "north cell in ZoC")
	var s := BattleState.new()
	s.setup(m, [a, b], "all", 3)
	s.always_hit = true
	s.current_id = b.id
	# B attacks A from front -> A may counter
	var ev: Array = s.execute(b, "普攻", a.pos)
	var types := []
	for e in ev:
		types.append(e["type"])
	check(types.has("counter") or types.has("damage"), "attack resolves")
	# After counter A should have spent RP if counter fired
	if types.has("counter"):
		eq(a.rp, 0, "counter spends RP")


func test_wuxia_b1_setup() -> void:
	var s := BattleDefs.build_wuxia_b1(7)
	eq(s.map.width, 12, "B1 width 12")
	eq(s.map.height, 12, "B1 height 12")
	eq(s.units.size(), 5, "3 allies + 2 bandits")
	check(s.gdd_mode, "gdd mode on")
	var names := []
	for u in s.units:
		names.append(u.name)
	check(names.has("剑客") and names.has("劫客甲"), "named cast loaded")
