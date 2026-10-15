extends Control
## Playable B1 visual/controller. All rules live in BattleState/BattleBoard.
const BattleState = preload("res://scripts/BattleState.gd")
const BattleBoard = preload("res://scripts/BattleBoard.gd")
const EnemyAI = preload("res://scripts/EnemyAI.gd")
const TILE_HALF := Vector2(30.0,15.0)
const ORIGIN := Vector2(640.0,110.0)
const COLOR_BASE := Color("#6b826f")
const COLOR_WATER := Color("#386779")
const COLOR_WOOD := Color("#9b7d5b")
const COLOR_MUD := Color("#9d8865")
const COLOR_WALL := Color("#3f4a4c")

var battle = BattleState.new()
var ai = EnemyAI.new()
var chosen: String = "移动"
var hovered: Vector2i = Vector2i(-99,-99)
var hovered_route: Array[Vector2i] = []
var pending_route: Array[Vector2i] = []
var pending_actor: int = -1
var pending_generation: int = -1
var turn_text: Label
var status_text: Label
var info_text: Label
var obj_text: Label
var preview_panel: PanelContainer
var preview_text: Label
var logs_panel: PanelContainer
var logs_text: Label
var confirm_move: ConfirmationDialog
var finished_dialog: AcceptDialog
var buttons: Dictionary = {}
var buttons_bar: HBoxContainer
var finished_popup_shown: bool = false
var enemy_busy: bool = false
var battle_generation: int = 0

func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    _create_ui()
    _new_battle()

func _new_battle() -> void:
    battle_generation += 1
    enemy_busy = false
    finished_popup_shown = false
    confirm_move.hide()
    finished_dialog.hide()
    _clear_pending()
    battle.reset()
    chosen = "移动"
    hovered = Vector2i(-99,-99)
    hovered_route.clear()
    pending_route.clear()
    preview_panel.hide()
    logs_panel.hide()
    _refresh()

func _panel_style(bg: Color, edge: Color) -> StyleBoxFlat:
    var style := StyleBoxFlat.new()
    style.bg_color = bg
    style.border_color = edge
    style.set_border_width_all(1)
    style.set_corner_radius_all(6)
    style.set_content_margin_all(10)
    return style

func _label(value: String, size_px: int, tint: Color) -> Label:
    var lbl := Label.new()
    lbl.text = value
    lbl.add_theme_font_size_override("font_size",size_px)
    lbl.add_theme_color_override("font_color",tint)
    lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
    return lbl

func _create_ui() -> void:
    var top := PanelContainer.new()
    top.position = Vector2(12,8)
    top.size = Vector2(1256,76)
    top.add_theme_stylebox_override("panel",_panel_style(Color("#17252ded"),Color("#758b86")))
    add_child(top)
    var top_row := HBoxContainer.new()
    top_row.add_theme_constant_override("separation",24)
    top.add_child(top_row)
    turn_text = _label("",17,Color("#f0ead9"))
    turn_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    turn_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    top_row.add_child(turn_text)
    obj_text = _label("B1 渡口截箱 | 消灭2名劫客",15,Color("#bddad0"))
    top_row.add_child(obj_text)

    var bottom := PanelContainer.new()
    bottom.position = Vector2(12,565)
    bottom.size = Vector2(1256,144)
    bottom.add_theme_stylebox_override("panel",_panel_style(Color("#17252df5"),Color("#758b86")))
    add_child(bottom)
    var content := VBoxContainer.new()
    content.add_theme_constant_override("separation",7)
    bottom.add_child(content)
    info_text = _label("",15,Color("#f2e5cf"))
    content.add_child(info_text)
    buttons_bar = HBoxContainer.new()
    buttons_bar.add_theme_constant_override("separation",6)
    content.add_child(buttons_bar)
    for key in ["移动","普攻","武学1","武学2","武学3","燕行步","防御","调息","结束行动","日志","重开"]:
        var btn := Button.new()
        btn.text = key
        btn.focus_mode = Control.FOCUS_NONE
        btn.custom_minimum_size = Vector2(93.0,39.0)
        if key == "结束行动":
            btn.custom_minimum_size.x = 128.0
        btn.pressed.connect(_on_button.bind(key))
        if key in ["普攻","武学1","武学2","武学3","燕行步","防御","调息"]:
            btn.mouse_entered.connect(_on_action_hover.bind(key))
            btn.mouse_exited.connect(_on_action_leave)
        buttons_bar.add_child(btn)
        buttons[key] = btn
    status_text = _label("",13,Color("#c6d1c8"))
    content.add_child(status_text)

    preview_panel = PanelContainer.new()
    preview_panel.position = Vector2(952,150)
    preview_panel.size = Vector2(302,210)
    preview_panel.add_theme_stylebox_override("panel",_panel_style(Color("#172630f4"),Color("#829f9b")))
    add_child(preview_panel)
    preview_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
    preview_text = _label("",15,Color("#f1e8d5"))
    preview_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    preview_panel.add_child(preview_text)
    preview_panel.hide()

    logs_panel = PanelContainer.new()
    logs_panel.position = Vector2(15,202)
    logs_panel.size = Vector2(305,275)
    logs_panel.add_theme_stylebox_override("panel",_panel_style(Color("#172630ef"),Color("#728e85")))
    add_child(logs_panel)
    var log_scroll := ScrollContainer.new()
    log_scroll.custom_minimum_size = Vector2(285,255)
    logs_panel.add_child(log_scroll)
    logs_text = _label("",14,Color("#ece3d1"))
    logs_text.custom_minimum_size.x = 265
    logs_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    logs_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    log_scroll.add_child(logs_text)
    logs_panel.hide()

    confirm_move = ConfirmationDialog.new()
    confirm_move.title = "移动路线存在反击风险"
    confirm_move.ok_button_text = "仍然移动"
    confirm_move.dialog_text = "这段路径可能遭到借机攻击，是否继续？"
    add_child(confirm_move)
    confirm_move.confirmed.connect(_commit_pending_move)
    confirm_move.canceled.connect(_cancel)
    confirm_move.close_requested.connect(_cancel)

    finished_dialog = AcceptDialog.new()
    finished_dialog.title = "战斗结果"
    finished_dialog.ok_button_text = "关闭（可点击重开）"
    add_child(finished_dialog)

func _resolve_button(key: String) -> String:
    if key == "武学1" or key == "武学2" or key == "武学3":
        var idx: int = int(key.right(1))-1
        var equipped: Array = battle.active().get("skills",[])
        return str(equipped[idx]) if idx < equipped.size() else ""
    return key

func _on_button(key: String) -> void:
    if key == "重开":
        _new_battle()
        return
    if key == "日志":
        logs_panel.visible = not logs_panel.visible
        return
    if key == "结束行动":
        _end_turn()
        return
    _choose(key)

func _unhandled_input(event: InputEvent) -> void:
    if not _active_usable():
        return
    if event is InputEventKey and event.pressed and not event.echo:
        match event.keycode:
            KEY_ESCAPE: _cancel()
            KEY_SPACE: _end_turn()
            KEY_Q: _choose("普攻")
            KEY_1: _choose("武学1")
            KEY_2: _choose("武学2")
            KEY_3: _choose("武学3")
            KEY_E: _choose("燕行步")
            KEY_F: _choose("防御")
            KEY_R: _choose("调息")
            KEY_M: _choose("移动")
    elif event is InputEventMouseButton and event.pressed:
        if event.button_index == MOUSE_BUTTON_RIGHT:
            _cancel()
        elif event.button_index == MOUSE_BUTTON_LEFT:
            if event.position.y <= 91 or event.position.y >= 555:
                return
            if logs_panel.visible and Rect2(logs_panel.position,logs_panel.size).has_point(event.position):
                return
            _click_cell(_pixel_cell(event.position))

func _process(_delta: float) -> void:
    if not _active_usable():
        return
    var m: Vector2 = get_viewport().get_mouse_position()
    if m.y <= 90 or m.y >= 556:
        return
    if logs_panel.visible and Rect2(logs_panel.position,logs_panel.size).has_point(m):
        return
    var cell: Vector2i = _pixel_cell(m)
    if cell != hovered:
        _update_hover(cell)

func _active_usable() -> bool:
    return not enemy_busy and battle.result == "" and not battle.active().is_empty() and battle.active()["side"] == "player" and not confirm_move.visible

func _refresh() -> void:
    if battle.units.is_empty():
        return
    var queue_parts: Array[String] = []
    for idx in range(battle.order.size()):
        var id: int = battle.order[idx]
        var unit: Dictionary = battle.units[id]
        if int(unit["hp"]) <= 0:
            continue
        var prefix := "▶" if id == battle.active_id() else ""
        queue_parts.append(prefix+str(unit["name"])+"("+str(unit["speed"])+")")
    turn_text.text = "第%d轮   %s" % [battle.round_no,"  →  ".join(PackedStringArray(queue_parts))]
    var u: Dictionary = battle.active()
    info_text.text = "%s     HP %d/%d     AP %d/6     内力 %d/12     RP %d/1     当前：%s" % [u["name"],u["hp"],u["max_hp"],u["ap"],u["qi"],u["rp"],chosen]
    status_text.text = battle.log_lines[0] if not battle.log_lines.is_empty() else ""
    logs_text.text = "战斗日志（最新在上）\n\n" + "\n".join(PackedStringArray(battle.log_lines))
    for key in buttons:
        var btn: Button = buttons[key]
        var name: String = _resolve_button(key) if key in ["武学1","武学2","武学3"] else str(key)
        btn.text = "%s %s" % [key,name if name != "" else "—"] if key.begins_with("武学") else name
        if key in ["日志","重开"]:
            btn.disabled = false
            continue
        btn.disabled = not _active_usable()
        if key not in ["移动","结束行动","日志","重开"]:
            btn.disabled = btn.disabled or not battle.can_pay(battle.active_id(),name)
            if name == "调息" and bool(u["rested"]):
                btn.disabled = true
        btn.modulate = Color("#eed9a4") if name == chosen and key != "结束行动" else Color.WHITE
    queue_redraw()
    _check_finished()

func _check_finished() -> void:
    if battle.result == "" or finished_popup_shown:
        return
    finished_popup_shown = true
    finished_dialog.dialog_text = "胜利！两名劫客被击败。" if battle.result == "victory" else ("关卡数据加载失败，请查看日志。" if battle.result == "error" else "失败：三名队员全部倒下。")
    finished_dialog.popup_centered()

func _choose(key: String) -> void:
    if not _active_usable():
        return
    var name: String = _resolve_button(key)
    if name in ["调息","防御","守关式"]:
        if not battle.self_action(battle.active_id(),name):
            battle.push_log("资源不足或本次行动已调息，指令未执行。")
        chosen = "移动"
        _update_hover(hovered)
        _refresh()
        return
    if name != "移动" and not battle.can_pay(battle.active_id(),name):
        battle.push_log("AP或内力不足。")
        _refresh()
        return
    chosen = name
    if battle.board.inside(hovered):
        _update_hover(hovered)
    else:
        preview_panel.hide()
    _refresh()

func _on_action_hover(key: String) -> void:
    if not _active_usable():
        return
    var name: String = _resolve_button(key)
    if not battle.skills.has(name):
        return
    var spec: Dictionary = battle.skills[name]
    preview_text.text = "%s\n消耗：%d AP / %d内力\n\n%s" % [name,spec["ap"],spec["qi"],_action_description(name)]
    preview_panel.show()

func _action_description(name: String) -> String:
    match name:
        "破风剑": return "3格八方向直线剑气，沿途敌人分别判定命中。"
        "回锋剑": return "近战攻击后自动沿反方向免费后撤1格；每次行动一次，免借机攻击；落点不合法则留在原地。"
        "穿云枪": return "恰好2格的直线枪击，破甲1。"
        "挑枪": return "恰好2格直线攻击，命中后击退1格。"
        "震山掌": return "近身攻击，命中后击退1格。"
        "截脉指": return "2格内直线攻击，命中后降低敌人下次行动2AP。"
        "守关式": return "下次被命中伤害减25%，与防御护甲互斥。"
        "普攻": return "相邻一格攻击，符合条件可触发反击。"
        "燕行步": return "3格内轻功跳跃，能越过低障碍，免借机攻击；每次行动一次。"
        "防御": return "下次命中护甲+2。"
        "调息": return "恢复4内力（不超过上限），本次行动限一次。"
        _: return ""

func _on_action_leave() -> void:
    _update_hover(hovered)

func _update_hover(cell: Vector2i) -> void:
    hovered = cell
    preview_panel.position.x = 20.0 if _cell_pixel(cell).x > 900.0 else 952.0
    hovered_route.clear()
    if not battle.board.inside(cell) or not _active_usable():
        preview_panel.hide()
        queue_redraw()
        return
    var uid: int = battle.living_at(cell)
    if chosen == "移动":
        hovered_route = battle.board.path(battle.active()["pos"],cell,battle.units,battle.active_id())
        if hovered_route.is_empty():
            preview_panel.hide()
        else:
            var plan: Dictionary = battle.movement_preview(battle.active_id(),hovered_route)
            preview_text.text = "移动至 %s\n消耗：%d AP / 当前%d\n%s\n%s" % [str(cell),plan["ap"],battle.active()["ap"],"可执行" if plan["valid"] else "AP不足或路径不合法",_risk_description(plan)]
            preview_panel.show()
    elif chosen == "燕行步":
        var allowed: bool = battle.can_pay(battle.active_id(),"燕行步") and battle.board.leap_allowed(battle.active()["pos"],cell,battle.units,battle.active_id())
        preview_text.text = "燕行步\n2 AP / 4内力\n%s" % ("合法落点：免借机攻击" if allowed else "落点不可用或穿越了实墙")
        preview_panel.show()
    elif uid >= 0 and battle.units[uid]["side"] != battle.active()["side"]:
        if battle.valid_attack(battle.active_id(),uid,chosen):
            var plan: Dictionary = battle.attack_preview(battle.active_id(),uid,chosen)
            var lines: Array[String] = ["%s → %s" % [chosen,battle.units[uid]["name"]]]
            for target in plan["targets"]:
                lines.append("%s：命中%d%% / 命中伤害%d" % [battle.units[int(target["id"])]["name"],target["chance"],target["damage"]])
            lines.append("消耗%d AP / %d内力；余%d AP / %d内力" % [battle.skills[chosen]["ap"],battle.skills[chosen]["qi"],plan["ap_after"],plan["qi_after"]])
            lines.append("命中后："+_counter_description(plan["counter_on_hit"]))
            lines.append("落空后："+_counter_description(plan["counter_on_miss"]))
            if chosen in ["震山掌","挑枪"]:
                lines.append("命中落点：%s" % str(plan["target_on_hit"]))
            elif chosen == "截脉指":
                lines.append("命中且存活：下次行动AP−2（不叠加）")
            elif chosen == "回锋剑":
                lines.append("攻击后位置：%s" % str(plan["attacker_on_hit"]))
            if not plan["valid"]:
                lines.append("资源不足，无法执行")
            preview_text.text = "\n".join(PackedStringArray(lines))
        else:
            preview_text.text = "不在%s的合法攻击范围内。" % chosen
        preview_panel.show()
    else:
        preview_panel.hide()
    queue_redraw()

func _counter_description(counter: Dictionary) -> String:
    if counter.is_empty():
        return "无自动反击"
    return "%s反击%d%% / 命中伤害%d" % [battle.units[int(counter["source"])]["name"],counter["chance"],counter["damage"]]

func _risk_description(plan: Dictionary) -> String:
    var lines: Array[String] = []
    for risk in plan["risks"]:
        lines.append("%s借机%d%% / 命中伤害%d–%d" % [battle.units[int(risk["source"])]["name"],risk["chance"],risk["damage"],risk["max_damage"]])
    return "无借机攻击风险" if lines.is_empty() else "\n".join(PackedStringArray(lines))

func _click_cell(cell: Vector2i) -> void:
    if not _active_usable() or not battle.board.inside(cell):
        return
    var uid: int = battle.living_at(cell)
    if chosen == "移动":
        var route: Array[Vector2i] = battle.board.path(battle.active()["pos"],cell,battle.units,battle.active_id())
        if route.is_empty() or battle.board.path_ap(route) > int(battle.active()["ap"]):
            battle.push_log("格子不可达，或剩余AP不足。")
        else:
            var danger: Array[String] = battle.risky_route(battle.active_id(),route)
            if not danger.is_empty():
                pending_route = route
                pending_actor = battle.active_id()
                pending_generation = battle_generation
                confirm_move.dialog_text = _risk_description(battle.movement_preview(pending_actor,route))+"\n伤害可能让角色中途倒下。仍然移动吗？"
                confirm_move.popup_centered()
            else:
                battle.movement(battle.active_id(),route)
    elif chosen == "燕行步":
        if battle.leap(battle.active_id(),cell):
            chosen = "移动"
        else:
            battle.push_log("轻功落点不合法。")
    elif uid >= 0 and battle.units[uid]["side"] != "player":
        if battle.attack(battle.active_id(),uid,chosen):
            chosen = "移动"
        else:
            battle.push_log("攻击失败：射程、路线或资源不足。")
    hovered_route.clear()
    _refresh()
    if battle.result == "" and int(battle.active()["hp"]) <= 0:
        _end_turn()
    elif battle.result == "" and _active_usable():
        _update_hover(cell)

func _commit_pending_move() -> void:
    confirm_move.hide()
    if not _active_usable():
        _clear_pending()
        return
    if pending_generation == battle_generation and pending_actor == battle.active_id() and not pending_route.is_empty():
        battle.movement(battle.active_id(),pending_route)
    _clear_pending()
    _update_hover(hovered)
    _refresh()
    if battle.result == "" and int(battle.active()["hp"]) <= 0:
        _end_turn()

func _clear_pending() -> void:
    pending_route.clear()
    pending_actor = -1
    pending_generation = -1

func _cancel() -> void:
    chosen = "移动"
    _clear_pending()
    confirm_move.hide()
    hovered_route.clear()
    preview_panel.hide()
    _refresh()

func _end_turn() -> void:
    if not _active_usable():
        return
    chosen = "移动"
    hovered_route.clear()
    preview_panel.hide()
    battle.advance()
    _refresh()
    if battle.result == "" and battle.active()["side"] == "enemy":
        enemy_busy = true
        call_deferred("_enemy_turn",battle_generation)

func _enemy_turn(token: int) -> void:
    if token != battle_generation:
        return
    if not is_inside_tree() or battle.result != "" or battle.active()["side"] != "enemy":
        enemy_busy = false
        return
    await get_tree().create_timer(0.3).timeout
    if token != battle_generation:
        return  # Reset happened while the enemy was waiting; never mutate the new battle.
    if not is_inside_tree() or battle.result != "":
        enemy_busy = false
        return
    ai.play(battle)
    _refresh()
    if battle.result == "":
        battle.advance()
    enemy_busy = false
    _refresh()
    if battle.result == "" and battle.active()["side"] == "enemy":
        enemy_busy = true
        call_deferred("_enemy_turn",battle_generation)

func _cell_pixel(cell: Vector2i) -> Vector2:
    return ORIGIN+Vector2(float(cell.x-cell.y)*TILE_HALF.x,float(cell.x+cell.y)*TILE_HALF.y)

func _pixel_cell(pt: Vector2) -> Vector2i:
    var p: Vector2 = pt-ORIGIN
    return Vector2i(roundi((p.x/TILE_HALF.x+p.y/TILE_HALF.y)*0.5),roundi((p.y/TILE_HALF.y-p.x/TILE_HALF.x)*0.5))

func _draw() -> void:
    draw_rect(Rect2(Vector2.ZERO,size),Color("#1d3035"),true)
    if battle.board.cells.is_empty():
        return
    for y in range(battle.board.height):
        for x in range(battle.board.width):
            var cell := Vector2i(x,y)
            var tile: String = battle.board.tile(cell)
            var p: Vector2 = _cell_pixel(cell)
            var corners := PackedVector2Array([p+Vector2(0,-TILE_HALF.y),p+Vector2(TILE_HALF.x,0),p+Vector2(0,TILE_HALF.y),p+Vector2(-TILE_HALF.x,0)])
            var fill: Color = COLOR_BASE if (x+y)%2 else Color("#799077")
            if tile == "~": fill = COLOR_WATER
            elif tile == "=": fill = COLOR_WOOD
            elif tile == "m": fill = COLOR_MUD
            elif tile in ["C","#"]: fill = COLOR_WALL
            draw_colored_polygon(corners,fill)
            draw_polyline(PackedVector2Array([corners[0],corners[1],corners[2],corners[3],corners[0]]),Color("#29433f"),1.0)
            if tile == "C":
                draw_rect(Rect2(p+Vector2(-13,-26),Vector2(26,20)),Color("#514c43"),true)
            if cell in hovered_route:
                draw_colored_polygon(corners,Color("#55b4df60"))
            if cell == hovered:
                draw_colored_polygon(corners,Color("#eed78160"))
                draw_polyline(PackedVector2Array([corners[0],corners[1],corners[2],corners[3],corners[0]]),Color("#ffedab"),2.0)
    # Display live enemy ZOC as a thin red rim (not as permanent opaque paint).
    if not battle.units.is_empty() and battle.result == "":
        for uid in battle.living_enemy_of("player"):
            var enemy: Dictionary = battle.units[uid]
            for d in BattleBoard.DIRECTIONS:
                var cell: Vector2i = enemy["pos"]+d
                if battle.board.inside(cell) and battle.zoc_threatens(enemy,cell):
                    var p: Vector2 = _cell_pixel(cell)
                    draw_arc(p,7.0,0.0,TAU,18,Color("#c96e72a8") if int(enemy["rp"]) > 0 else Color("#6b666680"),1.0)
    for u in battle.units:
        if int(u["hp"]) <= 0:
            continue
        var p: Vector2 = _cell_pixel(u["pos"])
        var enemy: bool = str(u["side"]) == "enemy"
        var fill: Color = Color("#c16c5a") if enemy else Color("#69adc6")
        if int(u["id"]) == battle.active_id():
            draw_arc(p+Vector2(0,-11),19,0,TAU,32,Color("#f5d88b"),2.5)
        draw_circle(p+Vector2(0,-11),13,fill)
        draw_string(get_theme_default_font(),p+Vector2(-21,-7),str(u["name"]).substr(0,1),HORIZONTAL_ALIGNMENT_CENTER,42,13,Color.WHITE)
        var f: Vector2i = u["facing"]
        var facing_screen: Vector2 = (_cell_pixel(u["pos"]+f)-p).normalized()*16.0
        draw_line(p+Vector2(0,-11),p+Vector2(0,-11)+facing_screen,Color("#fff3e2"),2.5)
        draw_rect(Rect2(p+Vector2(-17,9),Vector2(34,4)),Color("#4c2828"),true)
        draw_rect(Rect2(p+Vector2(-17,9),Vector2(34.0*float(u["hp"])/float(u["max_hp"]),4)),Color("#7fc894"),true)
    draw_string(get_theme_default_font(),Vector2(20,122),"青崖渡 · B1 渡口截箱",HORIZONTAL_ALIGNMENT_LEFT,-1,21,Color("#e3e9dc"))
    draw_string(get_theme_default_font(),Vector2(20,149),"蓝色我方 · 红色敌方 · 箭头为朝向",HORIZONTAL_ALIGNMENT_LEFT,-1,15,Color("#bfcfc6"))
    draw_string(get_theme_default_font(),Vector2(20,173),"移动 M   普攻 Q   武学 1/2/3   轻功 E   结束 Space",HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color("#bfcfc6"))
