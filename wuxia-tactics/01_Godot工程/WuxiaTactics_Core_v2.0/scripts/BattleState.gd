extends RefCounted
## Battle state and resolver. Neither UI nor animation may roll their own combat math.
const Board = preload("res://scripts/BattleBoard.gd")
const BASE_AP: int = 6
const MAX_QI: int = 12
const SKILLS: Dictionary = {
    "普攻": {"ap":3,"qi":0,"power":8,"range":1,"base_hit":90,"kind":"melee"},
    "破风剑": {"ap":4,"qi":3,"power":10,"range":3,"base_hit":85,"kind":"line_aoe","pierce":1},
    "回锋剑": {"ap":3,"qi":2,"power":8,"range":1,"base_hit":95,"kind":"melee_retreat"},
    "穿云枪": {"ap":4,"qi":3,"power":11,"range":2,"base_hit":90,"kind":"spear","pierce":1},
    "挑枪": {"ap":4,"qi":2,"power":8,"range":2,"base_hit":90,"kind":"push_spear"},
    "震山掌": {"ap":4,"qi":3,"power":8,"range":1,"base_hit":90,"kind":"push"},
    "截脉指": {"ap":4,"qi":4,"power":5,"range":2,"base_hit":85,"kind":"seal"},
    "守关式": {"ap":2,"qi":2,"kind":"shield"},
    "燕行步": {"ap":2,"qi":4,"kind":"leap"},
    "防御": {"ap":2,"qi":0,"kind":"guard"},
    "调息": {"ap":3,"qi":0,"kind":"rest"}
}
var board = Board.new()
var units: Array[Dictionary] = []
var order: Array[int] = []
var queue_index: int = 0
var round_no: int = 1
var result: String = ""
var log_lines: Array[String] = []
var rng := RandomNumberGenerator.new()

func reset() -> void:
    if not board.load_from("res://data/b1_map.json"):
        result = "error"
        return
    rng.randomize()
    # Independent units: attack (strength), armor, accuracy, evasion, facing, per-round RP.
    units = [
        {"id":0,"name":"剑客","side":"player","pos":Vector2i(2,10),"facing":Vector2i(0,-1),"hp":31,"max_hp":31,"strength":4,"armor":3,"accuracy":5,"evasion":5,"speed":88,"ap":6,"qi":12,"rp":1,"guard":0,"shield":false,"slow":0,"rested":false,"skills":["破风剑","回锋剑","守关式"]},
        {"id":1,"name":"枪客","side":"player","pos":Vector2i(3,10),"facing":Vector2i(0,-1),"hp":36,"max_hp":36,"strength":4,"armor":4,"accuracy":0,"evasion":4,"speed":61,"ap":6,"qi":12,"rp":1,"guard":0,"shield":false,"slow":0,"rested":false,"skills":["穿云枪","挑枪","守关式"]},
        {"id":2,"name":"拳师","side":"player","pos":Vector2i(4,10),"facing":Vector2i(0,-1),"hp":33,"max_hp":33,"strength":3,"armor":3,"accuracy":3,"evasion":7,"speed":50,"ap":6,"qi":12,"rp":1,"guard":0,"shield":false,"slow":0,"rested":false,"skills":["震山掌","截脉指","守关式"]},
        {"id":3,"name":"劫客甲","side":"enemy","pos":Vector2i(5,7),"facing":Vector2i(0,1),"hp":25,"max_hp":25,"strength":3,"armor":2,"accuracy":0,"evasion":10,"speed":76,"ap":6,"qi":8,"rp":1,"guard":0,"shield":false,"slow":0,"rested":false,"skills":[]},
        {"id":4,"name":"劫客乙","side":"enemy","pos":Vector2i(7,6),"facing":Vector2i(-1,1),"hp":26,"max_hp":26,"strength":3,"armor":3,"accuracy":0,"evasion":7,"speed":45,"ap":6,"qi":8,"rp":1,"guard":0,"shield":false,"slow":0,"rested":false,"skills":[]}
    ]
    order = [0, 1, 2, 3, 4]
    order.sort_custom(func(a: int, b: int) -> bool:
        if int(units[a]["speed"]) == int(units[b]["speed"]):
            return a < b
        return int(units[a]["speed"]) > int(units[b]["speed"])
    )
    round_no = 1
    queue_index = 0
    result = ""
    log_lines.clear()
    push_log("B1 渡口截箱：消灭两名劫客。点击地砖移动，选择指令攻击。")
    start_current()

func push_log(message: String) -> void:
    log_lines.push_front(message)
    if log_lines.size() > 7:
        log_lines.pop_back()

func active_id() -> int:
    if order.is_empty():
        return -1
    return order[queue_index]

func active() -> Dictionary:
    return units[active_id()]

func living_enemy_of(side: String) -> Array[int]:
    var found: Array[int] = []
    for u in units:
        if int(u["hp"]) > 0 and str(u["side"]) != side:
            found.append(int(u["id"]))
    return found

func living_at(cell: Vector2i) -> int:
    for u in units:
        if int(u["hp"]) > 0 and u["pos"] == cell:
            return int(u["id"])
    return -1

func start_current() -> void:
    if result != "":
        return
    var u: Dictionary = active()
    u["ap"] = BASE_AP
    u["qi"] = mini(MAX_QI, int(u["qi"])+1)
    u["rested"] = false
    # Guard/shield last until the following own action, unless consumed by a hit.
    u["guard"] = 0
    u["shield"] = false
    if int(u["slow"]) > 0:
        u["ap"] = maxi(0,BASE_AP-int(u["slow"]))
        u["slow"] = 0
        push_log("%s气脉受阻，本次AP减少。" % u["name"])
    push_log("第%d轮：轮到%s（AP %d）。" % [round_no,u["name"],u["ap"]])

func advance() -> void:
    if result != "":
        return
    var scanned: int = 0
    while scanned < units.size()+1:
        queue_index += 1
        if queue_index >= order.size():
            queue_index = 0
            round_no += 1
            order.sort_custom(func(a: int, b: int) -> bool:
                if int(units[a]["speed"]) == int(units[b]["speed"]):
                    return a < b
                return int(units[a]["speed"]) > int(units[b]["speed"])
            )
            for u in units:
                u["rp"] = 1
        if int(active()["hp"]) > 0:
            start_current()
            return
        scanned += 1

func zoc_threatens(defender: Dictionary, location: Vector2i) -> bool:
    if int(defender["hp"]) <= 0:
        return false
    var delta: Vector2i = location - defender["pos"]
    if board.chebyshev(defender["pos"], location) != 1:
        return false
    var f: Vector2i = defender["facing"]
    return (delta.x*f.x + delta.y*f.y) >= 0

func opportunity_sources(moving_id: int, from_cell: Vector2i, to_cell: Vector2i) -> Array[int]:
    var sources: Array[int] = []
    var mover: Dictionary = units[moving_id]
    for eid in living_enemy_of(str(mover["side"])):
        var e: Dictionary = units[eid]
        if int(e["rp"]) > 0 and zoc_threatens(e,from_cell) and not zoc_threatens(e,to_cell):
            sources.append(eid)
    return sources

func risky_route(moving_id: int, route: Array[Vector2i]) -> Array[String]:
    var names: Array[String] = []
    var from_cell: Vector2i = units[moving_id]["pos"]
    var simulated_used: Dictionary = {}
    for nxt in route:
        for eid in opportunity_sources(moving_id,from_cell,nxt):
            if not simulated_used.has(eid):
                names.append(str(units[eid]["name"]))
                simulated_used[eid] = true
        from_cell = nxt
    return names

func movement(moving_id: int, route: Array[Vector2i]) -> bool:
    if result != "" or moving_id != active_id() or route.is_empty():
        return false
    var mover: Dictionary = units[moving_id]
    if board.path_ap(route) > int(mover["ap"]):
        push_log("AP不足，移动未执行。")
        return false
    # Recheck one step at a time; an opportunity attack may stop the path on death.
    for nxt in route:
        if not board.can_step(mover["pos"],nxt,units,moving_id):
            return false
        for enemy_id in opportunity_sources(moving_id,mover["pos"],nxt):
            if int(units[moving_id]["hp"]) <= 0:
                break
            counterstrike(enemy_id,moving_id,"借机攻击")
        if int(mover["hp"]) <= 0:
            push_log("%s在撤离控制区时倒下，移动中止。" % mover["name"])
            check_outcome()
            return true
        mover["ap"] = int(mover["ap"])-board.travel_cost(nxt)
        var delta: Vector2i = nxt-mover["pos"]
        mover["pos"] = nxt
        mover["facing"] = Vector2i(signi(delta.x),signi(delta.y))
    push_log("%s移动完成，剩余AP %d。" % [mover["name"],mover["ap"]])
    return true

func valid_attack(attacker_id: int, target_id: int, skill_name: String) -> bool:
    if not SKILLS.has(skill_name):
        return false
    var spec: Dictionary = SKILLS[skill_name]
    var kind: String = str(spec["kind"])
    if kind in ["leap","guard","shield","rest"]:
        return false
    var attacker: Dictionary = units[attacker_id]
    var target: Dictionary = units[target_id]
    if skill_name != "普攻" and skill_name not in attacker["skills"]:
        return false
    if int(attacker["hp"]) <= 0 or int(target["hp"]) <= 0 or attacker["side"] == target["side"]:
        return false
    var at: Vector2i = attacker["pos"]
    var tg: Vector2i = target["pos"]
    var dist: int = board.chebyshev(at,tg)
    if skill_name == "普攻":
        return dist == 1
    if kind in ["melee","melee_retreat","push"]:
        return dist == 1
    if kind in ["spear","push_spear"]:
        if not (dist == 2 and board.in_line(at,tg,2) and board.line_clear(at,tg)):
            return false
        # Spear point cannot stab through a unit occupying the intervening tile.
        var d: Vector2i = Vector2i(signi(tg.x-at.x),signi(tg.y-at.y))
        return living_at(at+d) == -1
    if kind == "line_aoe":
        return board.in_line(at,tg,3) and board.line_clear(at,tg)
    if kind == "seal":
        return board.in_line(at,tg,2) and board.line_clear(at,tg)
    return false

func can_pay(user_id: int, name: String) -> bool:
    if not SKILLS.has(name):
        return false
    var u: Dictionary = units[user_id]
    var spec: Dictionary = SKILLS[name]
    return int(u["hp"]) > 0 and int(u["ap"]) >= int(spec["ap"]) and int(u["qi"]) >= int(spec["qi"])

func consume(user_id: int, name: String) -> void:
    var u: Dictionary = units[user_id]
    var spec: Dictionary = SKILLS[name]
    u["ap"] = int(u["ap"])-int(spec["ap"])
    u["qi"] = int(u["qi"])-int(spec["qi"])

func hit_chance(attacker_id: int, target_id: int, skill_name: String) -> int:
    var a: Dictionary = units[attacker_id]
    var t: Dictionary = units[target_id]
    var spec: Dictionary = SKILLS[skill_name]
    var v: int = int(spec["base_hit"])+int(a["accuracy"])-int(t["evasion"])
    var delta: Vector2i = a["pos"]-t["pos"]
    var f: Vector2i = t["facing"]
    var facing_dot: int = delta.x*f.x+delta.y*f.y
    if facing_dot < 0:
        v += 10
    elif facing_dot == 0:
        v += 5
    # Low crate grants cover to ranged attacks only. Physical blockers fully block LOS.
    if str(spec["kind"]) in ["line_aoe","spear","push_spear","seal"]:
        for d in Board.DIRECTIONS:
            if board.tile(t["pos"]+d) == "C":
                v -= 10
                break
    return clampi(v,10,95)

func expected_damage(attacker_id: int, target_id: int, skill_name: String) -> int:
    var a: Dictionary = units[attacker_id]
    var t: Dictionary = units[target_id]
    var spec: Dictionary = SKILLS[skill_name]
    var effective_armor: int = maxi(0,int(t["armor"])+int(t["guard"])-int(spec.get("pierce",0)))
    var damage: int = maxi(1,int(spec["power"])+int(a["strength"])-effective_armor)
    if bool(t["shield"]):
        damage = maxi(1,roundi(float(damage)*0.75))
    return damage

func counterstrike(counter_id: int, target_id: int, reason: String) -> void:
    var counter: Dictionary = units[counter_id]
    if int(counter["rp"]) <= 0 or int(counter["hp"]) <= 0 or int(units[target_id]["hp"]) <= 0:
        return
    if not zoc_threatens(counter,units[target_id]["pos"]):
        return
    counter["rp"] = 0
    _resolve_one_hit(counter_id,target_id,"普攻",reason)
    check_outcome()

func _resolve_one_hit(attacker_id: int, target_id: int, skill_name: String, prefix: String) -> bool:
    var a: Dictionary = units[attacker_id]
    var t: Dictionary = units[target_id]
    var chance: int = hit_chance(attacker_id,target_id,skill_name)
    var rolled: int = rng.randi_range(1,100)
    if rolled > chance:
        push_log("%s%s对%s未命中（%d%%）。" % [a["name"],prefix,t["name"],chance])
        return false
    var damage: int = expected_damage(attacker_id,target_id,skill_name)
    t["hp"] = maxi(0,int(t["hp"])-damage)
    t["guard"] = 0
    t["shield"] = false
    push_log("%s%s命中%s，造成%d伤害（%d%%）。" % [a["name"],prefix,t["name"],damage,chance])
    if int(t["hp"]) <= 0:
        push_log("%s倒下。" % t["name"])
    return true

func attack(attacker_id: int, target_id: int, skill_name: String) -> bool:
    if result != "" or attacker_id != active_id() or not valid_attack(attacker_id,target_id,skill_name) or not can_pay(attacker_id,skill_name):
        return false
    var attacker: Dictionary = units[attacker_id]
    var target: Dictionary = units[target_id]
    var old_pos: Vector2i = attacker["pos"]
    var target_pos: Vector2i = target["pos"]
    consume(attacker_id,skill_name)
    attacker["facing"] = Vector2i(signi(target_pos.x-old_pos.x),signi(target_pos.y-old_pos.y))
    var kind: String = str(SKILLS[skill_name]["kind"])
    if kind == "line_aoe":
        var d: Vector2i = attacker["facing"]
        for step in range(1,4):
            var pos: Vector2i = old_pos+d*step
            if board.solid(pos):
                break
            var uid: int = living_at(pos)
            if uid >= 0 and units[uid]["side"] != attacker["side"]:
                _resolve_one_hit(attacker_id,uid,skill_name,"施展"+skill_name)
    else:
        var hit: bool = _resolve_one_hit(attacker_id,target_id,skill_name,"施展"+skill_name)
        if hit and int(target["hp"]) > 0:
            if kind == "seal":
                target["slow"] = maxi(int(target["slow"]),2)
                push_log("%s气脉受阻：下次行动AP−2。" % target["name"])
            if kind in ["push","push_spear"]:
                var d: Vector2i = Vector2i(signi(target_pos.x-old_pos.x),signi(target_pos.y-old_pos.y))
                var dest: Vector2i = target_pos+d
                if board.can_step(target_pos,dest,units,target_id):
                    target["pos"] = dest
                    push_log("%s被击退一格。" % target["name"])
        if kind == "melee_retreat":
            var backwards: Vector2i = Vector2i(signi(old_pos.x-target_pos.x),signi(old_pos.y-target_pos.y))
            var landing: Vector2i = old_pos+backwards
            if board.can_step(old_pos,landing,units,attacker_id):
                attacker["pos"] = landing
                push_log("%s回锋后撤一格（不会触发借机攻击）。" % attacker["name"])
        # A direct adjacent strike can be countered once, after the attack resolves.
        if int(target["hp"]) > 0 and int(attacker["hp"]) > 0 and kind in ["melee","melee_retreat","push"]:
            if board.chebyshev(target["pos"],attacker["pos"]) == 1 and zoc_threatens(target,attacker["pos"]):
                counterstrike(target_id,attacker_id,"自动反击")
    check_outcome()
    return true

func self_action(user_id: int, command: String) -> bool:
    if result != "" or user_id != active_id() or not can_pay(user_id,command):
        return false
    var u: Dictionary = units[user_id]
    if command == "调息" and bool(u["rested"]):
        return false
    if command not in ["调息","防御","守关式"]:
        return false
    consume(user_id,command)
    if command == "调息":
        u["qi"] = mini(MAX_QI,int(u["qi"])+4)
        u["rested"] = true
        push_log("%s调息恢复4点内力（每次行动仅限1次）。" % u["name"])
    elif command == "防御":
        u["guard"] = 2
        u["shield"] = false
        push_log("%s防御：下次命中时护甲+2。" % u["name"])
    else:
        u["guard"] = 0
        u["shield"] = true
        push_log("%s施展守关式：下次命中伤害降低25%%。" % u["name"])
    return true

func leap(user_id: int, goal: Vector2i) -> bool:
    if result != "" or user_id != active_id() or not can_pay(user_id,"燕行步"):
        return false
    var u: Dictionary = units[user_id]
    if not board.leap_allowed(u["pos"],goal,units,user_id):
        return false
    consume(user_id,"燕行步")
    var d: Vector2i = goal-u["pos"]
    u["pos"] = goal
    u["facing"] = Vector2i(signi(d.x),signi(d.y))
    push_log("%s施展燕行步落于%s，免疫该次移动的借机攻击。" % [u["name"],str(goal)])
    return true

func check_outcome() -> void:
    if living_enemy_of("player").is_empty():
        result = "victory"
        push_log("胜利！劫客已全部击败。")
    elif living_enemy_of("enemy").is_empty():
        result = "defeat"
        push_log("失败：我方全部战败。")
