extends RefCounted
## 唯一战斗规则/结算入口。预览只读，不消耗随机数；表现读取 events。
const Board = preload("res://scripts/BattleBoard.gd")
const BASE_AP: int = 6
const MAX_QI: int = 12
var board = Board.new()
var skills: Dictionary = {}
var units: Array[Dictionary] = []
var order: Array[int] = []
var queue_index: int = 0
var round_no: int = 1
var result: String = ""
var log_lines: Array[String] = []
var events: Array[Dictionary] = []
var rng := RandomNumberGenerator.new()

func reset(seed_value: int = -1) -> void:
    units.clear()
    order.clear()
    skills.clear()
    events.clear()
    log_lines.clear()
    result = ""
    round_no = 1
    queue_index = 0
    if not board.load_from("res://data/b1_map.json"):
        result = "error"
        return
    var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/b1_combat.json"))
    if not raw is Dictionary or not raw.has("skills") or not raw.has("units"):
        result = "error"
        push_error("B1战斗配置缺失或无效")
        return
    skills = raw["skills"].duplicate(true)
    for definition in raw["units"]:
        var u: Dictionary = definition.duplicate(true)
        var marker: Array = board.markers.get(u["marker"], [])
        if int(u["id"]) != units.size() or marker.is_empty():
            result = "error"
            return
        u["pos"] = Vector2i(int(marker[0][0]),int(marker[0][1]))
        u["facing"] = Vector2i(int(u["facing"][0]),int(u["facing"][1]))
        if board.solid(u["pos"]) or board.occupied(u["pos"],units):
            result = "error"
            return
        u.merge({"ap":BASE_AP,"rp":1,"guard":0,"shield":false,"slow":0,"rested":false,"retreated":false,"leaped":false},true)
        units.append(u)
        order.append(int(u["id"]))
    if seed_value < 0:
        rng.randomize()
    else:
        rng.seed = seed_value
    _sort_order()
    push_log("B1 渡口截箱：消灭两名劫客。点击地砖移动，选择指令攻击。")
    start_current()

func push_log(message: String) -> void:
    log_lines.push_front(message)
    if log_lines.size() > 200:
        log_lines.pop_back()

func _sort_order() -> void:
    order.sort_custom(_faster)

func _faster(a: int, b: int) -> bool:
    if int(units[a]["speed"]) == int(units[b]["speed"]):
        return a < b
    return int(units[a]["speed"]) > int(units[b]["speed"])

func active_id() -> int:
    return -1 if order.is_empty() else order[queue_index]

func active() -> Dictionary:
    return {} if active_id() < 0 else units[active_id()]

func has_unit(uid: int) -> bool:
    return uid >= 0 and uid < units.size()

func can_act(uid: int) -> bool:
    return result == "" and has_unit(uid) and uid == active_id() and int(units[uid]["hp"]) > 0

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
    if result != "" or active_id() < 0:
        return
    var u: Dictionary = active()
    u["ap"] = maxi(0,BASE_AP-int(u["slow"]))
    u["slow"] = 0
    u["qi"] = mini(MAX_QI,int(u["qi"])+1)
    u["rested"] = false
    u["retreated"] = false
    u["leaped"] = false
    u["guard"] = 0
    u["shield"] = false
    push_log("第%d轮：轮到%s（AP %d）。" % [round_no,u["name"],u["ap"]])

func advance() -> void:
    check_outcome()
    if result != "" or order.is_empty():
        return
    for _scan in range(order.size()+1):
        queue_index += 1
        if queue_index >= order.size():
            queue_index = 0
            round_no += 1
            _sort_order()
            for u in units:
                u["rp"] = 1 if int(u["hp"]) > 0 else 0
        if int(active()["hp"]) > 0:
            start_current()
            return

func zoc_threatens(defender: Dictionary, location: Vector2i) -> bool:
    if int(defender["hp"]) <= 0 or not board.melee_clear(defender["pos"],location):
        return false
    var delta: Vector2i = location-defender["pos"]
    var f: Vector2i = defender["facing"]
    return delta.x*f.x+delta.y*f.y >= 0

func opportunity_sources(moving_id: int, from_cell: Vector2i, to_cell: Vector2i, used: Dictionary = {}) -> Array[int]:
    var sources: Array[int] = []
    for eid in living_enemy_of(str(units[moving_id]["side"])):
        var e: Dictionary = units[eid]
        if not used.has(eid) and int(e["rp"]) > 0 and zoc_threatens(e,from_cell) and not zoc_threatens(e,to_cell):
            sources.append(eid)
    sources.sort_custom(_faster)
    # GDD 2.7 / 2.11: 同一步仅速度最快的一人，后续步可触发其他人。
    if sources.size() > 1:
        sources.resize(1)
    return sources

func _preview_copy():
    var copy = get_script().new()
    copy.board = board
    copy.skills = skills
    copy.units = units.duplicate(true)
    copy.order = order.duplicate()
    copy.queue_index = queue_index
    return copy

func movement_preview(moving_id: int, route: Array[Vector2i]) -> Dictionary:
    var preview: Dictionary = {"valid":false,"ap":board.path_ap(route),"risks":[],"reason":"非法路径或AP不足"}
    if not can_act(moving_id) or route.is_empty() or int(preview["ap"]) > int(units[moving_id]["ap"]):
        return preview
    var simulated = _preview_copy()
    var u: Dictionary = simulated.units[moving_id]
    var used: Dictionary = {}
    var previous_risk: bool = false
    for nxt in route:
        if not board.can_step(u["pos"],nxt,simulated.units,moving_id):
            return preview
        for eid in simulated.opportunity_sources(moving_id,u["pos"],nxt,used):
            used[eid] = true
            var damage: int = simulated.expected_damage(eid,moving_id,"普攻")
            var no_guard: Dictionary = u.duplicate(true)
            u["guard"] = 0
            u["shield"] = false
            var maximum: int = simulated.expected_damage(eid,moving_id,"普攻") if previous_risk else damage
            u.merge(no_guard,true)
            preview["risks"].append({"source":eid,"from":u["pos"],"to":nxt,"chance":simulated.hit_chance(eid,moving_id,"普攻",true),"damage":damage,"max_damage":maximum})
            previous_risk = true
        var delta: Vector2i = nxt-u["pos"]
        u["pos"] = nxt
        u["facing"] = Vector2i(signi(delta.x),signi(delta.y))
    preview["valid"] = true
    preview["reason"] = ""
    return preview

func risky_route(moving_id: int, route: Array[Vector2i]) -> Array[String]:
    var names: Array[String] = []
    for risk in movement_preview(moving_id,route)["risks"]:
        names.append(str(units[int(risk["source"])]["name"]))
    return names

func movement(moving_id: int, route: Array[Vector2i]) -> bool:
    # Validate the entire command before committing any AP or reactions.
    if not bool(movement_preview(moving_id,route)["valid"]):
        return false
    events.clear()
    var mover: Dictionary = units[moving_id]
    for nxt in route:
        mover["ap"] = int(mover["ap"])-board.travel_cost(nxt)
        for enemy_id in opportunity_sources(moving_id,mover["pos"],nxt):
            counterstrike(enemy_id,moving_id,"借机攻击")
        if int(mover["hp"]) <= 0:
            push_log("%s在撤离控制区时倒下，移动中止。" % mover["name"])
            check_outcome()
            return true
        var old: Vector2i = mover["pos"]
        mover["pos"] = nxt
        mover["facing"] = Vector2i(signi(nxt.x-old.x),signi(nxt.y-old.y))
        events.append({"type":"move","unit":moving_id,"from":old,"to":nxt})
    push_log("%s移动完成，剩余AP %d。" % [mover["name"],mover["ap"]])
    return true

func knows(user_id: int, skill_name: String) -> bool:
    if not has_unit(user_id) or not skills.has(skill_name):
        return false
    return skill_name in ["普攻","防御","调息"] or skill_name in units[user_id]["skills"] or skill_name == units[user_id]["lightfoot"]

func valid_attack(attacker_id: int, target_id: int, skill_name: String) -> bool:
    if not knows(attacker_id,skill_name) or not has_unit(target_id):
        return false
    var spec: Dictionary = skills[skill_name]
    var kind: String = str(spec["kind"])
    var attacker: Dictionary = units[attacker_id]
    var target: Dictionary = units[target_id]
    if int(attacker["hp"]) <= 0 or int(target["hp"]) <= 0 or attacker["side"] == target["side"]:
        return false
    var at: Vector2i = attacker["pos"]
    var tg: Vector2i = target["pos"]
    var dist: int = board.chebyshev(at,tg)
    if kind in ["melee","melee_retreat","push"]:
        return board.melee_clear(at,tg)
    if kind in ["spear","push_spear"]:
        if not (dist == 2 and board.in_line(at,tg,int(spec["range"])) and board.line_clear(at,tg)):
            return false
        var d: Vector2i = Vector2i(signi(tg.x-at.x),signi(tg.y-at.y))
        return living_at(at+d) == -1
    if kind in ["line_aoe","seal"]:
        return board.in_line(at,tg,int(spec["range"])) and board.line_clear(at,tg)
    return false

func can_pay(user_id: int, name: String) -> bool:
    if not knows(user_id,name):
        return false
    var u: Dictionary = units[user_id]
    var spec: Dictionary = skills[name]
    if name == "调息" and bool(u["rested"]):
        return false
    if str(spec["kind"]) == "leap" and bool(u["leaped"]):
        return false
    return int(u["hp"]) > 0 and int(u["ap"]) >= int(spec["ap"]) and int(u["qi"]) >= int(spec["qi"])

func consume(user_id: int, name: String) -> void:
    var u: Dictionary = units[user_id]
    var spec: Dictionary = skills[name]
    u["ap"] = int(u["ap"])-int(spec["ap"])
    u["qi"] = int(u["qi"])-int(spec["qi"])

func hit_chance(attacker_id: int, target_id: int, skill_name: String, reaction: bool = false) -> int:
    var a: Dictionary = units[attacker_id]
    var t: Dictionary = units[target_id]
    var spec: Dictionary = skills[skill_name]
    var v: int = int(spec["base_hit"])+int(a["accuracy"])-int(t["evasion"])
    # Quantize the relative direction before comparing diagonal/cardinal facings.
    var delta: Vector2i = a["pos"]-t["pos"]
    delta = Vector2i(signi(delta.x),signi(delta.y))
    var f: Vector2i = t["facing"]
    var facing_dot: int = delta.x*f.x+delta.y*f.y
    if facing_dot < 0:
        v += 10
    elif facing_dot == 0:
        v += 5
    if str(spec["kind"]) in ["line_aoe","spear","push_spear","seal"]:
        for d in Board.DIRECTIONS:
            if board.tile(t["pos"]+d) == "C":
                v -= 10
                break
    if reaction:
        v -= 10
    return clampi(v,10,95)

func expected_damage(attacker_id: int, target_id: int, skill_name: String) -> int:
    var a: Dictionary = units[attacker_id]
    var t: Dictionary = units[target_id]
    var spec: Dictionary = skills[skill_name]
    var armor: int = maxi(0,int(t["armor"])+int(t["guard"])-int(spec.get("pierce",0)))
    var damage: int = maxi(1,int(spec["power"])+int(a["strength"])-armor)
    if bool(t["shield"]):
        damage = maxi(1,floori(float(damage)*0.75))
    return damage

func can_react(counter_id: int, target_id: int) -> bool:
    return has_unit(counter_id) and has_unit(target_id) and int(units[counter_id]["rp"]) > 0 and valid_attack(counter_id,target_id,"普攻") and zoc_threatens(units[counter_id],units[target_id]["pos"])

func counterstrike(counter_id: int, target_id: int, reason: String) -> void:
    if not can_react(counter_id,target_id):
        return
    units[counter_id]["rp"] = 0
    _resolve_one_hit(counter_id,target_id,"普攻",reason,true)
    check_outcome()

func _resolve_one_hit(attacker_id: int, target_id: int, skill_name: String, prefix: String, reaction: bool = false) -> bool:
    var a: Dictionary = units[attacker_id]
    var t: Dictionary = units[target_id]
    var chance: int = hit_chance(attacker_id,target_id,skill_name,reaction)
    var rolled: int = rng.randi_range(1,100)
    var hit: bool = rolled <= chance
    var damage: int = expected_damage(attacker_id,target_id,skill_name) if hit else 0
    events.append({"type":"attack","attacker":attacker_id,"target":target_id,"skill":skill_name,"reaction":reaction,"chance":chance,"roll":rolled,"hit":hit,"damage":damage})
    if not hit:
        push_log("%s%s对%s未命中（%d%%）。" % [a["name"],prefix,t["name"],chance])
        return false
    t["hp"] = maxi(0,int(t["hp"])-damage)
    t["guard"] = 0
    t["shield"] = false
    push_log("%s%s命中%s，造成%d伤害（%d%%）。" % [a["name"],prefix,t["name"],damage,chance])
    if int(t["hp"]) <= 0:
        push_log("%s倒下。" % t["name"])
    return true

func affected_targets(attacker_id: int, target_id: int, skill_name: String) -> Array[int]:
    var found: Array[int] = []
    if not valid_attack(attacker_id,target_id,skill_name):
        return found
    if str(skills[skill_name]["kind"]) != "line_aoe":
        found.append(target_id)
        return found
    var at: Vector2i = units[attacker_id]["pos"]
    var tg: Vector2i = units[target_id]["pos"]
    var d: Vector2i = Vector2i(signi(tg.x-at.x),signi(tg.y-at.y))
    for step in range(1,int(skills[skill_name]["range"])+1):
        var p: Vector2i = at+d*step
        if not board.melee_clear(at+d*(step-1),p):
            break
        var uid: int = living_at(p)
        if uid >= 0 and units[uid]["side"] != units[attacker_id]["side"]:
            found.append(uid)
    return found

func _hit_effects(attacker_id: int, target_id: int, skill_name: String) -> void:
    var target: Dictionary = units[target_id]
    if int(target["hp"]) <= 0:
        return
    var kind: String = str(skills[skill_name]["kind"])
    if kind == "seal":
        target["slow"] = 2
    if kind in ["push","push_spear"]:
        var at: Vector2i = units[attacker_id]["pos"]
        var tg: Vector2i = target["pos"]
        var dest: Vector2i = tg+Vector2i(signi(tg.x-at.x),signi(tg.y-at.y))
        if board.can_step(tg,dest,units,target_id):
            target["pos"] = dest

func _retreat(attacker_id: int, target_pos: Vector2i, skill_name: String) -> bool:
    var u: Dictionary = units[attacker_id]
    if str(skills[skill_name]["kind"]) != "melee_retreat" or bool(u["retreated"]):
        return false
    var at: Vector2i = u["pos"]
    var landing: Vector2i = at+Vector2i(signi(at.x-target_pos.x),signi(at.y-target_pos.y))
    if not board.can_step(at,landing,units,attacker_id):
        return false
    # B1 25.3 / 25.4: 回锋剑数据明确声明安全后撤；每行动一次。
    if not bool(skills[skill_name].get("retreat_safe",false)):
        for eid in opportunity_sources(attacker_id,at,landing):
            counterstrike(eid,attacker_id,"后撤借机攻击")
    u["retreated"] = true
    if int(u["hp"]) <= 0:
        return false
    u["pos"] = landing
    return true

func _counter_preview(counter_id: int, attacker_id: int) -> Dictionary:
    if not can_react(counter_id,attacker_id):
        return {}
    return {"source":counter_id,"chance":hit_chance(counter_id,attacker_id,"普攻",true),"damage":expected_damage(counter_id,attacker_id,"普攻")}

func attack_preview(attacker_id: int, target_id: int, skill_name: String) -> Dictionary:
    var preview: Dictionary = {"valid":false,"targets":[],"counter_on_hit":{},"counter_on_miss":{}}
    if not can_act(attacker_id) or not valid_attack(attacker_id,target_id,skill_name):
        return preview
    preview["valid"] = can_pay(attacker_id,skill_name)
    var spec: Dictionary = skills[skill_name]
    preview["ap_after"] = int(units[attacker_id]["ap"])-int(spec["ap"])
    preview["qi_after"] = int(units[attacker_id]["qi"])-int(spec["qi"])
    for uid in affected_targets(attacker_id,target_id,skill_name):
        preview["targets"].append({"id":uid,"chance":hit_chance(attacker_id,uid,skill_name),"damage":expected_damage(attacker_id,uid,skill_name)})
    # Simulate hit/miss branches on copies, using exactly the same displacement helpers.
    for did_hit in [true,false]:
        var sim = _preview_copy()
        var at: Vector2i = sim.units[attacker_id]["pos"]
        var tg: Vector2i = sim.units[target_id]["pos"]
        sim.units[attacker_id]["facing"] = Vector2i(signi(tg.x-at.x),signi(tg.y-at.y))
        if did_hit:
            sim.units[target_id]["hp"] = maxi(0,int(sim.units[target_id]["hp"])-sim.expected_damage(attacker_id,target_id,skill_name))
            sim._hit_effects(attacker_id,target_id,skill_name)
        sim._retreat(attacker_id,tg,skill_name)
        var suffix: String = "hit" if did_hit else "miss"
        preview["counter_on_"+suffix] = sim._counter_preview(target_id,attacker_id)
        preview["attacker_on_"+suffix] = sim.units[attacker_id]["pos"]
        preview["target_on_"+suffix] = sim.units[target_id]["pos"]
    return preview

func attack(attacker_id: int, target_id: int, skill_name: String) -> bool:
    if not can_act(attacker_id) or not valid_attack(attacker_id,target_id,skill_name) or not can_pay(attacker_id,skill_name):
        return false
    events.clear()
    var attacker: Dictionary = units[attacker_id]
    var old_pos: Vector2i = attacker["pos"]
    var target_pos: Vector2i = units[target_id]["pos"]
    consume(attacker_id,skill_name)
    attacker["facing"] = Vector2i(signi(target_pos.x-old_pos.x),signi(target_pos.y-old_pos.y))
    for uid in affected_targets(attacker_id,target_id,skill_name):
        if _resolve_one_hit(attacker_id,uid,skill_name,"施展"+skill_name):
            _hit_effects(attacker_id,uid,skill_name)
    if _retreat(attacker_id,target_pos,skill_name):
        push_log("%s回锋后撤一格（本次行动仅一次，免借机攻击）。" % attacker["name"])
    # Only the designated primary target may counter, including a missed attack.
    counterstrike(target_id,attacker_id,"自动反击")
    check_outcome()
    return true

func self_action(user_id: int, command: String) -> bool:
    if not can_act(user_id) or command not in ["调息","防御","守关式"] or not can_pay(user_id,command):
        return false
    events.clear()
    var u: Dictionary = units[user_id]
    consume(user_id,command)
    if command == "调息":
        var before: int = int(u["qi"])
        u["qi"] = mini(MAX_QI,before+4)
        u["rested"] = true
        push_log("%s调息恢复%d点内力（本次行动限一次）。" % [u["name"],int(u["qi"])-before])
    else:
        u["guard"] = 2 if command == "防御" else 0
        u["shield"] = command == "守关式"
        push_log("%s使用%s，下次命中时生效。" % [u["name"],command])
    events.append({"type":"self","unit":user_id,"skill":command})
    return true

func leap(user_id: int, goal: Vector2i) -> bool:
    if not can_act(user_id) or not can_pay(user_id,"燕行步") or not board.leap_allowed(units[user_id]["pos"],goal,units,user_id):
        return false
    events.clear()
    var u: Dictionary = units[user_id]
    var old: Vector2i = u["pos"]
    consume(user_id,"燕行步")
    u["pos"] = goal
    u["facing"] = Vector2i(signi(goal.x-old.x),signi(goal.y-old.y))
    u["leaped"] = true
    events.append({"type":"leap","unit":user_id,"from":old,"to":goal})
    push_log("%s施展燕行步，免疫本次位移的借机攻击。" % u["name"])
    return true

func check_outcome() -> void:
    if result != "" or units.is_empty():
        return
    if living_enemy_of("player").is_empty():
        result = "victory"
        push_log("胜利！劫客已全部击败。")
    elif living_enemy_of("enemy").is_empty():
        result = "defeat"
        push_log("失败：我方全部倒下。")
    if result != "":
        events.append({"type":"result","result":result})
