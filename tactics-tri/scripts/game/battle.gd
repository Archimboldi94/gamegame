extends Node2D
## Battle scene: renders a BattleState, handles touch/mouse input and drives player / AI turns.

const TileNode := preload("res://scripts/game/tile_node.gd")
const UnitNode := preload("res://scripts/game/unit_node.gd")

const NONE := Vector2i(-1, -1)
const COL_MOVE := Color(0.3, 0.6, 1.0, 0.42)
const COL_ATTACK := Color(1.0, 0.3, 0.25, 0.40)
const COL_HEAL := Color(0.3, 1.0, 0.5, 0.40)
const COL_AREA := Color(1.0, 0.85, 0.3, 0.55)
const COL_DANGER := Color(1.0, 0.45, 0.15, 0.30)
const ARROW_FILES := ["ne", "se", "sw", "nw"]
const TAG_COLORS := {"背后": "#ff7060", "侧面": "#ffb347", "夹击": "#d0a0ff", "守势": "#b0b0b0"}
const ZOOM_MIN := 0.45
const ZOOM_MAX := 2.2
const DRAG_THRESHOLD := 18.0

var def: Dictionary
var state: BattleState
var world: Node2D
var cam: Camera2D
var tiles := {}
var unit_nodes := {}

var ui_root: Control
var safe: Control
var timeline_box: HBoxContainer
var info_text: RichTextLabel
var menu_panel: PanelContainer
var menu_box: VBoxContainer
var preview_panel: PanelContainer
var preview_text: RichTextLabel
var hint_label: Label
var banner: Label
var arrows: Array = []
var overlay: Control
var ui_blockers: Array = []

var mode := "busy"
var sel_skill := ""
var sel_target := NONE
var move_info := {}
var target_set: Array = []
var cam_follow: Node2D

var touches := {}
var tap_start := Vector2.ZERO
var tap_valid := false
var dragging := false
var pinch_d0 := 0.0
var pinch_z0 := 1.0


func _ready() -> void:
	def = BattleDefs.get_def(Game.current_battle)
	state = BattleDefs.build_state(Game.current_battle, 7 if Game.shot != "" else randi())
	_build_world()
	_build_ui()
	_refresh_all()
	if Game.shot.begins_with("battle"):
		_setup_shot()
	else:
		_show_intro()


# ================================================================== construction

func _build_world() -> void:
	var sky := CanvasLayer.new()
	sky.layer = -1
	add_child(sky)
	var grad := Gradient.new()
	grad.set_color(0, def["sky"].lightened(0.25))
	grad.set_color(1, def["sky"].darkened(0.45))
	var gt := GradientTexture2D.new()
	gt.gradient = grad
	gt.fill_from = Vector2(0, 0)
	gt.fill_to = Vector2(0, 1)
	var bg := TextureRect.new()
	bg.texture = gt
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	sky.add_child(UIKit.full_rect(bg))

	world = Node2D.new()
	world.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(world)
	for y in state.map.height:
		for x in state.map.width:
			var p := Vector2i(x, y)
			var tn := TileNode.new()
			tn.setup(p, state.map.get_h(p), state.map.get_terrain(p))
			world.add_child(tn)
			tiles[p] = tn
	for u in state.units:
		var un := UnitNode.new()
		un.setup(u)
		un.place_at(u.pos, state.map.get_h(u.pos))
		world.add_child(un)
		unit_nodes[u.id] = un
	cam = Camera2D.new()
	world.add_child(cam)
	cam.position = TileNode.iso(Vector2i(state.map.width / 2, state.map.height / 2), 1)
	cam.make_current()


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 5
	add_child(layer)
	ui_root = UIKit.full_rect(Control.new())
	ui_root.theme = Game.theme
	layer.add_child(ui_root)
	safe = Control.new()
	safe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_root.add_child(safe)
	Game.apply_safe_area(safe)

	# Container layout: top row / hint / middle (menu at right) / bottom row (info + preview).
	var layout := UIKit.vbox(10)
	layout.set_anchors_preset(Control.PRESET_FULL_RECT)
	safe.add_child(layout)

	var top := UIKit.hbox(12)
	layout.add_child(top)
	var head := UIKit.panel()
	head.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	top.add_child(head)
	var hv := UIKit.vbox(4)
	head.add_child(hv)
	hv.add_child(UIKit.label(def["name"], 30, Color(1, 0.88, 0.6)))
	hv.add_child(UIKit.label("胜利：" + def["win_text"], 28, Color(0.75, 0.95, 0.75)))
	hv.add_child(UIKit.label("败北：" + def["lose_text"], 28, Color(1, 0.7, 0.65)))
	top.add_child(_spacer())
	var tl := UIKit.panel()
	tl.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	top.add_child(tl)
	var tlv := UIKit.hbox(8)
	tl.add_child(tlv)
	tlv.add_child(UIKit.label("行动\n顺序", 28, Color(1, 0.88, 0.6)))
	timeline_box = UIKit.hbox(8)
	tlv.add_child(timeline_box)
	top.add_child(_spacer())
	var cbtn := UIKit.button("镜头归位", _recenter, 220, 100)
	cbtn.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	top.add_child(cbtn)

	hint_label = UIKit.label("", 30, Color(1, 1, 1), 8)
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_label.custom_minimum_size = Vector2(0, 44)
	layout.add_child(hint_label)

	var mid := UIKit.hbox(12)
	mid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(mid)
	mid.add_child(_spacer())
	menu_panel = UIKit.panel()
	menu_panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	mid.add_child(menu_panel)
	menu_box = UIKit.vbox(12)
	menu_panel.add_child(menu_box)
	menu_panel.visible = false

	var bottom := UIKit.hbox(12)
	layout.add_child(bottom)
	var info := UIKit.panel()
	info.size_flags_vertical = Control.SIZE_SHRINK_END
	bottom.add_child(info)
	info_text = UIKit.rich(28)
	info_text.custom_minimum_size = Vector2(560, 0)
	info.add_child(info_text)
	bottom.add_child(_spacer())
	preview_panel = UIKit.panel()
	preview_panel.size_flags_vertical = Control.SIZE_SHRINK_END
	bottom.add_child(preview_panel)
	preview_text = UIKit.rich(30)
	preview_text.custom_minimum_size = Vector2(760, 0)
	preview_panel.add_child(preview_text)
	preview_panel.visible = false
	var right_pad := Control.new()
	right_pad.custom_minimum_size = Vector2(200, 0)
	right_pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom.add_child(right_pad)

	banner = UIKit.label("", 72, Color(1, 0.92, 0.6), 16)
	banner.set_anchors_preset(Control.PRESET_CENTER)
	banner.grow_horizontal = Control.GROW_DIRECTION_BOTH
	banner.grow_vertical = Control.GROW_DIRECTION_BOTH
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner.modulate.a = 0.0
	safe.add_child(banner)

	for i in 4:
		var tb := TextureButton.new()
		tb.texture_normal = load("res://assets/ui/arrow_%s.png" % ARROW_FILES[i])
		tb.ignore_texture_size = true
		tb.stretch_mode = TextureButton.STRETCH_SCALE
		tb.custom_minimum_size = Vector2(128, 128)
		tb.size = Vector2(128, 128)
		tb.focus_mode = Control.FOCUS_NONE
		tb.visible = false
		tb.pressed.connect(_choose_facing.bind(i), CONNECT_DEFERRED)
		ui_root.add_child(tb)
		arrows.append(tb)

	ui_blockers = [head, tl, cbtn, info, menu_panel, preview_panel]
	ui_blockers.append_array(arrows)


func _spacer() -> Control:
	var c := Control.new()
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


# ================================================================== refresh helpers

func _refresh_all() -> void:
	for id in unit_nodes:
		var n = unit_nodes[id]
		n.place_at(n.unit.pos, state.map.get_h(n.unit.pos))
		n.refresh()
	for p in tiles:
		var tn = tiles[p]
		var eff := state.map.effect_at(p)
		if tn.effect != eff:
			tn.effect = eff
			tn.queue_redraw()
	_refresh_timeline()
	var cur := state.current()
	if cur != null:
		_show_info(cur)


func _refresh_timeline() -> void:
	UIKit.clear(timeline_box)
	var ids := state.turn_preview(8)
	for i in ids.size():
		var u := state.unit_by_id(ids[i])
		if u == null:
			continue
		var chip := PanelContainer.new()
		chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var col := Color(0.18, 0.32, 0.66, 0.92) if u.team == BattleUnit.PLAYER else Color(0.62, 0.18, 0.18, 0.92)
		var cur := i == 0 and state.current_id == u.id
		chip.add_theme_stylebox_override("panel", UIKit.color_box(col, 10, Color(1, 0.85, 0.4), 4 if cur else 0))
		chip.custom_minimum_size = Vector2(118, 0)
		var v := UIKit.vbox(0)
		chip.add_child(v)
		var icon := TextureRect.new()
		icon.texture = load("res://assets/icons/%s.png" % u.cls)
		icon.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
		icon.custom_minimum_size = Vector2(48, 48)
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		v.add_child(icon)
		var l := UIKit.label(u.name, 28)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(l)
		timeline_box.add_child(chip)


func _show_info(u: BattleUnit) -> void:
	var col := "#8ab8ff" if u.team == BattleUnit.PLAYER else "#ff8a80"
	var tp := "●".repeat(u.tp) + "○".repeat(u.max_tp - u.tp)
	var t := "[b][color=%s]%s[/color][/b]  %s · %s\n" % [col, u.name, u.class_label(), u.title]
	t += "HP [color=#9f9]%d[/color]/%d    TP [color=#8cf]%s[/color]\n" % [u.hp, u.max_hp, tp]
	t += "攻%d 防%d 魔%d 抗%d 速%d\n" % [u.atk, u.def, u.mag, u.res, u.spd]
	t += "移动%d 跳跃%d 朝向%s%s\n" % [u.mov, u.jump, BattleUnit.DIR_NAMES[u.facing], "  [color=#ccc][守势][/color]" if u.guard else ""]
	t += _terrain_text(u.pos)
	info_text.text = t


func _terrain_text(p: Vector2i) -> String:
	var tinfo := Terrain.info(state.map.get_terrain(p))
	var eva := state.map.evasion(p)
	var eff := state.map.effect_at(p)
	var s := "地形：%s  高度%d  消耗%d  回避%s%d" % [tinfo["name"], state.map.get_h(p), state.map.move_cost(p), "+" if eva >= 0 else "", eva]
	if eff != "":
		s += "  [color=#ffb060]%s[/color]" % Terrain.EFFECT_NAMES[eff]
	return s


func _set_menu(items: Array) -> void:
	UIKit.clear(menu_box)
	for it in items:
		var b := UIKit.button(it[0], it[1], 300, 104)
		b.disabled = not it[2]
		menu_box.add_child(b)
	menu_panel.visible = not items.is_empty()


func _clear_hl() -> void:
	for p in tiles:
		var tn = tiles[p]
		if tn.hl.a > 0.0 or tn.hl2.a > 0.0 or tn.cursor:
			tn.hl = Color(0, 0, 0, 0)
			tn.hl2 = Color(0, 0, 0, 0)
			tn.cursor = false
			tn.queue_redraw()


func _clear_hl2() -> void:
	for p in tiles:
		var tn = tiles[p]
		if tn.hl2.a > 0.0:
			tn.hl2 = Color(0, 0, 0, 0)
			tn.queue_redraw()


func _set_hl(p: Vector2i, c: Color, second := false) -> void:
	if not tiles.has(p):
		return
	var tn = tiles[p]
	if second:
		tn.hl2 = c
	else:
		tn.hl = c
	tn.queue_redraw()


func _set_active(u: BattleUnit) -> void:
	for id in unit_nodes:
		var n = unit_nodes[id]
		n.active = n.unit == u
		n.queue_redraw()


func _hint(text: String) -> void:
	hint_label.text = text


func _banner(text: String, col := Color(1, 0.92, 0.6)) -> void:
	banner.text = text
	banner.add_theme_color_override("font_color", col)
	banner.modulate.a = 1.0
	var tw := create_tween()
	tw.tween_interval(0.7)
	tw.tween_property(banner, "modulate:a", 0.0, 0.4)


# ================================================================== turn flow

func _show_intro() -> void:
	mode = "intro"
	overlay = _overlay_panel([
		[def["name"], 56, Color(1, 0.88, 0.6)],
		["胜利条件：" + def["win_text"], 34, Color(0.75, 0.95, 0.75)],
		["败北条件：" + def["lose_text"], 34, Color(1, 0.7, 0.65)],
		["点击单位/格子进行操作 · 单指拖动平移 · 双指捏合或滚轮缩放", 28, Color(0.9, 0.9, 0.95)],
		["从背后、侧面、高处攻击伤害更高；把敌人夹在两名同伴之间会触发夹击追击。", 28, Color(0.9, 0.9, 0.95)],
	], [["开始战斗", _start_battle]])


func _start_battle() -> void:
	if overlay:
		overlay.queue_free()
		overlay = null
	_next_turn()


func _next_turn() -> void:
	var oc := state.outcome()
	if oc != "":
		_finish(oc)
		return
	var r := state.begin_next_turn()
	var u = r["unit"]
	_refresh_all()
	for e in r["events"]:
		if e["type"] == "burn":
			_popup(e["unit"], "灼烧 %d" % e["amount"], Color(1, 0.55, 0.2))
	if u == null:
		_finish(state.outcome() if state.outcome() != "" else "lose")
		return
	_set_active(u)
	await _focus(u.pos)
	if u.team == BattleUnit.ENEMY:
		await _ai_turn(u)
		_next_turn.call_deferred()
	else:
		_banner("%s 的回合" % u.name, Color(0.7, 0.85, 1.0))
		_enter_main()


func _ai_turn(u: BattleUnit) -> void:
	mode = "busy"
	_set_menu([])
	preview_panel.visible = false
	_hint("敌方行动中……")
	_show_info(u)
	await get_tree().create_timer(0.35).timeout
	var plan := EnemyAI.plan(state, u)
	if plan["move"] != u.pos:
		var path := state.move_unit(u, plan["move"])
		await _animate_path(u, path)
	if plan["skill"] != "":
		var sk := SkillDB.get_skill(plan["skill"])
		for p in Combat.affected_tiles(sk, u.pos, plan["target"]):
			_set_hl(p, COL_AREA, true)
		_banner(sk["name"], Color(1, 0.6, 0.55))
		await get_tree().create_timer(0.45).timeout
		var events := state.execute(u, plan["skill"], plan["target"])
		_clear_hl()
		await _play_events(u, events)
	state.end_turn(plan["facing"])
	_refresh_all()


func _finish(result: String) -> void:
	mode = "result"
	_set_menu([])
	preview_panel.visible = false
	for a in arrows:
		a.visible = false
	_set_active(null)
	if result == "win":
		overlay = _overlay_panel([
			["胜  利", 96, Color(1, 0.88, 0.5)],
			[def["win_text"] + " —— 达成！", 34, Color(0.85, 0.95, 0.85)],
		], [["继续", Game.advance]])
	else:
		overlay = _overlay_panel([
			["败  北", 96, Color(1, 0.5, 0.45)],
			["林砚倒下了……天平不会为倒下的人倾斜。", 34, Color(0.95, 0.85, 0.85)],
		], [["重新挑战", Game.retry_battle], ["返回标题", Game.goto_title]])


func _overlay_panel(lines: Array, buttons: Array) -> Control:
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	ui_root.add_child(dim)
	var p := UIKit.panel()
	p.set_anchors_preset(Control.PRESET_CENTER)
	p.grow_horizontal = Control.GROW_DIRECTION_BOTH
	p.grow_vertical = Control.GROW_DIRECTION_BOTH
	dim.add_child(p)
	var v := UIKit.vbox(18)
	p.add_child(v)
	for l in lines:
		var lab := UIKit.label(l[0], l[1], l[2], 6)
		lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(lab)
	var row := UIKit.hbox(30)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(row)
	for b in buttons:
		row.add_child(UIKit.button(b[0], b[1], 320, 110))
	return dim


# ================================================================== player states

func _enter_main() -> void:
	mode = "main"
	sel_skill = ""
	sel_target = NONE
	var u := state.current()
	_clear_hl()
	move_info = {}
	if not state.moved:
		move_info = state.reachable_for(u)
		for p in move_info["ends"]:
			if p != u.pos:
				_set_hl(p, COL_MOVE)
	tiles[u.pos].cursor = true
	tiles[u.pos].queue_redraw()
	_hint("点击蓝色格子移动，或在右侧选择行动" if not state.moved else "选择行动，或「待机」结束本回合")
	_set_menu([
		["攻击", _on_attack, not state.acted],
		["技能", _on_skills, not state.acted],
		["撤销移动", _on_undo, state.can_undo_move()],
		["待机", _enter_facing, true],
	])
	preview_panel.visible = false
	_show_info(u)


func _on_attack() -> void:
	if mode == "main":
		_enter_target(state.current().basic)


func _on_undo() -> void:
	if mode != "main" or not state.can_undo_move():
		return
	state.undo_move()
	_refresh_all()
	await _focus(state.current().pos)
	_enter_main()


func _on_skills() -> void:
	if mode != "main" and mode != "target":
		return
	mode = "skills"
	_clear_hl()
	var u := state.current()
	tiles[u.pos].cursor = true
	tiles[u.pos].queue_redraw()
	var items := []
	var desc := "[b]%s 的技能[/b]   当前TP %d\n" % [u.name, u.tp]
	for sid in u.skills:
		var sk := SkillDB.get_skill(sid)
		items.append(["%s  TP%d" % [sk["name"], sk["tp"]], _enter_target.bind(sid), state.skill_usable(u, sid)])
		desc += "[color=#ffd27a]%s[/color] (TP%d)：%s\n" % [sk["name"], sk["tp"], sk["desc"]]
	items.append(["返回", _enter_main, true])
	_set_menu(items)
	preview_text.text = desc.strip_edges()
	preview_panel.visible = true
	_hint("选择要使用的技能")


func _enter_target(sid: String) -> void:
	var u := state.current()
	var sk := SkillDB.get_skill(sid)
	mode = "target"
	sel_skill = sid
	sel_target = NONE
	_clear_hl()
	if sk["kind"] == "self":
		target_set = [u.pos]
		sel_target = u.pos
		_set_hl(u.pos, COL_AREA)
		preview_text.text = "[b]%s[/b]  TP%d\n%s" % [sk["name"], sk["tp"], sk["desc"]]
		_hint("确认后立即生效")
		_set_menu([["确认", _confirm, true], ["取消", _enter_main, true]])
	else:
		target_set = state.target_tiles(u, sid, u.pos)
		var col := COL_HEAL if sk["kind"] == "heal" else COL_ATTACK
		for p in target_set:
			_set_hl(p, col)
		preview_text.text = "[b]%s[/b]  TP%d\n%s" % [sk["name"], sk["tp"], sk["desc"]]
		_hint("点击范围内的目标查看预测；再次点击同一目标或按「确认」执行")
		_set_menu([["确认", _confirm, false], ["取消", _enter_main, true]])
	tiles[u.pos].cursor = true
	tiles[u.pos].queue_redraw()
	preview_panel.visible = true


func _select_target(cell: Vector2i) -> void:
	var u := state.current()
	if cell == sel_target and state.is_valid_target(u, sel_skill, cell):
		_confirm()
		return
	sel_target = cell
	var sk := SkillDB.get_skill(sel_skill)
	_clear_hl2()
	for p in Combat.affected_tiles(sk, u.pos, cell):
		_set_hl(p, COL_AREA, true)
	var entries := state.preview(u, sel_skill, cell)
	_show_preview(sk, entries)
	_set_menu([["确认", _confirm, state.is_valid_target(u, sel_skill, cell)], ["取消", _enter_main, true]])


func _show_preview(sk: Dictionary, entries: Array) -> void:
	var t := "[b]%s[/b]  TP%d\n" % [sk["name"], sk["tp"]]
	if entries.is_empty():
		t += "范围内没有可作用的目标。"
	for e in entries:
		var tu: BattleUnit = e["unit"]
		if e["heal"]:
			var amount := mini(int(e["dmg"]), tu.max_hp - tu.hp)
			t += "%s  恢复 [color=#80ff90]%d[/color]   HP %d→%d\n" % [tu.name, amount, tu.hp, tu.hp + amount]
			continue
		var after := maxi(0, tu.hp - int(e["dmg"]))
		t += "%s  伤害 [color=#ffe070]%d[/color]  命中 [color=#90d0ff]%d%%[/color]   HP %d→%d%s\n" % [
			tu.name, e["dmg"], e["hit"], tu.hp, after, "  [color=#ff7060]可击倒[/color]" if after == 0 else ""]
		var tags: Array = e["labels"]
		if not tags.is_empty():
			var parts := []
			for tag in tags:
				parts.append("[color=%s]【%s】[/color]" % [_tag_color(tag), tag])
			t += "   " + " ".join(parts) + "\n"
		if e.has("pincer"):
			t += "   夹击追击：[color=#d0a0ff]%s[/color] 伤害%d 命中%d%%\n" % [e["pincer"].name, e["pincer_dmg"], e["pincer_hit"]]
	if sk["effect"] == "fire":
		t += "[color=#ffb060]地面将燃烧：站在火上的单位回合开始时受伤[/color]"
	elif sk["effect"] == "ice":
		t += "[color=#a0e0ff]地面将结冰（浅水可通行）；被击中者行动迟缓[/color]"
	preview_text.text = t.strip_edges()
	preview_panel.visible = true


func _tag_color(tag: String) -> String:
	for k in TAG_COLORS:
		if tag.begins_with(k):
			return TAG_COLORS[k]
	if tag.begins_with("高低差"):
		return "#90ff90" if tag.contains("+") else "#ff9090"
	return "#ffffff"


func _confirm() -> void:
	if mode != "target":
		return
	var u := state.current()
	if sel_target == NONE or not state.is_valid_target(u, sel_skill, sel_target):
		return
	mode = "busy"
	_set_menu([])
	preview_panel.visible = false
	_clear_hl()
	var events := state.execute(u, sel_skill, sel_target)
	await _play_events(u, events)
	_refresh_all()
	var oc := state.outcome()
	if oc != "":
		_finish(oc)
		return
	if state.acted and state.moved:
		_enter_facing()
	else:
		_enter_main()


func _enter_facing() -> void:
	if mode != "main" and mode != "busy":
		return
	mode = "facing"
	_clear_hl()
	preview_panel.visible = false
	var u := state.current()
	tiles[u.pos].cursor = true
	tiles[u.pos].queue_redraw()
	_hint("点击箭头选择朝向以结束行动（背后受击伤害最高）")
	_set_menu([["返回", _enter_main, true]])
	for a in arrows:
		a.visible = true
	_position_arrows()


func _choose_facing(dir: int) -> void:
	if mode != "facing":
		return
	for a in arrows:
		a.visible = false
	mode = "busy"
	_set_menu([])
	_clear_hl()
	_hint("")
	state.end_turn(dir)
	_refresh_all()
	_next_turn()


func _cancel() -> void:
	match mode:
		"target", "skills", "facing":
			for a in arrows:
				a.visible = false
			_enter_main()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_cancel()


# ================================================================== animation

func _animate_path(u: BattleUnit, path: Array) -> void:
	var n = unit_nodes[u.id]
	cam_follow = n
	var tw := create_tween()
	for i in range(1, path.size()):
		var a: Vector2i = path[i - 1]
		var b: Vector2i = path[i]
		var dest := TileNode.iso(b, state.map.get_h(b))
		tw.tween_callback(func():
			n.z_index = maxi(n.cell_z(a), n.cell_z(b))
			n.sprite.flip_h = Combat.dir_toward(a, b) >= 2)
		tw.tween_property(n, "position", dest, 0.14)
	tw.tween_callback(func():
		n.place_at(u.pos, state.map.get_h(u.pos))
		n.refresh())
	await tw.finished
	cam_follow = null


func _play_events(att: BattleUnit, events: Array) -> void:
	for e in events:
		var t = e.get("unit")
		match e["type"]:
			"damage":
				await _lunge(e["by"], t.pos)
				_popup(t, str(e["amount"]), Color(1, 0.9, 0.4))
				if e["side"] == "back":
					_banner("背后攻击！", Color(1, 0.5, 0.4))
				elif e["side"] == "side":
					_banner("侧面攻击", Color(1, 0.75, 0.4))
				_flash(t)
			"miss":
				await _lunge(e["by"], t.pos)
				_popup(t, "未命中", Color(0.8, 0.8, 0.85))
			"heal":
				_popup(t, "+%d" % e["amount"], Color(0.5, 1, 0.6))
			"pincer":
				_banner("夹击！", Color(0.85, 0.65, 1.0))
				await get_tree().create_timer(0.25).timeout
				await _lunge(e["by"], t.pos)
				_popup(t, str(e["amount"]) if e["hit"] else "未命中", Color(0.85, 0.65, 1.0))
				if e["hit"]:
					_flash(t)
			"steal":
				_popup(t, "TP -%d" % e["amount"], Color(0.6, 0.85, 1.0))
				_popup(e["by"], "TP +%d" % e["amount"], Color(0.6, 0.85, 1.0))
			"delay":
				_popup(t, "迟缓", Color(0.6, 0.9, 1.0))
			"knockback":
				var n = unit_nodes[t.id]
				var tw := create_tween()
				tw.tween_property(n, "position", TileNode.iso(e["to"], state.map.get_h(e["to"])), 0.18)
				await tw.finished
				n.place_at(t.pos, state.map.get_h(t.pos))
				if int(e["amount"]) > 0:
					_popup(t, "摔伤 %d" % e["amount"], Color(1, 0.7, 0.4))
			"collide":
				_popup(t, "撞击 %d" % e["amount"], Color(1, 0.7, 0.4))
			"terrain":
				for p in tiles:
					tiles[p].effect = state.map.effect_at(p)
					tiles[p].queue_redraw()
			"buff":
				_popup(t, e["text"], Color(0.9, 0.9, 1.0))
		if t != null and unit_nodes.has(t.id):
			unit_nodes[t.id].queue_redraw()
		if e.has("by") and e["by"] != null and unit_nodes.has(e["by"].id):
			unit_nodes[e["by"].id].refresh()
		if e.get("killed", false):
			await get_tree().create_timer(0.2).timeout
			await _fade_out(t)
		await get_tree().create_timer(0.28).timeout
	_refresh_timeline()


func _lunge(by: BattleUnit, target: Vector2i) -> void:
	if by == null or not unit_nodes.has(by.id):
		return
	var n = unit_nodes[by.id]
	n.refresh()
	var base: Vector2 = n.position
	var dir: Vector2 = (TileNode.iso(target, state.map.get_h(target)) - base).normalized()
	var tw := create_tween()
	tw.tween_property(n, "position", base + dir * 28.0, 0.09)
	tw.tween_property(n, "position", base, 0.12)
	await tw.finished


func _flash(u: BattleUnit) -> void:
	var n = unit_nodes[u.id]
	var tw := create_tween()
	tw.tween_property(n, "modulate", Color(1, 0.4, 0.4), 0.08)
	tw.tween_property(n, "modulate", Color(1, 1, 1), 0.2)


func _fade_out(u: BattleUnit) -> void:
	var n = unit_nodes[u.id]
	var tw := create_tween()
	tw.tween_property(n, "modulate:a", 0.0, 0.4)
	await tw.finished
	n.visible = false
	n.modulate.a = 1.0


func _popup(u: BattleUnit, text: String, col: Color) -> void:
	if u == null or not unit_nodes.has(u.id):
		return
	var n = unit_nodes[u.id]
	var l := UIKit.label(text, 46, col, 10)
	l.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	l.z_index = 4000
	l.z_as_relative = false
	l.size = Vector2(240, 60)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.position = n.position + Vector2(-120, -200)
	world.add_child(l)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(l, "position:y", l.position.y - 56, 0.9)
	tw.tween_property(l, "modulate:a", 0.0, 0.9).set_delay(0.35)
	tw.chain().tween_callback(l.queue_free)


func _focus(cell: Vector2i) -> void:
	var dest := TileNode.iso(cell, state.map.get_h(cell)) + Vector2(0, -40)
	if dest.distance_to(cam.position) < 4.0:
		return
	var tw := create_tween()
	tw.tween_property(cam, "position", _clamp_cam(dest), 0.3).set_trans(Tween.TRANS_SINE)
	await tw.finished


func _recenter() -> void:
	var u := state.current()
	if u != null:
		_focus(u.pos)


# ================================================================== input / camera

func _process(_delta: float) -> void:
	if cam_follow != null:
		cam.position = cam.position.lerp(_clamp_cam(cam_follow.position + Vector2(0, -40)), 0.2)
	if mode == "facing":
		_position_arrows()


func _position_arrows() -> void:
	var u := state.current()
	if u == null:
		return
	var n = unit_nodes[u.id]
	var ct := get_viewport().get_canvas_transform()
	var z := cam.zoom.x
	for i in 4:
		var v: Vector2 = UnitNode.ISO_DIR[i]
		var world_pt: Vector2 = n.position + Vector2(v.x * 120.0, v.y * 120.0) + Vector2(0, -50)
		var sp: Vector2 = ct * world_pt
		var a: Control = arrows[i]
		var s := clampf(128.0 * maxf(z, 0.8), 112.0, 160.0)
		a.size = Vector2(s, s)
		a.position = sp - a.size * 0.5


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			touches[event.index] = event.position
			if touches.size() == 1:
				tap_start = event.position
				tap_valid = true
				dragging = false
			else:
				tap_valid = false
				pinch_d0 = 0.0
		else:
			if touches.has(event.index):
				var single := touches.size() == 1
				touches.erase(event.index)
				if single and tap_valid and not dragging:
					_on_tap(event.position)
			pinch_d0 = 0.0
	elif event is InputEventScreenDrag:
		if not touches.has(event.index):
			return
		touches[event.index] = event.position
		if touches.size() == 1:
			if not dragging and event.position.distance_to(tap_start) > DRAG_THRESHOLD:
				dragging = true
				tap_valid = false
			if dragging:
				_pan(event.relative)
		else:
			_pinch()
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom_to(cam.zoom.x * 1.1, event.position)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom_to(cam.zoom.x / 1.1, event.position)
	elif event is InputEventMagnifyGesture:
		_zoom_to(cam.zoom.x * event.factor, event.position)
	elif event is InputEventPanGesture:
		_pan(-event.delta * 20.0)
	elif event.is_action_pressed("ui_cancel"):
		_cancel()


func _pan(rel: Vector2) -> void:
	cam_follow = null
	cam.position = _clamp_cam(cam.position - rel / cam.zoom.x)


func _pinch() -> void:
	var keys := touches.keys()
	var p0: Vector2 = touches[keys[0]]
	var p1: Vector2 = touches[keys[1]]
	var d := p0.distance_to(p1)
	if d < 1.0:
		return
	if pinch_d0 <= 0.0:
		pinch_d0 = d
		pinch_z0 = cam.zoom.x
		return
	_zoom_to(pinch_z0 * d / pinch_d0, (p0 + p1) * 0.5)


func _zoom_to(z: float, screen_pos: Vector2) -> void:
	z = clampf(z, ZOOM_MIN, ZOOM_MAX)
	var half := get_viewport().get_visible_rect().size * 0.5
	var before := cam.position + (screen_pos - half) / cam.zoom.x
	cam.zoom = Vector2(z, z)
	cam.position = _clamp_cam(before - (screen_pos - half) / z)


func _clamp_cam(p: Vector2) -> Vector2:
	return Vector2(clampf(p.x, -900.0, 900.0), clampf(p.y, -300.0, 900.0))


func _over_ui(pos: Vector2) -> bool:
	if overlay != null:
		return true
	for c in ui_blockers:
		if c.is_visible_in_tree() and c.get_global_rect().has_point(pos):
			return true
	return false


func _pick(screen_pos: Vector2) -> Vector2i:
	var wp: Vector2 = get_viewport().get_canvas_transform().affine_inverse() * screen_pos
	var best := NONE
	var best_z := -1
	for id in unit_nodes:
		var n = unit_nodes[id]
		if not n.visible:
			continue
		if UnitNode.SPRITE_RECT.has_point(wp - n.position) and n.z_index > best_z:
			best_z = n.z_index
			best = n.unit.pos
	for p in tiles:
		var tn = tiles[p]
		if tn.z_index <= best_z:
			continue
		if tn.contains_local(wp - tn.position):
			best_z = tn.z_index
			best = p
	return best


func _on_tap(pos: Vector2) -> void:
	if _over_ui(pos):
		return
	var cell := _pick(pos)
	if cell == NONE:
		return
	var other := state.unit_at(cell)
	match mode:
		"main":
			var u := state.current()
			if not state.moved and not move_info.is_empty() and (move_info["ends"] as Array).has(cell) and cell != u.pos:
				_do_move(cell)
				return
			_inspect(cell, other)
		"target":
			if target_set.has(cell):
				_select_target(cell)
			else:
				_inspect(cell, other)
		"facing":
			var cu := state.current()
			if cell != cu.pos:
				_choose_facing(Combat.dir_toward(cu.pos, cell, cu.facing))
		_:
			_inspect(cell, other)


func _inspect(cell: Vector2i, other: BattleUnit) -> void:
	_clear_hl2()
	if other != null:
		_show_info(other)
		if other.team == BattleUnit.ENEMY and mode == "main":
			var r := state.reachable_for(other)
			for p in r["ends"]:
				_set_hl(p, COL_DANGER, true)
			_hint("橙色：%s 的移动范围" % other.name)
	else:
		info_text.text = _terrain_text(cell)


func _do_move(cell: Vector2i) -> void:
	mode = "busy"
	_set_menu([])
	_clear_hl()
	var u := state.current()
	var path := state.move_unit(u, cell)
	await _animate_path(u, path)
	_refresh_all()
	_enter_main()


# ================================================================== screenshot setup

func _setup_shot() -> void:
	var lord: BattleUnit = null
	var lancer: BattleUnit = null
	for u in state.units:
		if u.key == "linyan":
			lord = u
		elif u.key == "gelan":
			lancer = u
	var foe: BattleUnit = state.living(BattleUnit.ENEMY)[0]
	if Game.current_battle == "b1":
		foe.pos = Vector2i(4, 7)
		foe.facing = 0
		lord.pos = Vector2i(4, 8)
		lord.facing = 0
		lancer.pos = Vector2i(4, 6)
		lancer.facing = 2
		state.map.apply_effect(Vector2i(6, 2), "fire")
		state.map.apply_effect(Vector2i(7, 2), "fire")
		state.map.apply_effect(Vector2i(2, 4), "ice")
		state.map.apply_effect(Vector2i(2, 5), "ice")
	state.current_id = lord.id
	state.moved = Game.current_battle == "b1"
	state.move_origin = lord.pos
	lord.tp = 3
	_refresh_all()
	_set_active(lord)
	cam.position = _clamp_cam(TileNode.iso(lord.pos, state.map.get_h(lord.pos)) + Vector2(0, -120))
	if Game.current_battle == "b1":
		mode = "main"
		_enter_target(lord.basic)
		_select_target(foe.pos)
	else:
		_enter_main()
