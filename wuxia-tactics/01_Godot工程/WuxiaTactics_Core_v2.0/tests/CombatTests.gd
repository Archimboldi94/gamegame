extends SceneTree
## 引擎原生、固定种子回归测试；不以源码字符串存在替代行为验证。
const BattleState = preload("res://scripts/BattleState.gd")
const Board = preload("res://scripts/BattleBoard.gd")
const EnemyAI = preload("res://scripts/EnemyAI.gd")
var failures: int = 0
var checks: int = 0

func expect_true(value: bool, name: String) -> void:
    checks += 1
    if value:
        print("PASS: "+name)
    else:
        failures += 1
        push_error("FAIL: "+name)

func fresh():
    var s = BattleState.new()
    s.reset(20261015)
    return s

func arena():
    var s = fresh()
    s.board.cells.assign(["............","............","............","............","............","............","............","............","............","............","............","............"])
    var positions: Array[Vector2i] = [Vector2i(5,5),Vector2i(0,10),Vector2i(1,10),Vector2i(5,4),Vector2i(10,0)]
    for i in range(5):
        s.units[i]["pos"] = positions[i]
        s.units[i]["hp"] = 100
        s.units[i]["max_hp"] = 100
    s.units[3]["facing"] = Vector2i(0,1)
    return s

func tile_set(s, cell: Vector2i, value: String) -> void:
    var row: String = s.board.cells[cell.y]
    s.board.cells[cell.y] = row.substr(0,cell.x)+value+row.substr(cell.x+1)

func force_next(s, will_hit: bool, chance: int) -> void:
    var probe := RandomNumberGenerator.new()
    for seed_no in range(10000):
        probe.seed = seed_no
        if (probe.randi_range(1,100) <= chance) == will_hit:
            s.rng.seed = seed_no
            return
    expect_true(false,"可找到命中/未命中种子")

func _initialize() -> void:
    test_board()
    test_turns_resources()
    test_reactions()
    test_skills_previews()
    test_ai_outcomes()
    print("TEST RESULT: %d checks, %d failures" % [checks,failures])
    quit(0 if failures == 0 else 1)

func test_board() -> void:
    var s = fresh()
    expect_true(s.board.width == 12 and s.board.height == 12 and s.units.size() == 5,"B1地图12×12、3我方2敌方")
    expect_true(s.units[0]["pos"] == Vector2i(2,10) and s.units[3]["pos"] == Vector2i(5,7),"地图marker驱动部署")
    expect_true(s.board.travel_cost(Vector2i(3,7)) == 2 and s.board.travel_cost(Vector2i(2,10)) == 1,"泥地2AP、普通1AP")
    s = arena()
    var route: Array[Vector2i] = s.board.path(Vector2i(5,5),Vector2i(8,8),s.units,0)
    expect_true(route.size() == 3 and s.board.path_ap(route) == 3,"空地八方向最短路径与斜移1AP")
    tile_set(s,Vector2i(6,5),"C")
    tile_set(s,Vector2i(5,6),"C")
    s.units[3]["pos"] = Vector2i(6,6)
    expect_true(not s.board.can_step(Vector2i(5,5),Vector2i(6,6),s.units,0),"禁止封闭墙角斜移")
    expect_true(not s.valid_attack(0,3,"普攻") and not s.zoc_threatens(s.units[0],Vector2i(6,6)),"禁止隔封闭墙角攻击及控制区")
    expect_true(not s.board.line_clear(Vector2i(5,5),Vector2i(7,7)),"直线武学不穿封闭斜角")
    s = arena()
    s.units[3]["pos"] = Vector2i(6,5)
    route = s.board.path(Vector2i(5,5),Vector2i(7,5),s.units,0)
    expect_true(not route.is_empty() and Vector2i(6,5) not in route,"绕过活单位占格")
    expect_true(s.board.path(Vector2i(5,5),Vector2i(6,5),s.units,0).is_empty(),"占格不可作为终点")
    var bad_route: Array[Vector2i] = [Vector2i(5,6),Vector2i(9,9)]
    var before: Array = s.units.duplicate(true)
    expect_true(not s.movement(0,bad_route) and before == s.units,"非法后半段路径整体拒绝且不扣资源")
    expect_true(not s.board.leap_allowed(Vector2i(5,5),Vector2i(-1,5),s.units,0),"轻功拒绝越界及超距")
    tile_set(s,Vector2i(6,5),"C")
    expect_true(not s.board.leap_allowed(Vector2i(5,5),Vector2i(8,7),s.units,0),"非轴向轻功检测全部经过格，不穿货箱")
    tile_set(s,Vector2i(6,5),"h")
    s.units[3]["pos"] = Vector2i(11,0)
    expect_true(s.board.leap_allowed(Vector2i(5,5),Vector2i(8,7),s.units,0),"轻功可越低矮障碍")
    tile_set(s,Vector2i(6,5),"H")
    tile_set(s,Vector2i(5,6),"C")
    expect_true(not s.board.leap_allowed(Vector2i(5,5),Vector2i(6,6),s.units,0),"轻功不可穿封闭高墙角")
    s = arena()
    tile_set(s,Vector2i(5,6),"m")
    route = [Vector2i(5,6)]
    expect_true(s.movement(0,route) and int(s.units[0]["ap"]) == 4,"实际进入泥地扣2AP")
    s.units[0]["ap"] = 1
    before = s.units.duplicate(true)
    route = [Vector2i(6,7),Vector2i(7,8)]
    expect_true(not s.movement(0,route) and before == s.units,"AP不足拒绝整个移动")

func test_turns_resources() -> void:
    var s = fresh()
    expect_true(s.order == [0,3,1,2,4],"速度交错队列")
    s.units[0]["rp"] = 0
    s.units[3]["qi"] = 10
    s.units[3]["slow"] = 2
    s.units[3]["guard"] = 2
    s.advance()
    expect_true(s.active_id() == 3 and int(s.active()["ap"]) == 4 and int(s.active()["qi"]) == 11,"下一单位开始恢复内力并应用AP削减")
    expect_true(int(s.active()["slow"]) == 0 and int(s.active()["guard"]) == 0 and int(s.units[0]["rp"]) == 0,"行动开始清状态但不恢复RP")
    s.units[4]["speed"] = 99
    expect_true(s.order == [0,3,1,2,4],"速度中途变化不打乱本轮队列")
    for _i in range(4):
        s.advance()
    expect_true(s.round_no == 2 and s.active_id() == 4 and s.order == [4,0,3,1,2],"新轮重新按速度排序")
    expect_true(int(s.units[0]["rp"]) == 1,"RP仅在新轮统一恢复")
    s = fresh()
    s.units[3]["hp"] = 0
    s.advance()
    expect_true(s.active_id() == 1,"跳过阵亡单位")
    s = arena()
    s.units[0]["qi"] = 7
    expect_true(s.self_action(0,"调息") and int(s.units[0]["qi"]) == 11 and int(s.units[0]["ap"]) == 3,"调息恢复4内力并扣3AP")
    expect_true(not s.can_pay(0,"调息") and not s.self_action(0,"调息"),"每次行动调息限一次，按钮可用性一致")
    expect_true(not s.self_action(1,"防御") and not s.attack(3,0,"普攻"),"禁止非当前单位主动操作")
    s = arena()
    s.units[0]["qi"] = 0
    expect_true(not s.attack(0,3,"破风剑") and int(s.units[0]["ap"]) == 6,"内力不足不支付AP")
    expect_true(not s.can_pay(0,"穿云枪") and not s.self_action(3,"守关式"),"不能使用未装备招式")
    s = arena()
    expect_true(s.self_action(0,"防御") and s.self_action(0,"守关式") and int(s.units[0]["guard"]) == 0 and s.units[0]["shield"],"防御与护势互斥替换")
    s.start_current()
    expect_true(not s.units[0]["shield"] and int(s.units[0]["ap"]) == 6,"下一自身行动清防御并恢复AP")
    expect_true(s.leap(0,Vector2i(7,6)) and not s.can_pay(0,"燕行步") and not s.leap(0,Vector2i(8,6)),"轻功每次行动限一次并支付2AP4内力")
    expect_true(int(s.units[0]["ap"]) == 4 and int(s.units[0]["qi"]) == 7,"轻功资源不额外按格扣除")

func test_reactions() -> void:
    var s = arena()
    for f in Board.DIRECTIONS:
        s.units[0]["facing"] = f
        var count: int = 0
        for d in Board.DIRECTIONS:
            count += int(s.zoc_threatens(s.units[0],Vector2i(5,5)+d))
        expect_true(count == 5,"八向朝向%s均严格五格控制区" % f)
    s = arena()
    s.units[3]["pos"] = Vector2i(4,4)
    s.units[3]["facing"] = Vector2i(1,1)
    s.units[4]["pos"] = Vector2i(6,4)
    s.units[4]["facing"] = Vector2i(-1,1)
    var route: Array[Vector2i] = [Vector2i(5,6)]
    expect_true(s.opportunity_sources(0,Vector2i(5,5),Vector2i(5,6)) == [3],"同时离开两人控制区仅速度最快者借机")
    s.units[4]["speed"] = 76
    expect_true(s.opportunity_sources(0,Vector2i(5,5),Vector2i(5,6)) == [3],"借机同速按稳定ID排序")
    s.units[4]["speed"] = 45
    s.movement(0,route)
    expect_true(int(s.units[3]["rp"]) == 0 and int(s.units[4]["rp"]) == 1,"同一步仅消耗一名反应者RP")
    s = arena()
    s.units[3]["pos"] = Vector2i(4,4)
    s.units[3]["facing"] = Vector2i(1,1)
    s.units[4]["pos"] = Vector2i(6,5)
    s.units[4]["facing"] = Vector2i(-1,1)
    route = [Vector2i(5,6),Vector2i(5,7)]
    var plan: Dictionary = s.movement_preview(0,route)
    var rng_before: int = s.rng.state
    s.movement_preview(0,route)
    expect_true(s.rng.state == rng_before and plan["risks"].size() == 2,"移动风险逐步模拟并不掷骰")
    s.movement(0,route)
    var reactions: Array = s.events.filter(func(e): return e["type"] == "attack")
    expect_true(reactions.size() == 2 and int(reactions[0]["attacker"]) == 3 and int(reactions[1]["attacker"]) == 4,"后续步骤可触发第二名敌人")
    expect_true(int(reactions[0]["chance"]) == int(plan["risks"][0]["chance"]) and int(reactions[1]["chance"]) == int(plan["risks"][1]["chance"]),"移动预览面向与实际借机命中率一致")
    s = arena()
    s.units[0]["hp"] = 1
    force_next(s,true,s.hit_chance(3,0,"普攻",true))
    route = [Vector2i(5,6),Vector2i(5,7)]
    s.movement(0,route)
    expect_true(int(s.units[0]["hp"]) == 0 and s.units[0]["pos"] == Vector2i(5,5) and int(s.units[0]["ap"]) == 5,"借机致死：已尝试步扣AP、留原格、后续步不扣")
    s.advance()
    expect_true(s.active_id() == 3,"当前单位途中阵亡后队列可继续")
    s = arena()
    expect_true(s.hit_chance(3,0,"普攻",true) == s.hit_chance(3,0,"普攻")-10,"反应攻击应用命中减10百分点")
    s.attack(0,3,"普攻")
    expect_true(s.events.size() == 2 and int(s.units[0]["rp"]) == 1 and int(s.units[3]["rp"]) == 0,"自动反击不递归且反击与借机共享RP")
    expect_true(int(s.units[3]["ap"]) == 6 and int(s.units[3]["qi"]) == 8,"反应不消耗AP内力")
    route = [Vector2i(5,6)]
    expect_true(s.risky_route(0,route).is_empty(),"已耗尽RP不再预览借机风险")
    s = arena()
    s.units[3]["facing"] = Vector2i(0,-1)
    s.attack(0,3,"普攻")
    expect_true(int(s.units[3]["rp"]) == 1 and s.events.size() == 1,"背袭不触发反击")
    s = arena()
    s.units[3]["guard"] = 2
    force_next(s,false,s.hit_chance(0,3,"回锋剑"))
    var target_hp: int = s.units[3]["hp"]
    s.attack(0,3,"回锋剑")
    expect_true(int(s.units[0]["ap"]) == 3 and int(s.units[0]["qi"]) == 10 and int(s.units[3]["hp"]) == target_hp and int(s.units[3]["guard"]) == 2,"未命中仍扣AP内力、不扣血不消耗目标防御")
    s = arena()
    force_next(s,false,s.hit_chance(0,3,"普攻"))
    s.attack(0,3,"普攻")
    expect_true(not s.events[0]["hit"] and s.events.size() == 2 and s.events[1]["reaction"],"有效近身攻击落空仍可被反击")

func test_skills_previews() -> void:
    var s = arena()
    s.units[3]["armor"] = 0
    s.units[0]["armor"] = 2
    s.units[0]["shield"] = true
    expect_true(s.expected_damage(3,0,"普攻") == 6,"护势按floor取整，9×0.75=6")
    s.units[3]["armor"] = 99
    expect_true(s.expected_damage(0,3,"普攻") == 1,"护甲不产生负伤害，最低1")
    s.units[3]["armor"] = 2
    s.units[3]["guard"] = 2
    expect_true(s.expected_damage(0,3,"破风剑") == 11,"破甲作用于包含防御加值的有效护甲")
    for hit in [true,false]:
        s = arena()
        s.queue_index = s.order.find(2)
        s.units[2]["pos"] = Vector2i(5,5)
        s.units[0]["pos"] = Vector2i(0,10)
        var before: Array = s.units.duplicate(true)
        var dice: int = s.rng.state
        var preview: Dictionary = s.attack_preview(2,3,"震山掌")
        expect_true(s.units == before and s.rng.state == dice,"攻击预览不修改状态或随机数（%s）" % hit)
        expect_true(preview["counter_on_hit"].is_empty() and not preview["counter_on_miss"].is_empty(),"击退命中/落空分支反击预览")
        force_next(s,hit,s.hit_chance(2,3,"震山掌"))
        s.attack(2,3,"震山掌")
        var suffix: String = "hit" if hit else "miss"
        expect_true(s.units[3]["pos"] == preview["target_on_"+suffix] and int(s.events[0]["chance"]) == int(preview["targets"][0]["chance"]),"击退实际落点和命中率等于预览（%s）" % hit)
        expect_true(s.events.size() == (1 if hit else 2),"击退后射程外不反击；落空仍反击（%s）" % hit)
        if hit:
            expect_true(int(s.events[0]["damage"]) == int(preview["targets"][0]["damage"]),"命中伤害与HUD预览同源")
    s = arena()
    s.queue_index = s.order.find(2)
    s.units[2]["pos"] = Vector2i(5,5)
    s.units[0]["pos"] = Vector2i(0,10)
    tile_set(s,Vector2i(5,3),"C")
    force_next(s,true,s.hit_chance(2,3,"震山掌"))
    s.attack(2,3,"震山掌")
    expect_true(s.units[3]["pos"] == Vector2i(5,4) and s.events.size() == 2,"击退撞障碍只伤害、目标留原格可反击")
    s = arena()
    force_next(s,false,s.hit_chance(0,3,"回锋剑"))
    var retreat_plan: Dictionary = s.attack_preview(0,3,"回锋剑")
    s.attack(0,3,"回锋剑")
    expect_true(s.units[0]["pos"] == Vector2i(5,6) and s.units[0]["pos"] == retreat_plan["attacker_on_miss"] and int(s.units[3]["rp"]) == 1,"回锋落空也后撤、明确豁免借机且脱离反击距离")
    s.units[3]["pos"] = Vector2i(5,5)
    s.attack(0,3,"回锋剑")
    expect_true(s.units[0]["pos"] == Vector2i(5,6),"同次行动第二次回锋不再次后撤")
    s = arena()
    s.units[4]["pos"] = Vector2i(5,3)
    var aoe: Dictionary = s.attack_preview(0,3,"破风剑")
    s.attack(0,3,"破风剑")
    expect_true(aoe["targets"].size() == 2 and s.events.size() == 3 and int(s.units[4]["rp"]) == 1,"直线AOE独立骰、仅相邻主目标可反击")
    s = arena()
    s.queue_index = s.order.find(1)
    s.units[1]["pos"] = Vector2i(5,6)
    s.units[0]["pos"] = Vector2i(0,10)
    expect_true(s.valid_attack(1,3,"穿云枪"),"枪法恰好2格八向直线")
    s.units[0]["pos"] = Vector2i(5,5)
    expect_true(not s.valid_attack(1,3,"穿云枪"),"枪法中间单位阻挡")
    s.units[0]["pos"] = Vector2i(0,10)
    tile_set(s,Vector2i(5,5),"C")
    expect_true(not s.valid_attack(1,3,"穿云枪"),"枪法中间实体阻挡")
    s = arena()
    s.queue_index = s.order.find(2)
    s.units[2]["pos"] = Vector2i(5,5)
    s.units[0]["pos"] = Vector2i(0,10)
    force_next(s,true,s.hit_chance(2,3,"截脉指"))
    s.attack(2,3,"截脉指")
    expect_true(int(s.units[3]["slow"]) == 2,"截脉指命中施加下次AP−2")
    s.queue_index = s.order.find(3)
    s.start_current()
    expect_true(int(s.units[3]["ap"]) == 4 and int(s.units[3]["slow"]) == 0,"截脉指仅影响下一自身行动")

func player_turn(s, use_skills: bool) -> void:
    var uid: int = s.active_id()
    for _try in range(8):
        if not s.can_act(uid):
            return
        var selected: String = ""
        var target_id: int = -1
        var best: float = -1.0
        var available: Array = ["普攻"]
        if use_skills:
            available.append_array(s.units[uid]["skills"])
        for enemy in s.living_enemy_of("player"):
            for skill in available:
                if s.valid_attack(uid,enemy,skill) and s.can_pay(uid,skill):
                    var score: float = float(s.expected_damage(uid,enemy,skill))*float(s.hit_chance(uid,enemy,skill))/float(s.skills[skill]["ap"])
                    if score > best:
                        best = score
                        selected = skill
                        target_id = enemy
        if target_id >= 0:
            s.attack(uid,target_id,selected)
            continue
        var best_route: Array[Vector2i] = []
        var best_cost: int = 999
        for enemy in s.living_enemy_of("player"):
            for d in Board.DIRECTIONS:
                var goal: Vector2i = s.units[enemy]["pos"]+d
                if not s.board.melee_clear(goal,s.units[enemy]["pos"]):
                    continue
                var route: Array[Vector2i] = s.board.path(s.units[uid]["pos"],goal,s.units,uid)
                if not route.is_empty() and s.board.path_ap(route) < best_cost:
                    best_route = route
                    best_cost = s.board.path_ap(route)
        var prefix: Array[Vector2i] = []
        var spent: int = 0
        for p in best_route:
            spent += s.board.travel_cost(p)
            if spent > int(s.units[uid]["ap"]):
                break
            prefix.append(p)
        if prefix.is_empty() or not s.movement(uid,prefix):
            return

func test_ai_outcomes() -> void:
    var s = arena()
    s.queue_index = s.order.find(3)
    for d in Board.DIRECTIONS:
        tile_set(s,s.units[3]["pos"]+d,"C")
    var ai = EnemyAI.new()
    ai.play(s)
    expect_true(int(s.units[3]["ap"]) == 6 and s.result == "","AI无路可走能有限返回，不隔墙攻击")
    s = fresh()
    s.advance()
    ai.play(s)
    expect_true(int(s.units[3]["ap"]) < 6,"真实B1敌方主动接敌或攻击")
    for game in range(3):
        s = fresh()
        s.rng.seed = 1234+game
        var turns: int = 0
        var invariant: bool = true
        while s.result == "" and turns < 200:
            if s.active()["side"] == "enemy":
                ai.play(s)
            elif game != 1:
                player_turn(s,game == 2)
            for u in s.units:
                invariant = invariant and int(u["ap"]) >= 0 and int(u["qi"]) >= 0 and int(u["qi"]) <= 12 and int(u["rp"]) in [0,1]
                if int(u["hp"]) > 0:
                    invariant = invariant and not s.board.solid(u["pos"]) and not s.board.occupied(u["pos"],s.units,int(u["id"]))
            s.advance()
            turns += 1
        print("B1 SIMULATION %d: seed=%d result=%s rounds=%d activations=%d" % [game+1,1234+game,s.result,s.round_no,turns])
        expect_true(s.result == "victory" and invariant,"完整B1第%d局：胜负与全程资源/占格约束" % (game+1))
        var old_order: Array = s.order.duplicate()
        var old_units: Array = s.units.duplicate(true)
        s.advance()
        expect_true(s.order == old_order and s.units == old_units and not s.self_action(s.active_id(),"防御"),"战斗结束禁止继续行动")
        s.reset(42)
        expect_true(s.result == "" and s.round_no == 1 and s.active_id() == 0 and s.units[0]["hp"] == 31 and s.units[0]["pos"] == Vector2i(2,10) and s.events.is_empty(),"胜负后重开完全复位")
    # 原始参数下纯待机也可能靠自动反击获胜；用濒死局面覆盖真实AI击杀→败北流程。
    s = fresh()
    for u in s.units:
        if u["side"] == "player":
            u["hp"] = 1
    var turns: int = 0
    while s.result == "" and turns < 100:
        if s.active()["side"] == "enemy":
            ai.play(s)
        s.advance()
        turns += 1
    expect_true(s.result == "defeat","濒死B1局面经真实敌方AI攻击至队伍全灭")
    print("B1 DEFEAT FIXTURE: result=%s rounds=%d activations=%d (player HP=1)" % [s.result,s.round_no,turns])
