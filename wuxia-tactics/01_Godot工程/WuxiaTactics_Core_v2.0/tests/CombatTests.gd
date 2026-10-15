extends SceneTree
## Run manually: godot --headless --path . --script res://tests/CombatTests.gd
const BattleState = preload("res://scripts/BattleState.gd")
const Board = preload("res://scripts/BattleBoard.gd")
const EnemyAI = preload("res://scripts/EnemyAI.gd")
var failures: int = 0

func expect_true(value: bool, name: String) -> void:
    if not value:
        failures += 1
        push_error("FAIL: " + name)
    else:
        print("PASS: " + name)

func _initialize() -> void:
    var state = BattleState.new()
    state.reset()
    expect_true(state.board.width == 12 and state.board.height == 12,"B1地图12×12")
    expect_true(state.order == [0,3,1,2,4],"角色速度交错排序")
    expect_true(state.board.travel_cost(Vector2i(3,7)) == 2,"泥地2AP")
    expect_true(state.board.travel_cost(Vector2i(1,10)) == 1,"普通地形1AP")
    expect_true(state.board.chebyshev(Vector2i(2,10),Vector2i(5,7)) == 3,"八方向距离")
    var source: Dictionary = state.units[3]
    var count: int = 0
    for delta in Board.DIRECTIONS:
        if state.zoc_threatens(source,source["pos"]+delta):
            count += 1
    expect_true(count == 5,"面向前侧5格控制区")
    expect_true(not state.zoc_threatens(source,source["pos"]+Vector2i(0,-1)),"背后控制盲区")
    expect_true(state.can_pay(0,"破风剑"),"初始资源足够施展破风剑")
    expect_true(state.self_action(0,"调息"),"允许主动调息")
    expect_true(not state.self_action(0,"调息"),"每次行动调息只允许一次")
    state.reset()
    state.units[3]["pos"] = Vector2i(2,9)
    state.units[3]["facing"] = Vector2i(0,1)
    expect_true(state.opportunity_sources(0,Vector2i(2,10),Vector2i(2,11)).size() == 1,"离开控制区预判借机攻击")
    var before_rp: int = int(state.units[3]["rp"])
    var route: Array[Vector2i] = [Vector2i(2,11)]
    state.movement(0,route)
    expect_true(before_rp == 1 and int(state.units[3]["rp"]) == 0,"借机攻击消耗敌方RP")
    state.reset()
    var id0: int = state.active_id()
    state.advance()
    expect_true(id0 == 0 and state.active_id() == 3,"我方剑客之后轮到敌方劫客")
    var ai = EnemyAI.new()
    ai.play(state)
    expect_true(int(state.units[3]["ap"]) < 6 or state.result != "","敌方AI执行移动或攻击")
    state.reset()
    state.units[3]["pos"] = Vector2i(2,9)
    state.units[3]["facing"] = Vector2i(0,1)
    var enemy_hp: int = int(state.units[3]["hp"])
    var ap: int = int(state.units[0]["ap"])
    expect_true(state.attack(0,3,"普攻"),"邻格普通攻击可执行")
    expect_true(int(state.units[0]["ap"]) == ap-3,"攻击后按规则扣除3AP")
    expect_true(int(state.units[3]["hp"]) <= enemy_hp,"攻击不治疗敌人")
    state.reset()
    state.units[3]["hp"] = 0
    state.units[4]["hp"] = 0
    state.check_outcome()
    expect_true(state.result == "victory","全部敌方阵亡触发胜利")
    print("TEST RESULT: %d failures" % failures)
    quit(0 if failures == 0 else 1)
