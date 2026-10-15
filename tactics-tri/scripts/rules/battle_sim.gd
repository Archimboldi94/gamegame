class_name BattleSim
extends RefCounted
## Headless both-sides AI simulation for balance stats. No scenes or nodes.


static func run(battle_id: String, seed: int = 7, max_turns: int = 400, party: PartyState = null) -> Dictionary:
	var state := BattleDefs.build_state(battle_id, seed, party)
	var turns := 0
	var actions := 0
	var opportunity_hits := 0
	while state.outcome() == "" and turns < max_turns:
		var r := state.begin_next_turn()
		var u = r["unit"]
		if u == null:
			break
		var plan := EnemyAI.plan(state, u)
		if plan["move"] != u.pos:
			var before_hp: int = u.hp
			var path := state.move_unit(u, plan["move"])
			if path.size() >= 2 and u.hp < before_hp:
				opportunity_hits += 1
		if plan["skill"] != "" and u.alive():
			var sid: String = plan["skill"]
			if sid == "__take_chest__":
				if state.take_chest(u):
					actions += 1
			elif state.is_valid_target(u, sid, plan["target"]) or SkillDB.get_skill(sid)["kind"] == "self":
				state.execute(u, sid, plan["target"])
				actions += 1
		state.end_turn()
		turns += 1
	var result: String = state.outcome()
	if result == "":
		result = "timeout"
	var allies := []
	var foes := []
	for u in state.units:
		var row := {"id": u.id, "name": u.name, "team": u.team, "hp": u.hp, "max_hp": u.max_hp, "alive": u.alive()}
		(allies if u.team == BattleUnit.PLAYER else foes).append(row)
	return {
		"battle_id": battle_id, "seed": seed, "result": result, "turns": turns,
		"actions": actions, "opportunity_hits": opportunity_hits,
		"allies": allies, "foes": foes,
	}


static func batch(battle_id: String, seeds: Array, max_turns: int = 400, party: PartyState = null) -> Dictionary:
	var wins := 0
	var losses := 0
	var timeouts := 0
	var total_turns := 0
	var rows: Array = []
	for seed in seeds:
		var row := run(battle_id, int(seed), max_turns, party)
		rows.append(row)
		total_turns += int(row["turns"])
		match str(row["result"]):
			"win":
				wins += 1
			"lose":
				losses += 1
			_:
				timeouts += 1
	var n := maxi(1, seeds.size())
	return {
		"battle_id": battle_id, "samples": seeds.size(),
		"wins": wins, "losses": losses, "timeouts": timeouts,
		"win_rate": float(wins) / float(n),
		"avg_turns": float(total_turns) / float(n),
		"rows": rows,
	}


static func format_summary(stats: Dictionary) -> String:
	return "SIM %s samples=%d wins=%d losses=%d timeouts=%d win_rate=%.1f%% avg_turns=%.1f" % [
		stats["battle_id"], stats["samples"], stats["wins"], stats["losses"], stats["timeouts"],
		100.0 * float(stats["win_rate"]), float(stats["avg_turns"]),
	]
