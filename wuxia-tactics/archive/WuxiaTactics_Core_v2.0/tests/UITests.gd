extends SceneTree
## 加载真实Main.tscn；经Viewport注入输入，覆盖HUD/模态框/延迟AI生命周期。
var failures: int = 0
var checks: int = 0
var ui

func expect(value: bool, name: String) -> void:
    checks += 1
    if value:
        print("PASS: "+name)
    else:
        failures += 1
        push_error("FAIL: "+name)

func _initialize() -> void:
    call_deferred("run")

func key(code: Key) -> void:
    var event := InputEventKey.new()
    event.keycode = code
    event.pressed = true
    root.push_input(event,true)
    event = InputEventKey.new()
    event.keycode = code
    event.pressed = false
    root.push_input(event,true)

func click(cell: Vector2i) -> void:
    var event := InputEventMouseButton.new()
    event.button_index = MOUSE_BUTTON_LEFT
    event.pressed = true
    event.position = ui._cell_pixel(cell)
    root.push_input(event,true)
    event = InputEventMouseButton.new()
    event.button_index = MOUSE_BUTTON_LEFT
    event.pressed = false
    event.position = ui._cell_pixel(cell)
    root.push_input(event,true)

func run() -> void:
    ui = load("res://scenes/Main.tscn").instantiate()
    root.add_child(ui)
    await process_frame
    await process_frame
    expect(ui.battle.active_id() == 0 and ui.buttons.size() == 11,"真实主场景加载完整HUD")
    expect(ui.buttons["重开"].get_global_rect().end.x <= root.get_visible_rect().size.x,"底部命令栏在基准视口内不溢出")
    var projection_ok: bool = true
    for y in range(12):
        for x in range(12):
            var cell := Vector2i(x,y)
            projection_ok = projection_ok and ui._pixel_cell(ui._cell_pixel(cell)) == cell
    expect(projection_ok,"12×12等距坐标选格往返正确")
    key(KEY_1)
    expect(ui.chosen == "破风剑","键盘1选择当前装备招式")
    key(KEY_ESCAPE)
    expect(ui.chosen == "移动","Esc取消选招")
    click(Vector2i(2,9))
    expect(ui.battle.units[0]["pos"] == Vector2i(2,9) and ui.battle.units[0]["ap"] == 5,"经Viewport鼠标点击实际移动并扣AP")
    key(KEY_SPACE)
    expect(ui.battle.active_id() == 3 and ui.enemy_busy,"空格只切换当前单位并安排敌方行动")
    expect(ui.buttons["武学1"].disabled and ui._resolve_button("武学1") == "","敌人无主动槽时HUD安全显示且禁用指令")
    await create_timer(0.45).timeout
    expect(ui.battle.active_id() == 1 and not ui.enemy_busy and ui.buttons["武学1"].text.contains("穿云枪"),"延迟敌方AI后正常轮到枪客并刷新武学")
    ui._new_battle()
    ui.battle.units[3]["pos"] = Vector2i(2,9)
    ui.battle.units[3]["facing"] = Vector2i(0,1)
    key(KEY_Q)
    click(Vector2i(2,9))
    expect(ui.battle.units[0]["ap"] == 3 and ui.battle.units[3]["rp"] == 0 and ui.battle.events.size() == 2,"经键鼠实际出招、扣资源并结算一次反击")
    ui._new_battle()
    ui.battle.units[3]["pos"] = Vector2i(2,9)
    ui.battle.units[3]["facing"] = Vector2i(0,1)
    click(Vector2i(2,11))
    expect(ui.confirm_move.visible and not ui.pending_route.is_empty() and ui.battle.units[0]["ap"] == 6,"危险点击先弹确认且不预扣AP")
    ui._end_turn()
    key(KEY_Q)
    click(Vector2i(1,10))
    expect(ui.battle.active_id() == 0 and ui.battle.units[0]["ap"] == 6 and ui.chosen == "移动","模态确认中不能穿透执行快捷键或棋盘点击")
    ui.confirm_move.get_cancel_button().pressed.emit()
    await process_frame
    expect(not ui.confirm_move.visible and ui.pending_route.is_empty() and ui.battle.units[0]["ap"] == 6,"取消危险移动清待执行路线且资源不变")
    expect(not ui.buttons["普攻"].disabled and not ui.buttons["结束行动"].disabled,"取消确认后立即恢复命令按钮可用状态")
    click(Vector2i(2,11))
    ui.confirm_move.get_ok_button().pressed.emit()
    await process_frame
    expect(not ui.confirm_move.visible and ui.battle.units[0]["pos"] == Vector2i(2,11) and ui.battle.units[3]["rp"] == 0,"确认危险移动实际执行并消耗对应RP")
    # 确认框打开时直接重建战斗：旧确认不得改变新战斗。
    ui._new_battle()
    ui.battle.units[3]["pos"] = Vector2i(2,9)
    click(Vector2i(2,11))
    ui._new_battle()
    ui._commit_pending_move()
    expect(ui.pending_route.is_empty() and not ui.confirm_move.visible and ui.battle.units[0]["pos"] == Vector2i(2,10),"重开关闭旧确认并使旧移动失效")
    # 延迟回调在重开前后两种竞争顺序都必须失效。
    ui._end_turn()
    ui._new_battle()
    await create_timer(0.4).timeout
    expect(ui.battle.active_id() == 0 and ui.battle.units[0]["ap"] == 6 and not ui.enemy_busy,"重开使尚未进入计时的旧AI回调失效")
    ui._end_turn()
    await process_frame
    ui._new_battle()
    await create_timer(0.4).timeout
    expect(ui.battle.active_id() == 0 and ui.battle.units[3]["pos"] == Vector2i(5,7),"重开使正在计时的旧AI回调失效")
    # HUD攻击预览必须取模型，不另掷骰，并显示击退条件分支。
    ui.battle.queue_index = ui.battle.order.find(2)
    ui.battle.units[2]["pos"] = Vector2i(5,9)
    ui.battle.units[3]["pos"] = Vector2i(5,8)
    ui.battle.units[3]["facing"] = Vector2i(0,1)
    ui._choose("武学1")
    var dice: int = ui.battle.rng.state
    ui._update_hover(Vector2i(5,8))
    var plan: Dictionary = ui.battle.attack_preview(2,3,"震山掌")
    expect(ui.battle.rng.state == dice and ui.preview_text.text.contains("命中%d%%" % plan["targets"][0]["chance"]) and ui.preview_text.text.contains("落空后"),"HUD命中/伤害和条件反击来自只读模型预览")
    ui.battle.units[3]["hp"] = 0
    ui.battle.units[4]["hp"] = 0
    ui.battle.check_outcome()
    ui._refresh()
    expect(ui.finished_dialog.visible and ui.finished_dialog.dialog_text.contains("胜利") and ui.buttons["普攻"].disabled,"胜利弹窗及指令锁定")
    ui._on_button("重开")
    expect(not ui.finished_dialog.visible and ui.battle.result == "" and ui.battle.active_id() == 0,"结果弹窗后重开关闭弹窗并恢复开局")
    for uid in [0,1,2]:
        ui.battle.units[uid]["hp"] = 0
    ui.battle.check_outcome()
    ui._refresh()
    expect(ui.finished_dialog.visible and ui.finished_dialog.dialog_text.contains("失败"),"失败弹窗")
    ui._on_button("重开")
    expect(ui.battle.units[0]["hp"] == 31 and not ui.finished_dialog.visible,"败北后重开恢复气血")
    ui.battle.units[3]["pos"] = Vector2i(2,9)
    ui.battle.units[0]["hp"] = 1
    ui.battle.units[3]["accuracy"] = 999
    ui.battle.rng.seed = 0
    ui._click_cell(Vector2i(2,11))
    ui._commit_pending_move()
    expect(ui.battle.units[0]["hp"] == 0 and ui.battle.active_id() == 3 and ui.enemy_busy,"危险确认中借机致死后UI自动推进，剩余队友可继续")
    ui._new_battle()
    await create_timer(0.4).timeout
    print("UI TEST RESULT: %d checks, %d failures" % [checks,failures])
    ui.queue_free()
    await process_frame
    quit(0 if failures == 0 else 1)
