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
		"test_wuxia_loadouts_and_costs", "test_wuxia_resource_submission_atomicity",
		"test_wuxia_rest_and_inner_start", "test_wuxia_seal_lifecycle",
		"test_wuxia_guard_and_cangsong", "test_wuxia_block_exclusive_and_consumption",
		"test_wuxia_line_and_arc_geometry", "test_wuxia_knockback_legality",
		"test_wuxia_misses_skip_effects", "test_wuxia_lightfoot_paths_and_limits",
		"test_wuxia_lightfoot_opportunities", "test_wuxia_retreat_once_and_reactions",
		"test_wuxia_movement_cost_and_action_combos", "test_wuxia_ai_resource_and_active_skills",
		"test_wuxia_hud_skill_availability",
		"test_wuxia_hud_resources_intro_and_rounds", "test_wuxia_hud_forecast_and_control_zones",
		"test_chapter_event_conditions_and_rewards", "test_chapter_stance_once_and_failure",
		"test_chapter_save_round_trip", "test_exploration_movement_and_radius",
		"test_exploration_outdoor_reachability", "test_exploration_scene_interactions",
		"test_exploration_doors_and_collision",
		"test_exploration_battle_return_flow",
	]
	for t in tests:
		_current = t
		await call(t)
	# Let the audio thread release stopped playback before headless shutdown.
	for node in root.get_node("AudioManager").get_children():
		if node is AudioStreamPlayer:
			node.stop()
			node.stream = null
	await create_timer(0.1).timeout
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
	check(battle.info_name.get_parsed_text().contains(defender.name), "forecast inspects target in Claude unit info")
	check(battle.info_icon.visible and battle.info_hp.visible, "unit info shows class icon and HP bar")
	eq(battle.info_hp.value, float(defender.hp), "unit info HP bar comes from current unit")
	check(battle.preview_text.get_parsed_text().contains("伤害 %d" % preview["dmg"]), "rich forecast damage comes from rules preview")
	check(battle.preview_text.get_parsed_text().contains("命中 %d%%" % preview["hit"]), "rich forecast hit chance comes from rules preview")
	check(battle.preview_text.text.contains("夹击追击"), "pincer follow-up remains visible")
	check(battle.preview_panel.visible, "Claude forecast panel is visible")
	check(battle.preview_text.text.begins_with("[b]斩击[/b]  TP0"), "classic forecast shows skill and TP cost")
	eq(battle.timeline_box.get_child_count(), 8, "timeline retains eight turns")
	var turn_stack: VBoxContainer = battle.turn_label.get_parent()
	eq(battle.timeline_box.get_parent(), turn_stack, "timeline shares top panel with turn label")
	check(battle.turn_label.get_index() < battle.timeline_box.get_index(), "timeline chips follow turn label")
	var top_row: HBoxContainer = turn_stack.get_parent().get_parent()
	eq(top_row.get_index(), 0, "turn panel occupies top row")
	check(battle.turn_label.text.contains("第 1 手 · 我方回合：" + attacker.name), "turn label uses Claude wording")
	check(battle.info_text.get_parsed_text().contains("地形："), "unit info includes terrain")
	var bottom_row: HBoxContainer = battle.preview_panel.get_parent()
	eq(bottom_row.get_parent().get_child(bottom_row.get_index() - 1).get_class(), "HBoxContainer", "bottom info follows the middle row")
	var tools: VBoxContainer = bottom_row.get_parent().get_child(bottom_row.get_index() - 1).get_child(0)
	var tool_labels := ["镜头归位", "放大", "缩小", "速度×1"]
	eq(tools.get_child_count(), tool_labels.size(), "left tools use a four-button column")
	for i in tool_labels.size():
		eq(tools.get_child(i).text, tool_labels[i], "Claude tool label %d" % i)
	check(not battle.unit_nodes[attacker.id].see_through, "attacker stays readable in forecast")
	check(not battle.unit_nodes[defender.id].see_through, "defender stays readable in forecast")
	battle._enter_main()
	eq(battle.menu_title.text, "%s  TP %d/%d" % [attacker.name, attacker.tp, attacker.max_tp], "classic action menu retains TP title")
	check(not battle.preview_panel.visible, "main menu hides rich forecast")
	for button in battle.menu_box.get_children():
		check(button.custom_minimum_size.y >= 96, "battle action remains touch-sized")
	battle._inspect(defender.pos, defender)
	check(battle.info_name.get_parsed_text().contains(defender.name), "inspection selects occupied unit")
	battle._inspect(defender.pos, defender)
	check(battle.sel_ground, "same-cell second tap selects ground")
	eq(battle.info_name.get_parsed_text(), Terrain.info(battle.state.map.get_terrain(defender.pos))["name"], "ground card shows terrain")
	check(not battle.info_icon.visible and not battle.info_hp.visible, "tile info hides unit icon and HP bar")
	var terrain: String = battle.info_text.get_parsed_text()
	check(terrain.contains("地形：") and terrain.contains("高度") and terrain.contains("消耗") and terrain.contains("回避"), "tile info includes Claude terrain details")
	check(battle.unit_nodes[defender.id].see_through, "ground inspection fades its occupant")
	battle._inspect(defender.pos, defender)
	check(not battle.sel_ground, "same-cell third tap returns to unit")
	check(not battle.unit_nodes[defender.id].see_through, "unit inspection restores its occupant")
	battle._enter_target("guard")
	check(battle.info_name.get_parsed_text().contains(attacker.name), "self skill shows its subject")
	check(battle.preview_text.text.contains("自身"), "self skill describes immediate use")
	var healer: BattleUnit = null
	for unit in battle.state.units:
		if unit.cls == "healer" and unit.team == BattleUnit.PLAYER:
			healer = unit
	attacker.hp = attacker.max_hp - 7
	battle.state.current_id = healer.id
	battle._enter_target("heal")
	battle._select_target(attacker.pos)
	check(battle.info_name.get_parsed_text().contains(attacker.name), "healing inspects recipient in unit info")
	check(battle.preview_text.get_parsed_text().contains("恢复 7"), "healing preview clamps to missing HP")
	check(battle.preview_text.text.contains("→%d" % attacker.max_hp), "healing predicts capped final HP")
	var outside := Vector2i(0, 4)
	battle.cam.force_update_scroll()
	var finger: Vector2 = battle.get_viewport().get_canvas_transform() * battle.view.screen(outside, battle.state.map.get_h(outside))
	battle._on_tap(finger)
	eq(battle.sel_target, Vector2i(-1, -1), "inspecting out-of-range ground clears pending target")
	check(battle.menu_box.get_child(0).disabled, "old forecast cannot be confirmed after ground inspection")
	check(not battle.preview_text.text.contains("恢复 [color="), "ground inspection clears old healing forecast")
	battle._select_target(attacker.pos)
	# Rotating the actual scene updates geometry, arrows and the selected cursor.
	for yaw in range(4):
		battle._rotate_cam(1)
		var center: Vector2 = battle.view.screen(attacker.pos, battle.state.map.get_h(attacker.pos))
		eq(battle.view.pick(center, battle.state.map), attacker.pos, "scene picks logical cell after rotation %d" % yaw)
		eq(battle.tile_cursor.position, center, "cursor follows selected tile after rotation %d" % yaw)
	battle.free()
	game.shot = "wuxia"
	game.current_battle = "wuxia_b1"
	var wuxia = load("res://scripts/game/battle.gd").new()
	root.add_child(wuxia)
	wuxia.state.current_id = wuxia.state.living(BattleUnit.PLAYER)[0].id
	wuxia._enter_main()
	check(wuxia.state.gdd_mode, "wuxia demo retains GDD rules")
	check(wuxia.menu_title.text.contains("AP") and wuxia.menu_title.text.contains("内力"), "wuxia menu shows AP and qi")
	check(wuxia.info_text.text.contains("AP") and wuxia.info_text.text.contains("内力"), "wuxia unit info shows AP and qi")
	wuxia._on_skills()
	check(wuxia.preview_text.text.contains("AP") and wuxia.preview_text.text.contains("内力"), "wuxia rich skill list shows resource costs")
	wuxia._enter_target(wuxia.state.current().basic)
	check(wuxia.preview_text.text.contains("AP3 内力0"), "wuxia targeting shows GDD skill cost")
	wuxia.free()
	game.shot = old_shot
	game.current_battle = old_battle


func test_chapter_event_conditions_and_rewards() -> void:
	var s := ChapterState.new()
	eq(s.quest_state, ChapterState.QuestState.S0_ARRIVED, "starts arrived")
	var initial := s.to_dict()
	for event in ["ferry_battle_start", "reversal_lesson", "choose_escort", "choose_sect"]:
		check(not s.apply_event(event), "reject early " + event)
		eq(s.to_dict(), initial, "early rejection changes nothing")
	check(not s.apply_event("b1_clear", {"result": "win"}), "cannot submit B1 before quest")
	check(s.apply_event("quest_start"), "accept quest")
	eq(s.quest_state, ChapterState.QuestState.S1_TO_FERRY, "quest points to ferry")
	check(not s.apply_event("quest_start"), "quest once")
	var entry := s.to_dict()
	check(s.apply_event("ferry_battle_start"), "B1 entry available")
	eq(s.to_dict(), entry, "entry grants no rewards or flags")
	check(not s.apply_event("b1_clear"), "B1 requires a victory result")
	check(s.apply_event("b1_clear", {"result": "win"}), "submit B1 victory")
	eq(s.quest_state, ChapterState.QuestState.S2_AFTER_B1, "after-B1 objective")
	eq(s.experience, 100, "B1 exp exactly 100")
	eq(s.unlocked_manuals, ["回锋剑谱"], "B1 shared codex unlock")
	var rewarded := s.to_dict()
	check(not s.apply_event("b1_clear", {"result": "win"}), "victory cannot repeat")
	check(not s.apply_event("ferry_battle_start"), "completed ferry cannot restart")
	eq(s.to_dict(), rewarded, "revisit grants nothing")
	check(s.apply_event("reversal_lesson"), "receive lesson after B1")
	check(not s.apply_event("reversal_lesson"), "lesson cannot repeat")
	eq(s.insights, 1, "one insight only")
	check(s.apply_event("choose_escort"), "choose route")
	eq(s.quest_state, ChapterState.QuestState.S3_ROUTE_SET, "route objective")
	check(s.can_event("shrine_battle_start"), "shrine does not require B2")
	check(s.can_event("bamboo_battle_start"), "optional bamboo available")
	check(not s.complete, "minimum slice never falsely completes chapter")
	s.b3_clear = true
	s.ledger_received = true
	eq(s.quest_state, ChapterState.QuestState.S4_FINAL, "future B3 + ledger state")
	s.complete = true
	eq(s.quest_state, ChapterState.QuestState.S5_COMPLETE, "future completed state")


func test_chapter_stance_once_and_failure() -> void:
	for first in ["choose_escort", "choose_sect"]:
		var s := ChapterState.new()
		s.apply_event("quest_start")
		var before := s.to_dict()
		for result in ["lose", "timeout", "abandon", ""]:
			check(not s.apply_event("b1_clear", {"result": result}), "non-win rejected " + result)
			eq(s.to_dict(), before, "failure leaves all flags/rewards/position unchanged")
		s.apply_event("b1_clear", {"result": "win"})
		check(s.apply_event(first), "first stance permitted")
		var chosen := s.to_dict()
		for repeat in ["choose_escort", "choose_sect"]:
			check(not s.apply_event(repeat), "neither same nor other stance can repeat")
			eq(s.to_dict(), chosen, "repeat stance changes no relations")
		eq(s.escort_relation + s.sect_relation, 1, "one faction point total")
		eq(s.stance, "escort" if first == "choose_escort" else "sect", "chosen stance preserved")
		check(s.apply_event("reversal_lesson"), "lesson still available after either stance")


func test_chapter_save_round_trip() -> void:
	var path := "user://ch01_test_round_trip.json"
	var s := ChapterState.new()
	s.apply_event("quest_start")
	s.apply_event("b1_clear", {"result": "win"})
	s.apply_event("choose_sect")
	s.apply_event("reversal_lesson")
	s.scene_id = "inn"
	s.player_position = Vector2(300.25, 366.75)
	s.outdoor_return = Vector2(408, 1080)
	s.facing = "NE"
	s.visited_areas.assign(["outdoor", "inn"])
	eq(s.save_to_file(path), OK, "save atomically")
	var loaded := ChapterState.load_from_file(path)
	check(loaded != null, "load succeeds")
	if loaded != null:
		eq(loaded.to_dict(), s.to_dict(), "disk round trip preserves flags/rewards/world position")
		for event in ["quest_start", "reversal_lesson", "choose_escort", "choose_sect"]:
			check(not loaded.apply_event(event), "load cannot duplicate " + event)
		check(not loaded.apply_event("b1_clear", {"result": "win"}), "loaded B1 reward once")
		eq(loaded.to_dict(), s.to_dict(), "loaded progress immutable on replay")
	# Replacing an existing file is also supported.
	eq(s.save_to_file(path), OK, "overwrite complete save atomically")
	var bad := s.to_dict()
	bad["stance"] = "both"
	check(ChapterState.from_dict(bad) == null, "invalid stance rejected")
	bad = s.to_dict()
	bad["b1_clear"] = false
	check(ChapterState.from_dict(bad) == null, "inconsistent progress rejected")
	check(ChapterState.from_dict({}) == null, "missing/corrupt save rejected")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	var fallback := ExplorationRules.center(ExplorationRules.OUTDOOR_POINTS["explore_spawn"])
	eq(ExplorationRules.valid_spawn("outdoor", Vector2(-100, -100)), fallback, "out of bounds load falls back safely")
	eq(ExplorationRules.valid_spawn("outdoor", ExplorationRules.center(Vector2i(46, 27))), fallback, "water load falls back safely")
	eq(ExplorationRules.valid_spawn("inn", ExplorationRules.center(ExplorationRules.INN_POINTS["keeper"])), ExplorationRules.center(ExplorationRules.INN_POINTS["inn_spawn"]), "NPC-overlap load falls back safely")


func test_exploration_movement_and_radius() -> void:
	eq(ExplorationRules.movement_velocity(Vector2.ZERO), Vector2.ZERO, "no input no movement")
	for direction in [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1), Vector2(1, 1), Vector2(1, -1), Vector2(-1, 1), Vector2(-1, -1)]:
		check(is_equal_approx(ExplorationRules.movement_velocity(direction).length(), ExplorationRules.SPEED), "all eight directions have same speed " + str(direction))
	var p := Vector2(400.5, 700.25)
	check(ExplorationRules.in_interaction_radius(p, p), "interaction at center")
	check(ExplorationRules.in_interaction_radius(p, p + Vector2(70, 0)), "interaction boundary included")
	check(not ExplorationRules.in_interaction_radius(p, p + Vector2(70.1, 0)), "outside radius excluded")
	check(not ExplorationRules.in_interaction_radius(p, p + Vector2(50, 50)), "radius is circular")


func _exploration_reachable(rows: Array[String], start: Vector2i) -> Dictionary:
	var reached := {start: true}
	var queue: Array[Vector2i] = [start]
	var index := 0
	# Four-neighbor BFS is stricter than continuous diagonal walking, so corner cuts cannot help.
	while index < queue.size():
		var point := queue[index]
		index += 1
		for direction in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var next: Vector2i = point + direction
			if not reached.has(next) and not ExplorationRules.is_blocked(rows, next):
				reached[next] = true
				queue.append(next)
	return reached


func test_exploration_outdoor_reachability() -> void:
	var rows := ExplorationRules.grid("outdoor")
	eq(rows.size(), 30, "outdoor 30 high")
	for row in rows:
		eq(row.length(), 48, "outdoor 48 wide")
	var reached := _exploration_reachable(rows, ExplorationRules.OUTDOOR_POINTS["explore_spawn"])
	for key in ["inn_door", "ferry_event", "bamboo_event", "shrine_event"]:
		var cell: Vector2i = ExplorationRules.OUTDOOR_POINTS[key]
		check(reached.has(cell), "spawn to " + key + " uses no wall/water")
		check(ExplorationRules.safe_position(rows, ExplorationRules.center(cell)), "player clearance at " + key)
	check(ExplorationRules.is_blocked(rows, Vector2i(46, 27)), "river solid")
	check(ExplorationRules.is_blocked(rows, Vector2i(5, 19)), "inn wall solid")
	check(ExplorationRules.is_blocked(rows, Vector2i(22, 5)), "forest solid")
	check(not ExplorationRules.is_blocked(rows, Vector2i(41, 23)), "wooden bridge passable")
	var inn := ExplorationRules.grid("inn")
	eq(inn.size(), 10, "inn 10 high")
	eq(inn[0].length(), 14, "inn 14 wide")
	var indoor_reached := _exploration_reachable(inn, ExplorationRules.INN_POINTS["inn_spawn"])
	for cell in ExplorationRules.INN_POINTS.values():
		check(indoor_reached.has(cell), "inn target accessible " + str(cell))


func test_exploration_scene_interactions() -> void:
	var game = root.get_node("Game")
	var old_chapter: ChapterState = game.chapter
	var old_shot: String = game.shot
	# These scene tests use screenshot isolation, never the player's save.
	game.shot = "inn"
	game.chapter = ChapterState.new()
	game.chapter.scene_id = "inn"
	game.chapter.player_position = ExplorationRules.center(ExplorationRules.INN_POINTS["inn_spawn"])
	var scene = load("res://scenes/explore.tscn").instantiate()
	root.add_child(scene)
	check(not scene.interact("keeper"), "scene rejects remote interaction")
	scene.player.position = ExplorationRules.center(ExplorationRules.INN_POINTS["keeper"]) + Vector2(0, 42)
	check(scene.interact("keeper"), "near keeper opens dialogue")
	check(not game.chapter.quest_accepted, "opening dialogue never accepts quest")
	scene._close_dialogue()
	check(not game.chapter.quest_accepted, "cancel confirmation preserves flags")
	scene.interact("keeper")
	scene.modal_action.call()
	check(game.chapter.quest_accepted, "confirmed keeper accepts quest")
	game.chapter.apply_event("b1_clear", {"result": "win"})
	scene.player.position = ExplorationRules.center(ExplorationRules.INN_POINTS["meng"]) + Vector2(0, 42)
	scene._close_dialogue()
	scene.interact("meng")
	check(game.chapter.stance == "", "stance needs confirmation")
	scene.modal_action.call()
	eq(game.chapter.stance, "escort", "M confirmation selects escort")
	scene.player.position = ExplorationRules.center(ExplorationRules.INN_POINTS["luo"]) + Vector2(0, 42)
	scene.interact("luo")
	check(not scene.modal_action.is_valid(), "N cannot change existing stance")
	scene.player.position = ExplorationRules.center(ExplorationRules.INN_POINTS["training"]) + Vector2(0, 42)
	scene.interact("training")
	scene.modal_action.call()
	scene.interact("training")
	eq(game.chapter.insights, 1, "scene lesson awarded once")
	check(not scene.modal_action.is_valid(), "scene repeat lesson has no reward action")
	scene.player.position = ExplorationRules.center(ExplorationRules.INN_POINTS["codex"]) + Vector2(0, 42)
	scene.interact("codex")
	check(scene.modal_title.text.contains("队伍已收录"), "codex first shows shared collection")
	check(scene.modal_text.text.contains("回锋剑谱"), "collected sword manual visible")
	scene.free()
	game.chapter = old_chapter
	game.shot = old_shot


func test_exploration_doors_and_collision() -> void:
	var game = root.get_node("Game")
	var old_chapter: ChapterState = game.chapter
	var old_shot: String = game.shot
	game.shot = "explore"
	game.chapter = ChapterState.new()
	var door_entry := ExplorationRules.center(ExplorationRules.OUTDOOR_POINTS["inn_door"]) + Vector2(0, 42)
	game.chapter.player_position = door_entry
	var scene = load("res://scenes/explore.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	check(scene.interact("inn_door"), "walk to door to enter inn")
	await scene_changed
	scene = current_scene
	eq(game.chapter.scene_id, "inn", "door loads inn")
	eq(scene.player.position, ExplorationRules.center(ExplorationRules.INN_POINTS["inn_spawn"]), "inn safe spawn")
	eq(game.chapter.outdoor_return, door_entry, "outdoor return position remembered")
	# Real physics: movement is fractional world motion and solid NPC feet stop it.
	Input.action_press("explore_up")
	var start: Vector2 = scene.player.position
	for i in 3:
		await physics_frame
	check(scene.player.position.y < start.y and scene.player.position.y > start.y - ExplorationRules.TILE, "continuous partial-tile movement")
	Input.action_release("explore_up")
	scene.player.position = ExplorationRules.center(Vector2i(6, 4))
	Input.action_press("explore_up")
	for i in 18:
		await physics_frame
	Input.action_release("explore_up")
	check(scene.player.position.y >= 168 + 24 - 0.1, "keeper collision prevents body overlap")
	scene.player.position = Vector2(60, 250)
	Input.action_press("explore_left")
	for i in 10:
		await physics_frame
	Input.action_release("explore_left")
	check(scene.player.position.x >= 58 - 0.1, "physical inn wall stops movement")
	scene._show_journal()
	var paused: Vector2 = scene.player.position
	Input.action_press("explore_right")
	for i in 3:
		await physics_frame
	Input.action_release("explore_right")
	eq(scene.player.position, paused, "dialogue/log pauses movement")
	scene._close_dialogue()
	scene.player.position = ExplorationRules.center(ExplorationRules.INN_POINTS["exit"]) - Vector2(0, 36)
	check(scene.interact("exit"), "walk to exit to return outdoors")
	await scene_changed
	scene = current_scene
	eq(game.chapter.scene_id, "outdoor", "exit loads outdoor")
	eq(scene.player.position, door_entry, "door restores saved world position")
	var river_edge := 42 * ExplorationRules.TILE
	scene.player.position = Vector2(river_edge - 12, 1320)
	Input.action_press("explore_right")
	for i in 18:
		await physics_frame
	Input.action_release("explore_right")
	check(scene.player.position.x <= river_edge - ExplorationRules.BODY_RADIUS + 0.1, "physical river collision stops movement")
	var half_view: Vector2 = scene.get_viewport_rect().size / scene.camera.zoom / 2
	var map_size := Vector2(48, 30) * ExplorationRules.TILE
	check(scene.camera.position.x >= half_view.x and scene.camera.position.x <= map_size.x - half_view.x, "camera constrained horizontally")
	if map_size.y >= half_view.y * 2:
		check(scene.camera.position.y >= half_view.y and scene.camera.position.y <= map_size.y - half_view.y, "camera constrained vertically")
	else:
		eq(scene.camera.position.y, map_size.y / 2, "camera centers maps smaller than viewport")
	scene.player.position = ExplorationRules.center(ExplorationRules.OUTDOOR_POINTS["bamboo_event"]) + Vector2(0, 38)
	scene.interact("bamboo_event")
	check(scene.modal_title.text.contains("线索不足"), "bamboo reachable before quest unlock")
	game.chapter.apply_event("quest_start")
	game.chapter.apply_event("b1_clear", {"result": "win"})
	game.chapter.apply_event("choose_sect")
	scene.interact("bamboo_event")
	check(scene.modal_text.text.contains("后续开放"), "eligible bamboo shows later opening")
	scene.player.position = ExplorationRules.center(ExplorationRules.OUTDOOR_POINTS["shrine_event"]) + Vector2(0, 38)
	scene.interact("shrine_event")
	check(scene.modal_text.text.contains("无需先去竹林"), "shrine never requires B2")
	check(game.chapter.visited_areas.has("inn") and game.chapter.visited_areas.has("outdoor"), "area first-visit names recorded")
	scene.queue_free()
	current_scene = null
	await process_frame
	game.chapter = old_chapter
	game.shot = old_shot


func test_exploration_battle_return_flow() -> void:
	var game = root.get_node("Game")
	var old_chapter: ChapterState = game.chapter
	var old_shot: String = game.shot
	var old_battle: String = game.current_battle
	var old_step: int = game.step
	var old_loaded: bool = game.chapter_loaded
	game.shot = "explore"
	game.step = 4
	for result in ["lose", "win"]:
		game.chapter = ChapterState.new()
		game.chapter.apply_event("quest_start")
		game.chapter.player_position = ExplorationRules.center(Vector2i(37, 23)) + Vector2(-16, -14)
		game.chapter.visited_areas.assign(["outdoor"])
		game.chapter.facing = "SW"
		var entry: Dictionary = game.chapter.to_dict()
		check(game.begin_ferry_battle(game.chapter.player_position), "exploration enters real B1")
		check(game.is_exploration_battle(), "battle origin recorded")
		eq(game.chapter.to_dict(), entry, "entry does not change chapter progress")
		await scene_changed
		var battle = current_scene
		eq(battle.get_script().resource_path, "res://scripts/game/battle.gd", "existing battle scene loaded")
		eq(game.current_battle, "wuxia_b1", "correct wuxia battle")
		if is_instance_valid(battle.overlay):
			battle.overlay.queue_free()
			battle.overlay = null
		battle._finish(result)
		eq(game.chapter.to_dict(), entry, "result display does not grant early rewards")
		battle.overlay_confirm.call()
		await scene_changed
		var explore = current_scene
		eq(explore.get_script().resource_path, "res://scripts/game/explore.gd", "result returns to exploration scene")
		eq(game.step, 4, "exploration return leaves story FLOW unchanged")
		check(not game.is_exploration_battle(), "battle origin consumed once")
		if result == "lose":
			eq(game.chapter.to_dict(), entry, "defeat restores entire entry snapshot")
			eq(explore.player.position, Vector2(entry["player_position"][0], entry["player_position"][1]), "defeat returns to exact entry world position")
		else:
			check(game.chapter.b1_clear, "scene victory submits B1 flag")
			eq(game.chapter.experience, 100, "scene victory records 100 exp")
			eq(game.chapter.unlocked_manuals, ["回锋剑谱"], "scene victory records shared manual")
			eq(explore.player.position, ExplorationRules.center(Vector2i(37, 22)), "victory returns to GDD safe position")
			check(not game.begin_ferry_battle(explore.player.position), "completed B1 cannot reopen")
		var once: Dictionary = game.chapter.to_dict()
		check(not game.finish_exploration_battle("win"), "double result callback rejected")
		eq(game.chapter.to_dict(), once, "double callback grants no extra rewards")
		explore.queue_free()
		current_scene = null
		await process_frame
	# Classic and directly launched battle results retain the original story callback.
	game.current_battle = "b1"
	var classic = load("res://scenes/battle.tscn").instantiate()
	root.add_child(classic)
	if is_instance_valid(classic.overlay):
		classic.overlay.queue_free()
		classic.overlay = null
	classic._finish("win")
	eq(classic.overlay_confirm, Callable(game, "advance"), "classic win still advances story")
	classic.free()
	game.chapter = old_chapter
	game.shot = old_shot
	game.current_battle = old_battle
	game.step = old_step
	game.chapter_loaded = old_loaded
	game.explore_notice = ""
	await process_frame


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
	s.living(BattleUnit.PLAYER)[0].hp = 0
	eq(s.outcome(), "", "B1 continues when swordsman falls but allies survive")
	for u in s.living(BattleUnit.PLAYER):
		u.hp = 0
	eq(s.outcome(), "lose", "B1 all-party defeat matches objective text")
	s = BattleDefs.build_wuxia_b1(7)
	for u in s.living(BattleUnit.ENEMY):
		u.hp = 0
	eq(s.outcome(), "win", "B1 victory requires all bandits defeated")


# GDD 4.4–4.7 / 6.4: deterministic B1 martial-art acceptance tests.
func wuxia_unit(id: int, team: int, pos: Vector2i) -> BattleUnit:
	var u := BattleUnit.new()
	u.id = id
	u.name = "武者%d" % id
	u.use_gdd_rules = true
	u.team = team
	u.pos = pos
	u.hp = 100
	u.max_hp = 100
	u.atk = 4
	u.spd = 60 - id
	u.basic = "普攻"
	u.skills = ["破风剑", "回锋剑", "横江刀", "震山掌", "截脉指", "守关式", "燕行步", "踏雪步", "防御", "调息"]
	return u


func force_next_wuxia_miss(s: BattleState) -> void:
	# Pick a seed whose next roll exceeds even the 95% hit cap.
	var probe := RandomNumberGenerator.new()
	for seed_value in range(10000):
		probe.seed = seed_value
		if probe.randi_range(1, 100) > 95:
			s.rng.seed = seed_value
			s.always_hit = false
			return
	check(false, "a deterministic miss seed exists")


func event_count(events: Array, kind: String) -> int:
	var count := 0
	for e in events:
		if e["type"] == kind:
			count += 1
	return count


func test_wuxia_loadouts_and_costs() -> void:
	var s := BattleDefs.build_wuxia_b1()
	var raw: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/wuxia/b1_combat.json"))
	var seen := {}
	var seen_inners := {}
	var seen_lightfoot := {}
	for u in s.living(BattleUnit.PLAYER):
		eq(u.active_skills.size(), 3, "B1 has three active slots")
		eq(u.active_skills, raw["units"][u.id]["skills"], "active slots loaded from JSON")
		eq(u.inner, raw["units"][u.id]["inner"], "inner slot loaded from JSON")
		eq(u.lightfoot, raw["units"][u.id]["lightfoot"], "lightfoot slot loaded from JSON")
		check(not SkillDB.get_inner(u.inner).is_empty(), "inner has data")
		check(u.skills.has(u.lightfoot) and not u.skills.has(u.inner), "lightfoot is usable and inner is passive")
		eq(u.all_actions().size(), 7, "three active + lightfoot + basic/rest/block")
		for sid in u.active_skills:
			seen[sid] = true
		seen_inners[u.inner] = true
		seen_lightfoot[u.lightfoot] = true
	for sid in ["破风剑", "回锋剑", "横江刀", "震山掌", "截脉指", "守关式"]:
		check(seen.has(sid), "B1 exposes active " + sid)
	eq(seen_inners.size(), 2, "both inners equipped")
	eq(seen_lightfoot.size(), 2, "both lightfoot arts equipped")
	eq(s.units[0].weapon, "sword", "sword loadout")
	eq(s.units[1].weapon, "spear", "spear loadout")
	eq(s.units[2].weapon, "fist", "fist loadout")
	var costs := {"破风剑": [4, 3], "回锋剑": [3, 2], "横江刀": [4, 3], "震山掌": [4, 3], "截脉指": [4, 4], "守关式": [2, 2], "燕行步": [2, 4], "踏雪步": [2, 3], "防御": [2, 0], "调息": [3, 0]}
	for sid in costs:
		var sk := SkillDB.get_skill(sid)
		eq([int(sk["ap"]), int(sk["qi"])], costs[sid], "GDD costs " + sid)
	eq(int(SkillDB.get_skill("截脉指")["rmax"]), 1, "seal is adjacent only")


func test_wuxia_resource_submission_atomicity() -> void:
	# GDD 6.4 #3: every command rejects insufficient resources before all mutations.
	for sid in ["普攻", "破风剑", "回锋剑", "横江刀", "震山掌", "截脉指", "守关式", "燕行步", "踏雪步", "防御", "调息"]:
		var u := wuxia_unit(0, 0, Vector2i(2, 2))
		var t := wuxia_unit(1, 1, Vector2i(3, 2))
		var s := state_with(BattleMap.flat(7, 7), [u, t])
		var sk := SkillDB.get_skill(sid)
		var tile := u.pos if sk["shape"] == "self" else (Vector2i(2, 3) if sk["shape"] == "leap" else t.pos)
		for resource in ["ap", "qi"]:
			if int(sk.get(resource, 0)) == 0:
				continue
			u.ap = 6
			u.qi = 12
			u.set(resource, int(sk[resource]) - 1)
			var snapshot := [u.ap, u.qi, u.pos, u.facing, t.hp, s.acted, u.used_skills.duplicate()]
			check(not s.skill_usable(u, sid), sid + " insufficient " + resource)
			check(not s.is_valid_target(u, sid, tile), sid + " cannot submit " + resource)
			eq(s.execute(u, sid, tile), [], sid + " no events on rejection")
			eq([u.ap, u.qi, u.pos, u.facing, t.hp, s.acted, u.used_skills], snapshot, sid + " rejection leaves state intact")
	var a := wuxia_unit(0, 0, Vector2i(1, 1))
	var state := state_with(BattleMap.flat(3, 3), [a])
	for bad in [Vector2i(-1, 1), Vector2i(8, 8), a.pos]:
		eq(state.execute(a, "燕行步", bad), [], "invalid leap rejected before payment")
	eq([a.ap, a.qi, state.acted, a.used_skills.size()], [6, 12, false, 0], "invalid landings consume nothing")
	a.skills.erase("守关式")
	check(not state.skill_usable(a, "守关式"), "unequipped art cannot be submitted")
	eq(state.execute(a, "守关式", a.pos), [], "unequipped art cannot be executed")


func test_wuxia_rest_and_inner_start() -> void:
	# GDD 6.4 #4: rest is once per own action, even at cap; resets next action.
	var u := wuxia_unit(0, 0, Vector2i(1, 1))
	u.inner = "归元诀"
	var s := state_with(BattleMap.flat(3, 3), [u])
	u.qi = 3
	s.begin_next_turn()
	eq(u.qi, 5, "Guiyuan adds one beyond base recovery")
	s.execute(u, "调息", u.pos)
	eq([u.ap, u.qi], [3, 9], "rest costs 3 AP and restores 4 qi")
	check(not s.skill_usable(u, "调息"), "rest disabled after use")
	eq(s.execute(u, "调息", u.pos), [], "second rest rejected")
	eq([u.ap, u.qi], [3, 9], "second rest consumes nothing")
	s.end_turn()
	s.begin_next_turn()
	check(s.skill_usable(u, "调息"), "rest resets on own next action")
	s.execute(u, "调息", u.pos)
	eq(u.qi, 12, "rest does not exceed cap")
	s.end_turn()
	s.begin_next_turn()
	eq(u.qi, 12, "Guiyuan recovery does not exceed cap")
	s.execute(u, "调息", u.pos)
	eq(u.ap, 3, "rest at cap still costs AP")
	check(not s.skill_usable(u, "调息"), "rest at cap still consumes its one use")
	u.inner = ""
	u.qi = 0
	s.end_turn()
	s.begin_next_turn()
	eq(u.qi, 1, "base recovery without inner is exactly one")


func test_wuxia_seal_lifecycle() -> void:
	# GDD 6.4 #5: pending penalty does not stack; active status clears at action end.
	var a := wuxia_unit(0, 0, Vector2i(2, 2))
	var b := wuxia_unit(1, 1, Vector2i(3, 2))
	b.rp = 0
	var s := state_with(BattleMap.flat(5, 5), [a, b])
	s.begin_next_turn()
	s.execute(a, "截脉指", b.pos)
	eq(b.ap_penalty, 2, "hit queues -2 AP")
	eq(b.ap, 6, "seal does not reduce current AP")
	a.ap = 6
	s.execute(a, "截脉指", b.pos)
	eq(b.ap_penalty, 2, "repeated seal does not stack")
	s.end_turn()
	eq(s.begin_next_turn()["unit"], b, "target obtains own action")
	eq(b.ap, 4, "next own action has 4 AP")
	check(b.qi_blocked, "seal remains visible throughout affected action")
	eq(b.ap_penalty, 0, "pending penalty consumed once")
	s.end_turn()
	check(not b.qi_blocked, "seal clears at affected action end")
	s.begin_next_turn()
	s.end_turn()
	s.begin_next_turn()
	eq(b.ap, 6, "subsequent action restores full AP")
	check(not b.qi_blocked, "seal does not persist into another action")


func test_wuxia_guard_and_cangsong() -> void:
	# GDD 6.4 #6: repeated sources retain one layer and expire only on owner's start.
	var a := wuxia_unit(0, 0, Vector2i(2, 2))
	var b := wuxia_unit(1, 1, Vector2i(3, 2))
	var s := state_with(BattleMap.flat(5, 5), [a, b])
	a.inner = "苍松功"
	s.begin_next_turn()
	s.execute(a, "守关式", a.pos)
	s.execute(a, "守关式", a.pos)
	eq(a.ap, 2, "two guard casts leave exactly 2 AP")
	s.end_turn()
	check(a.guard and a.used_skills.get("inner_end", false), "Cangsong triggers at exactly 2 AP")
	s.begin_next_turn()
	check(a.guard, "another unit's start does not expire guard")
	var expected := Combat.gdd_calc(b, a, SkillDB.get_skill("普攻"), s.map, b.pos)
	eq(expected["dmg"], 9, "multiple guard sources only reduce 12 damage to 9")
	a.rp = 0
	var hp := a.hp
	s.execute(b, "普攻", a.pos)
	eq(hp - a.hp, 9, "guard reduces the next hit by 25 percent")
	check(not a.guard, "guard consumed after one hit")
	hp = a.hp
	s.execute(b, "普攻", a.pos)
	eq(hp - a.hp, 12, "next hit receives full damage")
	a.gain_guard()
	s.end_turn()
	s.begin_next_turn()
	check(not a.guard, "unused guard expires at owner's next start")
	a.ap = 1
	s.end_turn()
	check(not a.guard, "Cangsong does not trigger below 2 AP")
	s.end_turn()
	check(not a.guard, "duplicate end_turn has no effect")


func test_wuxia_block_exclusive_and_consumption() -> void:
	# GDD 6.4 #21: basic block is 2AP/0qi, +2 armor for one hit, exclusive with guard.
	var a := wuxia_unit(0, 0, Vector2i(2, 2))
	var b := wuxia_unit(1, 1, Vector2i(3, 2))
	var s := state_with(BattleMap.flat(5, 5), [a, b])
	a.qi = 0
	s.execute(a, "防御", a.pos)
	eq([a.ap, a.qi], [4, 0], "basic block costs only 2 AP")
	check(a.block and not a.guard, "basic defense grants block")
	eq(Combat.gdd_calc(b, a, SkillDB.get_skill("普攻"), s.map, b.pos)["dmg"], 10, "block adds exactly 2 armor")
	a.rp = 0
	force_next_wuxia_miss(s)
	s.execute(b, "普攻", a.pos)
	check(a.block, "miss does not consume block")
	b.ap = 6
	s.always_hit = true
	var hp := a.hp
	s.execute(b, "普攻", a.pos)
	eq(hp - a.hp, 10, "block applies to one hit")
	check(not a.block, "block removed after effective hit")
	hp = a.hp
	s.execute(b, "普攻", a.pos)
	eq(hp - a.hp, 12, "second hit has no block armor")
	a.ap = 6
	a.qi = 12
	s.execute(a, "守关式", a.pos)
	s.execute(a, "防御", a.pos)
	check(a.block and not a.guard, "later block replaces guard")
	s.execute(a, "守关式", a.pos)
	check(a.guard and not a.block, "later guard replaces block")
	eq(Combat.gdd_calc(b, a, SkillDB.get_skill("普攻"), s.map, b.pos)["dmg"], 9, "guard does not also gain block armor")
	a.gain_block()
	s.begin_next_turn()
	check(not a.block, "unused block expires on own start")
	a.gain_block()
	a.inner = "苍松功"
	s.end_turn()
	check(a.guard and not a.block, "Cangsong replaces block with one guard")


func test_wuxia_line_and_arc_geometry() -> void:
	# GDD 6.4 #7: line preview and execution both stop at walls, in all eight axes.
	for facing in range(8):
		var m := BattleMap.flat(11, 11)
		var a := wuxia_unit(0, 0, Vector2i(5, 5))
		var d: Vector2i = BattleMap.DIRS[facing]
		var near := wuxia_unit(1, 1, a.pos + d)
		var far := wuxia_unit(2, 1, a.pos + d * 3)
		var s := state_with(m, [a, near, far])
		m.set_terrain(a.pos + d * 2, "wall")
		eq(s.preview(a, "破风剑", near.pos).size(), 1, "wall removes targets behind line " + str(facing))
		check(not s.target_tiles(a, "破风剑", a.pos).has(far.pos), "range excludes behind-wall line target")
		s.execute(a, "破风剑", near.pos)
		check(near.hp < 100, "line hits before wall")
		eq(far.hp, 100, "line cannot hit through wall")
		m.set_terrain(a.pos + d * 2, "grass")
		a.ap = 6
		eq(s.preview(a, "破风剑", near.pos).size(), 2, "line reaches multiple targets without wall")
		var sk := SkillDB.get_skill("横江刀")
		var arc := Combat.affected_tiles(sk, a.pos, a.pos + d, m)
		var expected: Array = []
		for offset in [-1, 0, 1]:
			expected.append(a.pos + BattleMap.DIRS[posmod(facing + offset, 8)])
		eq(arc, expected, "sweep covers three consecutive neighbors for facing " + str(facing))
	# All three legal enemies are hit; an ally and rear enemy are excluded.
	var a := wuxia_unit(0, 0, Vector2i(3, 3))
	var units: Array = [a]
	for i in range(8):
		units.append(wuxia_unit(i + 1, 1, a.pos + BattleMap.DIRS[i]))
	var s := state_with(BattleMap.flat(7, 7), units)
	var ev := s.execute(a, "横江刀", a.pos + BattleMap.DIRS[0])
	eq(event_count(ev, "damage"), 3, "sweep hits all three front targets")
	eq(event_count(ev, "counter"), 0, "sweep has no single-target counters")
	for i in range(8):
		eq(units[i + 1].hp < 100, i in [7, 0, 1], "sweep only damages its arc")
	units[8].team = 0
	a.ap = 6
	a.qi = 12
	eq(s.preview(a, "横江刀", a.pos + BattleMap.DIRS[0]).size(), 2, "sweep excludes friendly units")
	s.map.set_terrain(a.pos + BattleMap.DIRS[1], "wall")
	eq(s.preview(a, "横江刀", a.pos + BattleMap.DIRS[0]).size(), 1, "sweep excludes obstructed neighbor")


func test_wuxia_knockback_legality() -> void:
	# GDD 6.4 #7: invalid forced landing causes only base damage, never collision damage.
	for block_kind in ["wall", "crate", "water", "occupied", "edge", "corner", "legal", "diagonal"]:
		var a := wuxia_unit(0, 0, Vector2i(1, 1))
		var b := wuxia_unit(1, 1, Vector2i(2, 1))
		var m := BattleMap.flat(5, 5)
		var units: Array = [a, b]
		var dest := Vector2i(3, 1)
		if block_kind in ["diagonal", "corner"]:
			b.pos = Vector2i(2, 2)
			dest = Vector2i(3, 3)
		if block_kind == "edge":
			a.pos = Vector2i(3, 1)
			b.pos = Vector2i(4, 1)
		elif block_kind == "occupied":
			units.append(wuxia_unit(2, 1, dest))
		elif block_kind == "corner":
			m.set_terrain(Vector2i(3, 2), "wall")
			m.set_terrain(Vector2i(2, 3), "wall")
		elif block_kind in ["wall", "crate", "water"]:
			m.set_terrain(dest, block_kind)
		var origin := b.pos
		var s := state_with(m, units)
		b.rp = 0
		var ev := s.execute(a, "震山掌", b.pos)
		eq(b.hp, 88, block_kind + " only base damage, no collision or falling damage")
		eq(b.pos, dest if block_kind in ["legal", "diagonal"] else origin, block_kind + " legal forced landing")
		eq(event_count(ev, "collide"), 0, "GDD push never creates collide damage")
		eq(event_count(ev, "opportunity"), 0, "forced displacement never triggers leaving reaction")


func test_wuxia_misses_skip_effects() -> void:
	for sid in ["震山掌", "截脉指", "破风剑"]:
		var a := wuxia_unit(0, 0, Vector2i(2, 2))
		var b := wuxia_unit(1, 1, Vector2i(3, 2))
		b.gain_guard()
		b.rp = 0
		var s := state_with(BattleMap.flat(6, 6), [a, b])
		force_next_wuxia_miss(s)
		var ev := s.execute(a, sid, b.pos)
		eq(event_count(ev, "miss"), 1, sid + " deterministic miss")
		eq([b.hp, b.pos, b.ap_penalty, b.guard], [100, Vector2i(3, 2), 0, true], sid + " miss has no damage/push/seal/guard consumption")
		var sk := SkillDB.get_skill(sid)
		eq([a.ap, a.qi], [6 - int(sk["ap"]), 12 - int(sk["qi"])], sid + " misses still pay declared costs")


func test_wuxia_lightfoot_paths_and_limits() -> void:
	# GDD 6.4 #2: Yanxing crosses low barriers; neither art crosses a complete wall.
	for obstacle in ["crate", "low_wall", "gap", "water", "wall"]:
		var m := BattleMap.flat(5, 5)
		for y in range(5):
			m.set_terrain(Vector2i(2, y), obstacle)
		var a := wuxia_unit(0, 0, Vector2i(1, 2))
		var s := state_with(m, [a])
		var landing := Vector2i(3, 2)
		eq(s.is_valid_target(a, "燕行步", landing), obstacle != "wall", "Yanxing crossing " + obstacle)
		check(not s.is_valid_target(a, "踏雪步", landing), "Taxue cannot cross " + obstacle)
		check(not s.is_valid_target(a, "燕行步", Vector2i(2, 2)), "cannot land on " + obstacle)
		if obstacle == "wall":
			eq(s.execute(a, "燕行步", landing), [], "cannot submit leap through wall")
			eq([a.ap, a.qi], [6, 12], "blocked leap costs nothing")
		else:
			s.execute(a, "燕行步", landing)
			eq(a.pos, landing, "Yanxing lands across low barrier")
			eq([a.ap, a.qi], [4, 8], "Yanxing pays flat 2AP/4qi")
	# Full wall corner is sealed even when the desired landing is walkable.
	var m := BattleMap.flat(4, 4)
	m.set_terrain(Vector2i(1, 0), "wall")
	m.set_terrain(Vector2i(0, 1), "wall")
	var a := wuxia_unit(0, 0, Vector2i.ZERO)
	var s := state_with(m, [a])
	check(not s.is_valid_target(a, "燕行步", Vector2i(1, 1)), "Yanxing cannot cut sealed wall corner")
	for sid in ["燕行步", "踏雪步"]:
		var u := wuxia_unit(0, 0, Vector2i(3, 3))
		var state := state_with(BattleMap.flat(9, 9), [u])
		state.begin_next_turn()
		var distance := 3 if sid == "燕行步" else 2
		var dest := u.pos + Vector2i(distance, distance)
		check(state.target_tiles(u, sid, u.pos).has(dest), sid + " reaches diagonal Chebyshev limit")
		check(not state.target_tiles(u, sid, u.pos).has(u.pos + Vector2i(distance + 1, 0)), sid + " excludes beyond range")
		var ev := state.execute(u, sid, dest)
		eq(u.pos, dest, sid + " reaches selected landing")
		eq(u.ap, 4, sid + " distance adds no per-cell AP")
		eq(u.guard, sid == "踏雪步", sid + " landing guard only for Taxue")
		eq(event_count(ev, "leap"), distance, sid + " exposes traversed path for animation")
		check(not state.skill_usable(u, sid), sid + " once per action")
		eq(state.execute(u, sid, Vector2i(3, 3)), [], sid + " repeat cannot be submitted")
		state.end_turn()
		state.begin_next_turn()
		check(state.skill_usable(u, sid), sid + " use resets next action")
		check(not u.guard, sid + " unused guard expires on own next action")
	# Occupied intermediate and landing cells cannot be traversed or targeted.
	var u := wuxia_unit(0, 0, Vector2i(0, 0))
	var blocker := wuxia_unit(1, 0, Vector2i(1, 0))
	var state := state_with(BattleMap.flat(4, 1), [u, blocker])
	for sid in ["燕行步", "踏雪步"]:
		check(not state.is_valid_target(u, sid, blocker.pos), sid + " occupied landing excluded")
		check(not state.is_valid_target(u, sid, Vector2i(2, 0)), sid + " occupied corridor blocked")


func test_wuxia_lightfoot_opportunities() -> void:
	# GDD 6.4 #14: Yanxing is exempt; Taxue settles opportunity BEFORE landing guard.
	for sid in ["燕行步", "踏雪步"]:
		var a := wuxia_unit(0, 0, Vector2i(2, 2))
		var b := wuxia_unit(1, 1, Vector2i(2, 1))
		b.facing = 4
		var s := state_with(BattleMap.flat(6, 6), [a, b])
		var ev := s.execute(a, sid, Vector2i(2, 4))
		var immune: bool = sid == "燕行步"
		eq(event_count(ev, "opportunity"), 0 if immune else 1, sid + " declared opportunity rule")
		eq(b.rp, 1 if immune else 0, sid + " reactor RP")
		eq(a.hp, 100 if immune else 88, sid + " reaction is before landing guard")
		eq(a.pos, Vector2i(2, 4), sid + " completes displacement")
		eq(a.guard, not immune, sid + " Taxue gains guard after landing")
	var a := wuxia_unit(0, 0, Vector2i(2, 2))
	var b := wuxia_unit(1, 1, Vector2i(2, 1))
	b.facing = 4
	a.hp = 1
	var s := state_with(BattleMap.flat(6, 6), [a, b])
	var ev := s.execute(a, "踏雪步", Vector2i(2, 4))
	check(not a.alive(), "lethal opportunity defeats Taxue mover")
	eq(a.pos, Vector2i(2, 2), "lethal opportunity stops before departing")
	check(not a.guard, "interrupted Taxue does not receive landing guard")
	eq([a.ap, a.qi], [4, 9], "submitted interrupted Taxue still pays fixed cost")
	eq(event_count(ev, "leap"), 0, "dead mover has no movement playback")


func test_wuxia_retreat_once_and_reactions() -> void:
	var a := wuxia_unit(0, 0, Vector2i(3, 3))
	var b := wuxia_unit(1, 1, Vector2i(4, 3))
	b.facing = 6
	var s := state_with(BattleMap.flat(8, 8), [a, b])
	s.begin_next_turn()
	var ev := s.execute(a, "回锋剑", b.pos)
	eq(a.pos, Vector2i(2, 3), "Huifeng retreats one adjacent tile")
	eq([a.ap, a.qi], [3, 10], "retreat adds no AP/qi cost")
	eq(event_count(ev, "opportunity"), 1, "Huifeng retreat is not implicitly safe")
	eq(event_count(ev, "counter"), 0, "retreat out of range prevents later counter")
	b.pos = Vector2i(3, 3)
	s.execute(a, "回锋剑", b.pos)
	eq(a.pos, Vector2i(2, 3), "second attack does not retreat again")
	s.end_turn()
	s.begin_next_turn()
	s.end_turn()
	s.begin_next_turn()
	eq(a.used_skills.size(), 0, "retreat usage resets at own action start")
	b.rp = 0
	s.map.set_terrain(Vector2i(1, 3), "wall")
	ev = s.execute(a, "回锋剑", b.pos)
	eq(a.pos, Vector2i(2, 3), "retreat cannot enter blocked landing")
	eq(event_count(ev, "damage"), 1, "blocked retreat still attacks normally")


func test_wuxia_movement_cost_and_action_combos() -> void:
	var m := BattleMap.flat(6, 4)
	var a := wuxia_unit(0, 0, Vector2i(1, 1))
	var b := wuxia_unit(1, 1, Vector2i(3, 2))
	b.rp = 0
	var s := state_with(m, [a, b])
	s.begin_next_turn()
	m.set_terrain(Vector2i(2, 2), "mud")
	s.move_unit(a, Vector2i(2, 2))
	eq(a.ap, 4, "GDD #2 mud costs 2 AP")
	s.execute(a, "普攻", b.pos)
	eq(a.ap, 1, "attack can follow movement")
	s.move_unit(a, Vector2i(1, 2))
	eq(a.ap, 0, "movement can follow attack in same action")
	eq(a.pos, Vector2i(1, 2), "move/attack/move reaches final tile")


func test_wuxia_ai_resource_and_active_skills() -> void:
	var a := wuxia_unit(0, 1, Vector2i(3, 3))
	a.skills = ["横江刀"]
	var b := wuxia_unit(1, 0, Vector2i(3, 2))
	var c := wuxia_unit(2, 0, Vector2i(4, 2))
	var d := wuxia_unit(3, 0, Vector2i(2, 2))
	var s := state_with(BattleMap.flat(7, 7), [a, b, c, d])
	var plan := EnemyAI.plan(s, a)
	eq(plan["skill"], "横江刀", "AI chooses active sweep against grouped foes")
	var move_cost := int(s.reachable_for(a)["cost"][plan["move"]])
	check(move_cost + 4 <= a.ap, "AI reserves AP for selected art")
	s.move_unit(a, plan["move"])
	check(s.is_valid_target(a, plan["skill"], plan["target"]), "AI action valid after movement")
	check(not s.execute(a, plan["skill"], plan["target"]).is_empty(), "AI active executes")
	a.ap = 3
	a.qi = 0
	plan = EnemyAI.plan(s, a)
	eq(plan["skill"], "普攻", "AI falls back to ordinary attack with low resources")
	a.ap = 2
	plan = EnemyAI.plan(s, a)
	eq(plan["skill"], "", "AI never submits an attack below 3 AP")
	var b1 := BattleDefs.build_wuxia_b1()
	for enemy in b1.living(BattleUnit.ENEMY):
		check(not enemy.active_skills.is_empty(), "B1 enemy has an active art")
	# Diagonal neighbors must pass the AI's GDD Chebyshev range filter.
	a.ap = 3
	a.skills = []
	b.pos = Vector2i(4, 4)
	a.pos = Vector2i(3, 3)
	c.hp = 0
	d.hp = 0
	plan = EnemyAI.plan(s, a)
	eq(plan["skill"], "普攻", "AI can attack diagonal neighbor without movement")


func hud_text(node: Node) -> String:
	var result := ""
	if node is Label or node is Button:
		result += node.text + "\n"
	elif node is RichTextLabel:
		result += node.get_parsed_text() + "\n"
	for child in node.get_children():
		result += hud_text(child)
	return result


func check_hud_bounds(battle: Node) -> void:
	var extent := root.get_visible_rect().end
	for control in [battle.info_text, battle.menu_panel, battle.preview_panel]:
		if control.is_visible_in_tree():
			check(control.get_global_rect().end.y <= extent.y, "GDD HUD stays inside viewport vertically")
			check(control.get_global_rect().end.x <= extent.x, "GDD HUD stays inside viewport horizontally")


func test_wuxia_hud_resources_intro_and_rounds() -> void:
	var game = root.get_node("Game")
	var old_shot: String = game.shot
	var old_battle: String = game.current_battle
	game.shot = "wuxia"
	game.current_battle = "wuxia_b1"
	var battle = load("res://scripts/game/battle.gd").new()
	root.add_child(battle)
	var u: BattleUnit = battle.state.current()
	eq(battle.mode, "main", "wuxia screenshot skips intro and opens action menu")
	eq(u, battle.state.living(BattleUnit.PLAYER)[0], "wuxia screenshot selects first ally")
	check(battle.overlay == null, "screenshot has no intro blocking the battlefield")
	u.ap = 4
	u.qi = 7
	u.rp = 0
	u.gain_guard()
	battle._enter_main()
	var text: String = hud_text(battle.ui_root)
	check(text.contains("AP") and text.contains("内力 7/12"), "live HUD uses AP and qi")
	check(not text.contains("技力") and not text.contains("TP"), "GDD visible HUD has no classic resources")
	check(battle.info_text.get_parsed_text().contains("■■■■□□ 4/6"), "AP cells show both spent and available AP")
	check(battle.info_text.text.contains("反应 0/1"), "RP denominator shows per-round reaction budget")
	for attribute in ["气血", "劲力", "护体", "眼力", "身法", "速度", "内力"]:
		check(battle.info_text.text.contains(attribute), "unit info shows existing attribute " + attribute)
	check(battle.info_text.text.contains("护势"), "guard stance visible")
	u.gain_block()
	u.qi_blocked = true
	battle._show_info(u)
	check(battle.info_text.text.contains("格挡") and battle.info_text.text.contains("气脉受阻"), "block and active qi seal visible")
	var hover: String = battle._hover_unit_text(u, "地形")
	check(hover.contains("AP 4/6") and hover.contains("内力 7/12") and hover.contains("反应 0/1"), "hover uses real GDD resources")
	check(hover.contains("格挡") and hover.contains("气脉受阻") and not hover.contains("技力"), "hover explains current statuses")
	battle._enter_main()
	await process_frame
	await process_frame
	check_hud_bounds(battle)
	battle._on_skills()
	await process_frame
	await process_frame
	check_hud_bounds(battle)
	battle._enter_target("调息")
	check(battle.preview_text.text.contains("AP3 内力0") and battle.preview_text.text.contains("内力 11/12"), "rest preview shows cost and capped qi gain")
	battle._show_intro()
	text = hud_text(battle.overlay)
	for phrase in ["6AP", "穿插", "八方向", "1AP", "泥地2AP", "侧背只修正命中", "控制区", "借机", "自动反击", "1RP", "调息", "击败全部劫客", "我方全灭"]:
		check(text.contains(phrase), "intro teaches GDD rule " + phrase)
	for phrase in ["技力", "TP", "伤害更高", "夹击追击", "林砚"]:
		check(not text.contains(phrase), "intro excludes classic wording " + phrase)
	battle.overlay.free()
	battle.overlay = null
	for i in range(battle.state.units.size()):
		battle._refresh_timeline()
		check(battle.turn_label.text.begins_with("第1轮 · 当前行动者："), "round label stays at one across all actors")
		battle.state.end_turn()
		battle.state.begin_next_turn()
	battle._refresh_timeline()
	check(battle.turn_label.text.begins_with("第2轮 · 当前行动者："), "round label advances after all actors finish")
	check(not battle.turn_label.text.contains("手"), "GDD timeline never calls actions hands")
	battle.free()
	game.shot = old_shot
	game.current_battle = old_battle


func test_wuxia_hud_forecast_and_control_zones() -> void:
	var game = root.get_node("Game")
	var old_shot: String = game.shot
	var old_battle: String = game.current_battle
	game.shot = "wuxia"
	game.current_battle = "wuxia_b1"
	var battle = load("res://scripts/game/battle.gd").new()
	root.add_child(battle)
	var u: BattleUnit = battle.state.current()
	var enemy: BattleUnit = battle.state.living(BattleUnit.ENEMY)[0]
	for other in battle.state.units:
		if other != u and other != enemy:
			other.hp = 0
	u.pos = Vector2i(6, 8)
	u.facing = 0
	enemy.pos = Vector2i(6, 9)
	for facing in range(8):
		enemy.facing = facing
		battle._enter_main()
		var count := 0
		for p in battle.tiles:
			if battle.tiles[p].hl == battle.COL_ZOC:
				count += 1
				check(ControlZone.cells(enemy, battle.state.map).has(p), "highlight matches actual control geometry")
		eq(count, 5, "five control-zone tiles highlighted for facing " + str(facing))
	enemy.facing = 0
	var goal := Vector2i(6, 7)
	battle._enter_main()
	var before := [u.pos, u.ap, u.qi, enemy.rp, battle.state.rng.state]
	var risks: Array = battle._preview_move(goal)
	eq(risks.size(), 1, "leaving control zone previews one reaction")
	eq(battle.tiles[u.pos].hl2, battle.COL_PATH_RISK, "departure tile marked red")
	eq(battle.tiles[goal].hl2, battle.COL_PATH_RISK, "dangerous step endpoint marked red")
	check(battle.preview_text.text.contains("AP1 内力0") and battle.preview_text.text.contains("借机攻击"), "movement forecast shows both resource costs and danger")
	var hit: Dictionary = Combat.gdd_calc(enemy, u, SkillDB.get_skill(enemy.basic), battle.state.map, enemy.pos, true)
	check(battle.preview_text.text.contains("命中 %d%%" % hit["hit"]), "opportunity hit chance uses reaction penalty")
	battle._request_move(goal)
	eq(battle.mode, "move_confirm", "dangerous movement requires confirmation")
	eq([u.pos, u.ap, u.qi, enemy.rp, battle.state.rng.state], before, "path previews and confirmation do not mutate battle or RNG")
	battle._cancel()
	eq(battle.mode, "main", "cancel danger returns to main menu")
	eq([u.pos, u.ap, u.qi, enemy.rp, battle.state.rng.state], before, "cancelling danger spends no resources")
	var loop_path := [u.pos, goal, u.pos, goal]
	eq(battle.state.path_reactions(u, loop_path).size(), 1, "same enemy cannot react twice along one path")
	eq(battle.state.path_reactions(u, [u.pos, Vector2i(5, 8)]).size(), 0, "movement within same control zone is safe")
	eq(battle.state.path_reactions(u, [goal, u.pos]).size(), 0, "entering a control zone is safe")
	enemy.rp = 0
	battle._enter_main()
	var dark_count := 0
	for p in battle.tiles:
		if battle.tiles[p].hl == battle.COL_ZOC_SPENT:
			dark_count += 1
	eq(dark_count, 5, "spent-RP geometry has five dim control tiles")
	eq(battle._preview_move(goal).size(), 0, "spent RP causes no opportunity warning")
	enemy.rp = 1
	battle._enter_target("燕行步")
	battle._select_target(goal)
	check(battle.preview_text.text.contains("AP2 内力4") and battle.preview_text.text.contains("内力 8/12"), "lightfoot forecast shows fixed costs and resources after use")
	check(battle.preview_text.text.contains("借机攻击：无（燕行步豁免）"), "safe lightfoot does not warn about opportunity attacks")
	u.lightfoot = "踏雪步"
	u.skills.append("踏雪步")
	battle._enter_target("踏雪步")
	battle._select_target(goal)
	check(battle.preview_text.text.contains("离开控制区") and battle.tiles[goal].hl2 == battle.COL_PATH_RISK, "taxue previews real opportunity risk")
	battle._enter_target(u.basic)
	battle._select_target(enemy.pos)
	var attack: Dictionary = battle.state.preview(u, u.basic, enemy.pos)[0]
	var text: String = battle.preview_text.get_parsed_text()
	check(text.contains("预计命中后伤害 %d" % attack["dmg"]) and text.contains("命中 %d%%" % attack["hit"]), "attack forecast matches rule damage and chance")
	for part in ["基础90%", "眼力+5", "闪避-10", "侧背+0", "地形+0"]:
		check(text.contains(part), "hit breakdown includes " + part)
	check(text.contains("AP3 内力0") and text.contains("施展后 AP 3/6"), "attack forecasts spending and remaining resources")
	check(text.contains("自动反击：可能") and text.contains("反击命中"), "front attack warns about automatic counter")
	enemy.rp = 0
	battle._show_preview(SkillDB.get_skill(u.basic), battle.state.preview(u, u.basic, enemy.pos))
	check(battle.preview_text.text.contains("自动反击：无（目标RP 0/1"), "counter forecast respects spent RP")
	enemy.rp = 1
	u.pos = Vector2i(6, 10)
	battle._enter_target(u.basic)
	battle._select_target(enemy.pos)
	check(battle.preview_text.text.contains("侧背+10") and battle.preview_text.text.contains("自动反击：无"), "back attack shows hit-only bonus and no counter")
	u.pos = Vector2i(7, 9)
	battle._enter_target(u.basic)
	battle._select_target(enemy.pos)
	check(battle.preview_text.text.contains("侧背+5") and battle.preview_text.text.contains("自动反击：可能"), "side attack includes hit bonus and counter risk")
	u.pos = Vector2i(6, 8)
	var push: Dictionary = battle.state.counter_preview(u, "震山掌", enemy)
	check(push.get("condition", "").contains("落空后"), "knockback forecast only warns of counter on a miss")
	check(battle.state.counter_preview(u, "破风剑", enemy).is_empty(), "area attacks do not forecast automatic counters")
	battle._enter_target("回锋剑")
	battle._select_target(enemy.pos)
	check(battle.preview_text.text.contains("自主后撤") and battle.preview_text.text.contains("离开控制区"), "free retreat forecasts opportunity attacks separately from counters")
	check(battle.preview_text.text.contains("自动反击：无"), "enemy cannot counter after spending its RP on retreat")
	await process_frame
	await process_frame
	check_hud_bounds(battle)
	u.ap = 2
	battle._enter_main()
	var attack_edges := 0
	for p in battle.tiles:
		if battle.tiles[p].edge.a > 0:
			attack_edges += 1
	eq(attack_edges, 0, "main attack reach excludes attacks with insufficient AP")
	u.ap = 6
	# Terrain and accuracy terms sum to the same clamped chance used in resolution.
	battle.state.map.set_terrain(enemy.pos, "forest")
	attack = Combat.calc(u, enemy, SkillDB.get_skill(u.basic), battle.state.map, u.pos)
	var sum := 0
	for value in attack["hit_parts"].values():
		sum += int(value)
	eq(clampi(sum, 10, 95), attack["hit"], "displayed hit components reproduce actual hit chance")
	check(attack["hit_parts"]["terrain"] < 0, "cover appears as negative terrain hit modifier")
	battle.free()
	game.shot = old_shot
	game.current_battle = old_battle


func test_wuxia_hud_skill_availability() -> void:
	var game = root.get_node("Game")
	var old_shot: String = game.shot
	var old_battle: String = game.current_battle
	game.shot = "wuxia"
	game.current_battle = "wuxia_b1"
	var battle = load("res://scripts/game/battle.gd").new()
	root.add_child(battle)
	for u in battle.state.living(BattleUnit.PLAYER):
		battle.state.current_id = u.id
		u.ap = 6
		u.qi = 12
		battle.state.acted = true
		battle.state.moved = true
		battle._enter_main()
		check(not battle.menu_box.get_child(0).disabled, "GDD HUD permits another attack with AP")
		check(not battle.menu_box.get_child(1).disabled, "GDD HUD permits skills after moving and attacking")
		battle._on_skills()
		check(battle.preview_text.text.contains(u.inner), "HUD displays equipped passive inner")
		for i in range(u.skills.size()):
			var sid: String = u.skills[i]
			var button: Button = battle.menu_box.get_child(i)
			check(button.text.contains(sid), "HUD lists " + sid)
			check(button.text.contains("AP") and button.text.contains("内力"), "HUD lists both costs " + sid)
			check(not button.disabled, "available skill enabled " + sid)
		battle._enter_target(u.lightfoot)
		eq(battle.sel_target, Vector2i(-1, -1), "lightfoot requires choosing a landing")
		check(battle.target_set.size() > 0 and not battle.target_set.has(u.pos), "lightfoot highlights legal landings")
		var landing: Vector2i = battle.target_set[0]
		battle._select_target(landing)
		check(not battle.menu_box.get_child(0).disabled, "legal landing can be confirmed")
		check(battle.preview_text.text.contains(SkillDB.get_skill(u.lightfoot)["desc"]), "landing forecast describes lightfoot effects")
		u.used_skills[u.lightfoot] = true
		battle._enter_main()
		battle._on_skills()
		check(battle.menu_box.get_child(3).disabled, "used lightfoot greyed out")
		u.ap = 0
		u.qi = 0
		battle._enter_main()
		check(battle.menu_box.get_child(0).disabled and battle.menu_box.get_child(1).disabled, "main commands greyed out with no AP")
		battle._on_skills()
		for i in range(u.skills.size()):
			check(battle.menu_box.get_child(i).disabled, "unaffordable skill greyed out")
		battle._enter_target(u.active_skills[0])
		check(not battle.state.is_valid_target(u, u.active_skills[0], landing), "HUD confirmation cannot bypass insufficient resources")
	var inspected: BattleUnit = battle.state.living(BattleUnit.PLAYER)[0]
	inspected.gain_guard()
	battle._show_info(inspected)
	check(battle.info_text.text.contains("护势"), "unit info names guard stance")
	inspected.gain_block()
	inspected.ap_penalty = 2
	battle._show_info(inspected)
	check(battle.info_text.text.contains("格挡") and not battle.info_text.text.contains("护势"), "unit info shows exclusive block stance")
	check(battle.info_text.text.contains("气脉受阻"), "unit info shows pending seal")
	inspected.ap_penalty = 0
	inspected.qi_blocked = true
	battle._show_info(inspected)
	check(battle.info_text.text.contains("气脉受阻"), "unit info shows seal through affected action")
	battle.free()
	game.shot = old_shot
	game.current_battle = old_battle
