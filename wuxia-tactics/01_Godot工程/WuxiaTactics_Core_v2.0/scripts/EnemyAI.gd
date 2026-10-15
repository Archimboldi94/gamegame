extends RefCounted
const Board = preload("res://scripts/BattleBoard.gd")
## Small deterministic rule-based AI: 1) strike adjacent targets; 2) move towards melee; 3) finish turn.
## Each enemy uses exactly the same movement, hit, armor, ZOC and reaction APIs as the player.

func play(state) -> void:
    if state.result != "":
        return
    var eid: int = state.active_id()
    if str(state.units[eid]["side"]) != "enemy":
        return
    var tries: int = 0
    while tries < 6 and state.result == "" and int(state.units[eid]["hp"]) > 0:
        tries += 1
        var adjacent: Array[int] = []
        for aid in state.living_enemy_of("enemy"):
            if state.valid_attack(eid,aid,"普攻"):
                adjacent.append(aid)
        if not adjacent.is_empty() and state.can_pay(eid,"普攻"):
            adjacent.sort_custom(func(a: int, b: int) -> bool:
                return int(state.units[a]["hp"]) < int(state.units[b]["hp"])
            )
            state.attack(eid,adjacent[0],"普攻")
            continue
        if not adjacent.is_empty() and not state.can_pay(eid,"普攻"):
            break
        var best_route: Array[Vector2i] = []
        var best_cost: int = 99999
        for aid in state.living_enemy_of("enemy"):
            var player: Dictionary = state.units[aid]
            var center: Vector2i = player["pos"]
            for d in Board.DIRECTIONS:
                var goal: Vector2i = center+d
                if state.board.solid(goal) or state.board.occupied(goal,state.units,eid):
                    continue
                var route: Array[Vector2i] = state.board.path(state.units[eid]["pos"],goal,state.units,eid)
                if route.is_empty():
                    continue
                var cost: int = state.board.path_ap(route)
                if cost < best_cost:
                    best_cost = cost
                    best_route = route
        if best_route.is_empty():
            state.push_log("%s无法接近目标，结束行动。" % state.units[eid]["name"])
            break
        var ap: int = int(state.units[eid]["ap"])
        if ap <= 0:
            break
        # Move far enough to approach; save attack AP when contact is achievable in this turn.
        var budget: int = ap
        if best_cost <= ap and ap-best_cost >= 3:
            budget = best_cost
        var prefix: Array[Vector2i] = []
        var spent: int = 0
        for p in best_route:
            var step_cost: int = state.board.travel_cost(p)
            if spent+step_cost > budget:
                break
            spent += step_cost
            prefix.append(p)
        if prefix.is_empty():
            break
        if not state.movement(eid,prefix):
            break
        # Next loop: attack if adjacent and enough AP; else continue advancing.
    state.push_log("%s行动结束。" % state.units[eid]["name"])
