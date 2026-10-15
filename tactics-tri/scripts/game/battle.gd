extends Node2D
## Battle scene: renders a BattleState, handles touch/mouse input and drives player / AI turns.
## Every state change is applied first, then animated; callers await the animation coroutines
## (_play_events, _animate_path, ...) so the turn flow only continues once the visuals finish.

const TileNode := preload("res://scripts/game/tile_node.gd")
const UnitNode := preload("res://scripts/game/unit_node.gd")
const BattleFX := preload("res://scripts/game/battle_fx.gd")
const TileCursor := preload("res://scripts/game/tile_cursor.gd")

const NONE := Vector2i(-1, -1)
const COL_MOVE := Color(0.40, 0.69, 0.76, 0.23)
const COL_ATTACK := Color(0.86, 0.40, 0.25, 0.25)
const COL_REACH := Color(0.88, 0.54, 0.35, 0.73)
const COL_HEAL := Color(0.53, 0.80, 0.51, 0.25)
const COL_AREA := Color(0.94, 0.80, 0.39, 0.30)
const COL_DANGER := Color(0.90, 0.60, 0.31, 0.22)
const COL_PLAYER := Color(0.55, 0.78, 1.0)
const COL_ENEMY := Color(1.0, 0.55, 0.5)
const TAG_COLORS := {"背后": "#ff7060", "侧面": "#ffb347", "夹击": "#d0a0ff", "守势": "#b0b0b0"}
const ZOOM_MIN := 0.45
const ZOOM_MAX := 2.2
const ZOOM_DEFAULT := 1.0
const DRAG_THRESHOLD := 24.0
const MENU_W := 340.0
const MENU_H := 100.0

const HEAVY := ["heavy_slash", "axe", "knockback"]
const SKILL_COL := {
	"slash": Color(1.0, 0.95, 0.8), "heavy_slash": Color(1.0, 0.6, 0.25), "axe": Color(1.0, 0.45, 0.3),
	"stab": Color(0.9, 0.95, 1.0), "steal": Color(0.5, 0.8, 1.0), "knockback": Color(1.0, 0.8, 0.35),
	"staff": Color(0.95, 0.9, 0.7), "thrust": Color(0.85, 0.95, 1.0), "pierce": Color(0.6, 0.85, 1.0),
	"shoot": Color(0.95, 0.85, 0.6), "aimed_shot": Color(1.0, 0.85, 0.3), "arrow_rain": Color(1.0, 0.9, 0.5),
	"bolt": Color(0.75, 0.5, 1.0), "flame": Color(1.0, 0.5, 0.15), "frost": Color(0.55, 0.9, 1.0),
	"heal": Color(0.4, 1.0, 0.55), "mass_heal": Color(0.5, 1.0, 0.7), "guard": Color(1.0, 0.85, 0.4),
	"dash": Color(0.6, 1.0, 0.75),
}

var def: Dictionary
var state: BattleState
var view: IsoView
var world: Node2D
var fx: BattleFX
var cam: Camera2D
var tile_cursor: Node2D
var hover_cursor: Node2D
var hover_panel: PanelContainer
var hover_label: Label
var tiles := {}
var unit_nodes := {}

var ui_root: Control
var safe: Control
var timeline_box: HBoxContainer
var turn_label: Label
var info_icon: TextureRect
var info_name: RichTextLabel
var info_hp: ProgressBar
var info_text: RichTextLabel
var menu_panel: PanelContainer
var menu_title: Label
var menu_box: VBoxContainer
var preview_panel: PanelContainer
var preview_text: RichTextLabel
var hint_panel: PanelContainer
var hint_label: Label
var speed_btn: Button
var banner: Label
var overlay: Control
var overlay_confirm: Callable
var ui_blockers: Array = []

var mode := "busy"
var sel_skill := ""
var sel_target := NONE
var sel_ground := false  # true: focus ground on occupied tile (toggle)
var move_info := {}
var target_set: Array = []
var focus_cell := NONE
var cam_follow: Node2D
var autoplay_turns := 0

var touches := {}
var tap_start := Vector2.ZERO
var tap_valid := false
var dragging := false
var pinch_d0 := 0.0
var pinch_z0 := 1.0
var mouse_seen := false
var mouse_button := 0
var mouse_start := Vector2.ZERO
var mouse_dragged := false
var held_keys := {}
const KEY_PAN_DELAY_MS := 180


func _ready() -> void:
	def = BattleDefs.get_def(Game.current_battle)
	state = BattleDefs.build_state(Game.current_battle, 7 if Game.shot != "" or Game.autoplay != "" else randi())
	view = IsoView.new()
	view.configure(state.map.width, state.map.height)
	_build_world()
	_build_ui()
	_refresh_all()
	AudioManager.play_bgm("bgm_battle_loop")
	AudioManager.play_ambience("amb_night_wind")
	if Game.shot.begins_with("battle"):
		_setup_shot()
	elif Game.autoplay != "":
		Engine.time_scale = 4.0
		_start_battle()
	else:
		_show_intro()


func _exit_tree() -> void:
	Engine.time_scale = 1.0
	AudioManager.stop_battle_audio()


# ================================================================== construction

func _build_world() -> void:
	var sky := CanvasLayer.new()
	sky.layer = -1
	add_child(sky)
	var bg := TextureRect.new()
	var grad := Gradient.new()
	grad.set_color(0, def["sky"].lightened(0.25))
	grad.set_color(1, def["sky"].darkened(0.45))
	var gt := GradientTexture2D.new()
	gt.gradient = grad
	gt.fill_from = Vector2(0, 0)
	gt.fill_to = Vector2(0, 1)
	bg.texture = gt
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	sky.add_child(UIKit.full_rect(bg))

	world = Node2D.new()
	world.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	add_child(world)
	for y in state.map.height:
		for x in state.map.width:
			var p := Vector2i(x, y)
			var tn := TileNode.new()
			tn.setup(p, state.map.get_h(p), state.map.get_terrain(p), view)
			world.add_child(tn)
			tiles[p] = tn
	for u in state.units:
		var un := UnitNode.new()
		un.setup(u, view)
		un.place_at(u.pos, state.map.get_h(u.pos))
		world.add_child(un)
		unit_nodes[u.id] = un
	fx = BattleFX.new()
	fx.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	world.add_child(fx)
	tile_cursor = TileCursor.new()
	tile_cursor.hide_cursor()
	world.add_child(tile_cursor)
	hover_cursor = TileCursor.new()
	hover_cursor.color = Color(0.60, 0.91, 0.89, 0.8)
	hover_cursor.subtle = true
	hover_cursor.hide_cursor()
	world.add_child(hover_cursor)
	cam = Camera2D.new()
	world.add_child(cam)
	cam.zoom = Vector2.ONE * ZOOM_DEFAULT
	cam.position = view.screen(Vector2i(state.map.width / 2, state.map.height / 2), 1)
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

	# Layout: top row (objective / turn + timeline) · hint · middle (tools left, action menu right)
	# · bottom row (unit info left, forecast right).
	var layout := UIKit.vbox(10)
	layout.set_anchors_preset(Control.PRESET_FULL_RECT)
	safe.add_child(layout)

	var top := UIKit.hbox(12)
	layout.add_child(top)
	var head := UIKit.panel()
	head.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	top.add_child(head)
	var hv := UIKit.vbox(2)
	head.add_child(hv)
	hv.add_child(UIKit.label(def["name"], 30, Color(1, 0.88, 0.6)))
	hv.add_child(UIKit.label("胜利：" + def["win_text"], 28, Color(0.75, 0.95, 0.75)))
	hv.add_child(UIKit.label("败北：" + def["lose_text"], 28, Color(1, 0.7, 0.65)))
	top.add_child(_spacer())
	var tl := UIKit.panel()
	tl.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	top.add_child(tl)
	var tlv := UIKit.vbox(4)
	tl.add_child(tlv)
	turn_label = UIKit.label("", 32, COL_PLAYER, 6)
	turn_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tlv.add_child(turn_label)
	timeline_box = UIKit.hbox(6)
	tlv.add_child(timeline_box)
	top.add_child(_spacer())

	hint_panel = PanelContainer.new()
	hint_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hint_panel.add_theme_stylebox_override("panel", UIKit.color_box(Color(0.05, 0.05, 0.1, 0.62), 14))
	hint_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	layout.add_child(hint_panel)
	hint_label = UIKit.label("", 30, Color(1, 1, 1))
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_panel.add_child(hint_label)

	var mid := UIKit.hbox(12)
	mid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(mid)
	var tools := UIKit.vbox(10)
	tools.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	mid.add_child(tools)
	var b_center := UIKit.button("镜头归位", _recenter, 170, 96)
	var b_in := UIKit.button("放大", _zoom_step.bind(1.2), 170, 96)
	var b_out := UIKit.button("缩小", _zoom_step.bind(1.0 / 1.2), 170, 96)
	speed_btn = UIKit.button("速度×1", _toggle_speed, 170, 96)
	for b in [b_center, b_in, b_out, speed_btn]:
		b.add_theme_font_size_override("font_size", 30)
		tools.add_child(b)
	mid.add_child(_spacer())
	menu_panel = UIKit.panel()
	menu_panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	mid.add_child(menu_panel)
	var mv := UIKit.vbox(10)
	menu_panel.add_child(mv)
	menu_title = UIKit.label("", 30, Color(1, 0.88, 0.6))
	menu_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mv.add_child(menu_title)
	menu_box = UIKit.vbox(10)
	mv.add_child(menu_box)
	menu_panel.visible = false

	var bottom := UIKit.hbox(12)
	layout.add_child(bottom)
	var info := UIKit.panel()
	info.size_flags_vertical = Control.SIZE_SHRINK_END
	bottom.add_child(info)
	var ih := UIKit.hbox(14)
	info.add_child(ih)
	info_icon = TextureRect.new()
	info_icon.custom_minimum_size = Vector2(96, 96)
	info_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	info_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	info_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	info_icon.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	ih.add_child(info_icon)
	var iv := UIKit.vbox(4)
	ih.add_child(iv)
	info_name = UIKit.rich(30)
	info_name.custom_minimum_size = Vector2(540, 0)
	iv.add_child(info_name)
	info_hp = ProgressBar.new()
	info_hp.show_percentage = false
	info_hp.custom_minimum_size = Vector2(540, 20)
	info_hp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info_hp.add_theme_stylebox_override("background", UIKit.color_box(Color(0, 0, 0, 0.7), 6))
	iv.add_child(info_hp)
	info_text = UIKit.rich(28)
	info_text.custom_minimum_size = Vector2(540, 0)
	iv.add_child(info_text)
	bottom.add_child(_spacer())
	preview_panel = UIKit.panel()
	preview_panel.size_flags_vertical = Control.SIZE_SHRINK_END
	bottom.add_child(preview_panel)
	preview_text = UIKit.rich(30)
	preview_text.custom_minimum_size = Vector2(760, 0)
	preview_panel.add_child(preview_text)
	preview_panel.visible = false

	banner = UIKit.label("", 68, Color(1, 0.92, 0.6), 16)
	banner.set_anchors_preset(Control.PRESET_CENTER)
	banner.grow_horizontal = Control.GROW_DIRECTION_BOTH
	banner.grow_vertical = Control.GROW_DIRECTION_BOTH
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner.modulate.a = 0.0
	safe.add_child(banner)

	ui_blockers = [head, tl, b_center, b_in, b_out, speed_btn, info, menu_panel, preview_panel]
	hover_panel = UIKit.panel()
	hover_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hover_panel.z_index = 10
	ui_root.add_child(hover_panel)
	hover_label = UIKit.label("", 21)
	hover_panel.add_child(hover_label)
	hover_panel.hide()


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
	_refresh_effects()
	_refresh_timeline()
	var cur := state.current()
	if cur != null:
		_show_info(cur)


func _refresh_effects() -> void:
	for p in tiles:
		var tn = tiles[p]
		var eff := state.map.effect_at(p)
		if tn.effect != eff:
			tn.effect = eff
			tn.queue_redraw()


func _refresh_timeline() -> void:
	UIKit.clear(timeline_box)
	var cur := state.current()
	if cur != null:
		var player := cur.team == BattleUnit.PLAYER
		turn_label.text = "第 %d 手 · %s：%s" % [state.turn_count, "我方回合" if player else "敌方回合", cur.name]
		turn_label.add_theme_color_override("font_color", COL_PLAYER if player else COL_ENEMY)
	var ids := state.turn_preview(8)
	for i in ids.size():
		var u := state.unit_by_id(ids[i])
		if u == null:
			continue
		var chip := PanelContainer.new()
		chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var col := Color(0.18, 0.32, 0.66, 0.92) if u.team == BattleUnit.PLAYER else Color(0.62, 0.18, 0.18, 0.92)
		var now := i == 0 and state.current_id == u.id
		chip.add_theme_stylebox_override("panel", UIKit.color_box(col, 10, Color(1, 0.85, 0.4), 5 if now else 0))
		chip.custom_minimum_size = Vector2(116, 0)
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
	info_icon.texture = load("res://assets/icons/%s.png" % u.cls)
	info_icon.visible = true
	var tp := "●".repeat(u.tp) + "○".repeat(u.max_tp - u.tp)
	info_name.text = "[b][color=%s]%s[/color][/b]  %s · %s" % [col, u.name, u.class_label(), u.title]
	var ratio := float(u.hp) / float(u.max_hp)
	info_hp.max_value = u.max_hp
	info_hp.value = u.hp
	info_hp.visible = true
	var bar := Color(0.35, 0.9, 0.4) if ratio > 0.5 else (Color(1.0, 0.8, 0.25) if ratio > 0.25 else Color(1.0, 0.3, 0.25))
	info_hp.add_theme_stylebox_override("fill", UIKit.color_box(bar, 6))
	var resource := "AP [color=#8cf]%d/%d[/color]  内力 %d/%d  RP %d" % [u.ap, u.max_ap, u.qi, u.max_qi, u.rp] if u.use_gdd_rules else "TP [color=#8cf]%s[/color]" % tp
	var status := ""
	if u.guard:
		status += "   [color=#ffd27a][%s][/color]" % ("护势" if u.use_gdd_rules else "守势")
	if u.use_gdd_rules and u.block:
		status += "   [color=#ffd27a][格挡][/color]"
	if u.use_gdd_rules and (u.ap_penalty > 0 or u.qi_blocked):
		status += "   [color=#ffb080][气脉受阻][/color]"
	var t := "HP [color=#9f9]%d[/color]/%d    %s%s\n" % [
		u.hp, u.max_hp, resource, status]
	t += "攻%d 防%d 魔%d 抗%d 速%d  移%d 跳%d  朝向%s\n" % [
		u.atk, u.def, u.mag, u.res, u.spd, u.mov, u.jump, BattleUnit.DIR_NAMES[u.facing]]
	t += _terrain_text(u.pos)
	info_text.text = t


func _show_tile_info(p: Vector2i) -> void:
	info_icon.visible = false
	info_hp.visible = false
	info_name.text = "[b]%s[/b]" % Terrain.info(state.map.get_terrain(p))["name"]
	info_text.text = _terrain_text(p)


func _terrain_text(p: Vector2i) -> String:
	var tinfo := Terrain.info(state.map.get_terrain(p))
	if not tinfo["pass"]:
		return "地形：%s  高度%d  [color=#ff9a80]无法进入[/color]%s" % [
			tinfo["name"], state.map.get_h(p), "（仅飞行单位可越过）" if tinfo.get("fly", false) else ""]
	var eva := state.map.evasion(p)
	var eff := state.map.effect_at(p)
	var s := "地形：%s  高度%d  消耗%d  回避%s%d" % [tinfo["name"], state.map.get_h(p), state.map.move_cost(p), "+" if eva >= 0 else "", eva]
	if eff != "":
		s += "  [color=#ffb060]%s[/color]" % Terrain.EFFECT_NAMES[eff]
	return s


func _clear_preview() -> void:
	preview_panel.hide()
	preview_text.text = ""


func _skill_cost(sk: Dictionary) -> String:
	return "AP%d 内力%d" % [int(sk.get("ap", 0)), int(sk.get("qi", 0))] if state.current().use_gdd_rules else "TP%d" % sk["tp"]


func _skill_heading(sk: Dictionary) -> void:
	preview_text.text = "[b]%s[/b]  %s\n%s" % [sk["name"], _skill_cost(sk), sk["desc"]]
	preview_panel.show()


## items: [[text, callable, enabled], ...]
func _set_menu(items: Array, title := "") -> void:
	UIKit.clear(menu_box)
	for it in items:
		var b := UIKit.button(it[0], it[1], MENU_W, MENU_H)
		b.disabled = not it[2]
		menu_box.add_child(b)
	menu_title.text = title
	menu_title.visible = title != ""
	menu_panel.visible = not items.is_empty()


func _clear_hl() -> void:
	for p in tiles:
		var tn = tiles[p]
		if tn.hl.a > 0.0 or tn.hl2.a > 0.0 or tn.edge.a > 0.0 or tn.cursor:
			tn.hl = Color(0, 0, 0, 0)
			tn.hl2 = Color(0, 0, 0, 0)
			tn.edge = Color(0, 0, 0, 0)
			tn.cursor = false
			tn.queue_redraw()
	if tile_cursor != null:
		tile_cursor.hide_cursor()
	_clear_occlusion()


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


func _set_edge(p: Vector2i, c: Color) -> void:
	if tiles.has(p):
		tiles[p].edge = c
		tiles[p].queue_redraw()


func _set_cursor(p: Vector2i) -> void:
	focus_cell = p
	if p == NONE or not tiles.has(p):
		if tile_cursor != null:
			tile_cursor.hide_cursor()
		_update_occlusion(NONE)
		return
	var h := state.map.get_h(p)
	tile_cursor.show_at(view.screen(p, h), view.cursor_z(p))
	_update_occlusion(p)


func _clear_occlusion() -> void:
	for id in unit_nodes:
		unit_nodes[id].set_see_through(false)


## Units whose sprites cover the focused tile (or stand on / in front of it) go translucent.
func _update_occlusion(cell: Vector2i) -> void:
	if cell == NONE:
		_clear_occlusion()
		return
	var tile_top := view.screen(cell, state.map.get_h(cell))
	var tile_z := view.tile_z(cell)
	var diamond := Rect2(tile_top + Vector2(-IsoView.TW * 0.5, -IsoView.TH * 0.5), Vector2(IsoView.TW, IsoView.TH))
	for id in unit_nodes:
		var n = unit_nodes[id]
		if not n.visible or not n.unit.alive():
			n.set_see_through(false)
			continue
		# Forecast subjects remain readable. Ground inspection still fades the
		# occupant; other sprites covering the focused diamond keep the fade.
		var subject: bool = mode == "target" and (n.unit == state.current() or n.unit.pos == sel_target)
		var covers: bool = n.unit.pos == cell and sel_ground
		if not subject and n.unit.pos != cell and n.z_index >= tile_z:
			covers = n.world_rect().intersects(diamond)
		n.set_see_through(covers and not subject)


func _set_active(u: BattleUnit) -> void:
	for id in unit_nodes:
		var n = unit_nodes[id]
		n.active = n.unit == u
		n.queue_redraw()


func _hint(text: String) -> void:
	hint_label.text = text
	hint_panel.visible = text != ""


func _banner(text: String, col := Color(1, 0.92, 0.6), hold := 0.6) -> void:
	banner.text = text
	banner.add_theme_color_override("font_color", col)
	banner.modulate.a = 1.0
	banner.scale = Vector2.ONE
	var tw := create_tween()
	tw.tween_interval(hold)
	tw.tween_property(banner, "modulate:a", 0.0, 0.3)


func _wait(t: float) -> void:
	await get_tree().create_timer(t).timeout


func _toggle_speed() -> void:
	Engine.time_scale = 2.0 if Engine.time_scale < 1.5 else 1.0
	speed_btn.text = "速度×%d" % int(Engine.time_scale)


# ================================================================== turn flow

func _show_intro() -> void:
	mode = "intro"
	overlay = _overlay_panel([
		[def["name"], 56, Color(1, 0.88, 0.6)],
		["胜利条件：" + def["win_text"], 34, Color(0.75, 0.95, 0.75)],
		["败北条件：" + def["lose_text"], 34, Color(1, 0.7, 0.65)],
		["点击蓝色格子移动 · 红框为攻击可及范围 · 右侧菜单选择行动", 28, Color(0.9, 0.9, 0.95)],
		["单指拖动平移 · 双指捏合缩放 · 左右转90°看清被挡住的格子", 28, Color(0.9, 0.9, 0.95)],
		["从背后、侧面、高处攻击伤害更高；行动后自动面向攻击目标。", 28, Color(0.9, 0.9, 0.95)],
		["深水无法涉足，请走浅滩或木桥；夹住敌人可触发夹击追击。", 28, Color(0.9, 0.9, 0.95)],
	], [["开始战斗", func():
		AudioManager.play_ui("ui_confirm")
		_start_battle()
	]])


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
	if Game.autoplay != "":
		autoplay_turns += 1
		if autoplay_turns > 300:
			_finish("timeout")
			return
	var before := _hp_snapshot()
	var r := state.begin_next_turn()
	var u = r["unit"]
	for e in r["events"]:
		if e["type"] == "burn":
			await _burn(e, before)
	_refresh_all()
	if u == null:
		_finish(state.outcome() if state.outcome() != "" else "lose")
		return
	_set_active(u)
	await _focus(u.pos)
	if u.team == BattleUnit.ENEMY or Game.autoplay != "":
		if u.team == BattleUnit.ENEMY:
			AudioManager.play_sfx("turn_start_enemy")
		else:
			AudioManager.play_sfx("turn_start_ally")
		await _ai_turn(u)
		_next_turn.call_deferred()
	else:
		AudioManager.play_sfx("turn_start_ally")
		_banner("%s 的回合" % u.name, Color(0.7, 0.85, 1.0), 0.45)
		_enter_main()


func _burn(e: Dictionary, before: Dictionary) -> void:
	var t: BattleUnit = e["unit"]
	var n = unit_nodes[t.id]
	n.hold_hp(before[t.id])
	await _focus(t.pos)
	fx.burst(n.body_pos(), SKILL_COL["flame"], 14, 120.0, 0.4, 120.0, 8.0)
	n.flash(Color(1, 0.55, 0.2), 0.9, 0.3)
	n.shake(6.0, 0.24)
	n.drain_hp(t.hp)
	fx.number(n.body_pos() + Vector2(0, -80), str(e["amount"]), Color(1, 0.6, 0.25), false, "灼烧")
	await _wait(0.35)
	if e.get("killed", false):
		AudioManager.play_sfx("unit_down")
		await n.die().finished


func _ai_turn(u: BattleUnit) -> void:
	mode = "busy"
	_set_menu([])
	_clear_preview()
	_hint("敌方行动中……" if u.team == BattleUnit.ENEMY else "自动演示中……")
	_show_info(u)
	await _wait(0.25)
	var plan := EnemyAI.plan(state, u)
	if plan["move"] != u.pos:
		var path := state.move_unit(u, plan["move"])
		await _animate_path(u, path)
	if plan["skill"] != "":
		var sid: String = plan["skill"]
		var tgt: Vector2i = plan["target"]
		var sk := SkillDB.get_skill(sid)
		for p in Combat.affected_tiles(sk, u.pos, tgt, state.map):
			_set_hl(p, COL_AREA, true)
		_banner(sk["name"], COL_ENEMY if u.team == BattleUnit.ENEMY else COL_PLAYER, 0.4)
		await _wait(0.35)
		_clear_hl()
		await _perform(u, sid, tgt)
	state.end_turn()
	unit_nodes[u.id].face()
	_refresh_all()


func _finish(result: String) -> void:
	mode = "result"
	_set_menu([])
	_clear_preview()
	_hint("")
	_set_active(null)
	if result == "win":
		AudioManager.play_sfx("victory")
	elif result == "lose":
		AudioManager.play_sfx("defeat")
	if Game.autoplay != "":
		print("AUTOPLAY %s result=%s turns=%d" % [Game.current_battle, result, state.turn_count])
		Engine.time_scale = 1.0
		get_tree().quit(0 if result == "win" or result == "lose" else 1)
		return
	if Game.is_exploration_battle():
		overlay = _overlay_panel([
			["胜  利" if result == "win" else "暂  退", 96, UIKit.GOLD],
			["封箱已夺回。回到渡口后收录剑谱，记录经验100。" if result == "win" else "返回战前入口，保留原有章节进度。", 34, UIKit.IVORY],
		], [["返回青崖渡", _return_to_exploration.bind(result)]])
		return
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


func _return_to_exploration(result: String) -> void:
	if not Game.finish_exploration_battle(result):
		if is_instance_valid(overlay):
			overlay.queue_free()
		overlay = _overlay_panel([
			["存档未能写入", 64, UIKit.GOLD],
			["章节进度保持原状，请重试返回。", 34, UIKit.IVORY],
		], [["重试返回", _return_to_exploration.bind(result)]])


func _overlay_panel(lines: Array, buttons: Array) -> Control:
	overlay_confirm = buttons[0][1] if not buttons.is_empty() else Callable()
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

func _menu_title(u: BattleUnit) -> String:
	return ("%s  ·  AP %d/%d  内力 %d/%d" % [u.name, u.ap, u.max_ap, u.qi, u.max_qi]) if u.use_gdd_rules else ("%s  TP %d/%d" % [u.name, u.tp, u.max_tp])


func _enter_main() -> void:
	mode = "main"
	sel_skill = ""
	sel_target = NONE
	sel_ground = false
	var u := state.current()
	_clear_hl()
	move_info = {}
	var stand: Array = [u.pos]
	if state.can_move(u):
		move_info = state.reachable_for(u)
	elif state.gdd_mode:
		move_info = {"cost": {}, "prev": {}, "ends": []}
	if not move_info.is_empty():
		stand = move_info["ends"]
		for p in stand:
			if p != u.pos:
				_set_hl(p, COL_MOVE)
	if u.use_gdd_rules or not state.acted:
		_show_reach(u, stand)
	_set_cursor(u.pos)
	if u.use_gdd_rules:
		_hint("剩余AP内可继续移动或出招；「待机」结束本次行动")
	elif not state.moved:
		_hint("蓝色格可移动 · 红框为攻击范围 · 同格再点切换地面 / 单位")
	elif not state.acted:
		_hint("选择行动；「撤销移动」可回到原位")
	else:
		_hint("可以继续移动，或「待机」结束回合")
	var basic := SkillDB.get_skill(u.basic)
	var can_attack := state.skill_usable(u, u.basic) if u.use_gdd_rules else not state.acted
	var can_skill := false
	for sid in u.skills:
		if state.skill_usable(u, sid):
			can_skill = true
	var attack_label := "攻击 · %s" % basic["name"]
	if u.use_gdd_rules:
		attack_label += " · " + _skill_cost(basic)
	_set_menu([
		[attack_label, _on_attack, can_attack],
		["技能", _on_skills, can_skill if u.use_gdd_rules else not state.acted],
		["撤销移动", _on_undo, state.can_undo_move()],
		["待机（结束）", _end_turn, true],
	], _menu_title(u))
	_clear_preview()
	_show_info(u)


## Red outlines: every tile the basic attack can reach from some reachable standing tile;
## enemies inside that reach get a red fill.
func _show_reach(u: BattleUnit, stand: Array) -> void:
	var reach := {}
	for s in stand:
		for p in state.target_tiles(u, u.basic, s):
			reach[p] = true
	for p in reach:
		var o := state.unit_at(p)
		if o != null and o.team != u.team:
			_set_hl(p, COL_ATTACK)
			_set_edge(p, COL_REACH)
		elif not (stand as Array).has(p) and state.map.is_passable(p, true):
			_set_edge(p, COL_REACH)


func _on_attack() -> void:
	if mode == "main":
		_enter_target(state.current().basic)


func _on_undo() -> void:
	if mode != "main" or not state.can_undo_move():
		return
	mode = "busy"
	var u := state.current()
	var from := u.pos
	state.undo_move()
	var n = unit_nodes[u.id]
	var tw := create_tween()
	tw.tween_property(n, "modulate:a", 0.0, 0.1)
	tw.tween_callback(func():
		n.place_at(u.pos, state.map.get_h(u.pos))
		n.face())
	tw.tween_property(n, "modulate:a", 1.0, 0.12)
	fx.glow(n.body_pos(), Color(0.6, 0.8, 1.0), 0.8, 0.25)
	if from != u.pos:
		fx.glow(view.screen(u.pos, state.map.get_h(u.pos)) + UnitNode.BODY, Color(0.6, 0.8, 1.0), 0.8, 0.3)
	AudioManager.play_ui("ui_cancel")
	await tw.finished
	_refresh_all()
	await _focus(u.pos)
	_enter_main()


func _on_skills() -> void:
	if mode != "main" and mode != "target":
		return
	mode = "skills"
	_clear_hl()
	var u := state.current()
	_set_cursor(u.pos)
	var items := []
	var desc := "[b]%s 的技能[/b]   %s\n" % [u.name, _menu_title(u)]
	if u.use_gdd_rules and u.inner != "":
		desc += "内功：%s · %s\n" % [u.inner, SkillDB.get_inner(u.inner).get("desc", "")]
	for sid in u.skills:
		var sk := SkillDB.get_skill(sid)
		var ok := state.skill_usable(u, sid)
		var cost_txt := _skill_cost(sk)
		items.append(["%s  ·  %s" % [sk["name"], cost_txt], _enter_target.bind(sid), ok])
		var need := ("本行动已使用" if bool(sk.get("once", false)) and u.used_skills.get(sid, false) else "资源不足") if u.use_gdd_rules else "TP不足"
		desc += "[color=#ffd27a]%s[/color] (%s)%s：%s\n" % [sk["name"], cost_txt, "" if ok else "[color=#ff8080]%s[/color]" % need, sk["desc"]]
	items.append(["返回", _enter_main, true])
	_set_menu(items, _menu_title(u))
	preview_text.text = desc.strip_edges()
	preview_panel.visible = true
	_hint("选择要使用的技能")


func _enter_target(sid: String) -> void:
	var u := state.current()
	var sk := SkillDB.get_skill(sid)
	mode = "target"
	sel_skill = sid
	sel_target = NONE
	sel_ground = false
	_clear_hl()
	_show_info(u)
	_skill_heading(sk)
	if sk["kind"] == "self":
		target_set = [u.pos]
		sel_target = u.pos
		_set_hl(u.pos, COL_AREA)
		preview_text.text += "\n作用于自身 · 确认后立即生效"
		_hint("确认后立即生效")
		_set_menu([["确认", _confirm, state.is_valid_target(u, sid, u.pos)], ["取消", _enter_main, true]], sk["name"])
	else:
		target_set = state.target_tiles(u, sid, u.pos)
		var col := COL_MOVE if sk["shape"] == "leap" else (COL_HEAL if sk["kind"] == "heal" else COL_ATTACK)
		for p in target_set:
			_set_hl(p, col)
			var o := state.unit_at(p)
			if o != null and (o.team == u.team) == (sk["kind"] == "heal"):
				_set_edge(p, Color(1, 1, 0.6, 0.95))
		_hint("点击目标查看预测；同格再点确认；或按「确认」执行")
		_set_menu([["确认", _confirm, false], ["取消", _enter_main, true]], sk["name"])
	_set_cursor(u.pos)
	preview_panel.visible = true


func _select_target(cell: Vector2i) -> void:
	var u := state.current()
	# Second tap on an already-selected attack/skill target confirms; unit/ground
	# toggle is only for inspect (_inspect), not pending targeting.
	if cell == sel_target:
		_confirm()
		return
	sel_target = cell
	sel_ground = false
	var sk := SkillDB.get_skill(sel_skill)
	_clear_hl2()
	for p in Combat.affected_tiles(sk, u.pos, cell, state.map):
		_set_hl(p, COL_AREA, true)
	_set_cursor(cell)
	var entries := state.preview(u, sel_skill, cell)
	_show_preview(sk, entries)
	var tu := state.unit_at(cell)
	if tu != null:
		_show_info(tu)
	elif entries.is_empty():
		_show_tile_info(cell)
	_set_menu([["确认", _confirm, state.is_valid_target(u, sel_skill, cell)], ["取消", _enter_main, true]], sk["name"])


func _show_preview(sk: Dictionary, entries: Array) -> void:
	var t := "[b]%s[/b]  %s\n" % [sk["name"], _skill_cost(sk)]
	if entries.is_empty():
		t += sk["desc"] if sk["shape"] == "leap" else "范围内没有可作用的目标。"
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
		t += "[color=#a0e0ff]地面将结冰（浅滩更易通行）；被击中者行动迟缓[/color]"
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
	AudioManager.play_ui("ui_confirm")
	mode = "busy"
	_set_menu([])
	_clear_preview()
	_hint("")
	_clear_hl()
	var sk := SkillDB.get_skill(sel_skill)
	if int(sk["tp"]) > 0:
		_banner(sk["name"], COL_PLAYER, 0.4)
	await _perform(u, sel_skill, sel_target)
	_refresh_all()
	var oc := state.outcome()
	if oc != "":
		_finish(oc)
		return
	if not u.alive():
		_end_turn()
	elif not u.use_gdd_rules and state.acted and state.moved:
		await _wait(0.12)
		_end_turn()
	else:
		_enter_main()


## Ends the turn; the unit auto-faces its last target (or its movement direction).
func _end_turn() -> void:
	if mode != "main" and mode != "busy":
		return
	mode = "busy"
	_set_menu([])
	_clear_hl()
	_clear_preview()
	_hint("")
	var u := state.current()
	state.end_turn()
	if u != null:
		unit_nodes[u.id].face()
	_refresh_all()
	_next_turn()


func _cancel() -> void:
	AudioManager.play_ui("ui_cancel")
	match mode:
		"target", "skills":
			_enter_main()
		"main":
			if state.can_undo_move():
				_on_undo()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_cancel()
	elif what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		touches.clear()
		dragging = false
		tap_valid = false
		mouse_button = 0
		held_keys.clear()
		mouse_seen = false


# ================================================================== animation

func _hp_snapshot() -> Dictionary:
	var d := {}
	for u in state.units:
		d[u.id] = u.hp
	return d


func _tile_top(p: Vector2i) -> Vector2:
	var h := state.map.get_h(p) if state.map.in_bounds(p) else 0
	return view.screen(p, h)


func _tile_body(p: Vector2i) -> Vector2:
	return _tile_top(p) + UnitNode.BODY


func _animate_path(u: BattleUnit, path: Array) -> void:
	var n = unit_nodes[u.id]
	cam_follow = n
	var tw := create_tween()
	for i in range(1, path.size()):
		var a: Vector2i = path[i - 1]
		var b: Vector2i = path[i]
		var dest := view.screen(b, state.map.get_h(b))
		var terrain := state.map.get_terrain(b)
		var from_c := a
		var to_c := b
		tw.tween_callback(func():
			n.z_index = maxi(n.cell_z(from_c), n.cell_z(to_c))
			n.sprite.flip_h = view.faces_left(Combat.dir_toward(from_c, to_c))
			AudioManager.step_for_terrain(terrain))
		tw.tween_property(n, "position", dest, 0.13)
	tw.tween_callback(func():
		n.place_at(u.pos, state.map.get_h(u.pos))
		n.refresh())
	await tw.finished
	cam_follow = null


## Executes the action in the rules layer, then plays it back: cast -> simultaneous primary hits
## -> deaths -> follow-ups (steal / slow / knockback / pincer / terrain) in order.
func _perform(u: BattleUnit, sid: String, tgt: Vector2i) -> void:
	var before := _hp_snapshot()
	var events := state.execute(u, sid, tgt)
	var shown := before.duplicate()
	for id in unit_nodes:
		unit_nodes[id].hold_hp(before[id])
	var sk := SkillDB.get_skill(sid)
	if tgt != u.pos and sk["kind"] != "self":
		var mid := (_tile_top(u.pos) + _tile_top(tgt)) * 0.5
		if mid.distance_to(cam.position) > 360.0 / cam.zoom.x:
			await _focus_world(mid)
	unit_nodes[u.id].face()
	var primary := []
	var rest := []
	for e in events:
		if (e["type"] == "damage" or e["type"] == "miss" or e["type"] == "heal") and e.get("by") == u:
			primary.append(e)
		else:
			rest.append(e)
	await _cast(u, sk, tgt, primary)
	var dying := []
	for e in primary:
		_react(e, u, sk, shown)
		if e.get("killed", false):
			dying.append(e["unit"])
	if not primary.is_empty():
		await _wait(0.34)
	if not dying.is_empty():
		AudioManager.play_sfx("unit_down")
		for d in dying:
			unit_nodes[d.id].die()
		await _wait(0.55)
	for e in rest:
		await _secondary(e, u, shown)
	unit_nodes[u.id].face()
	_refresh_timeline()


func _cast(u: BattleUnit, sk: Dictionary, tgt: Vector2i, primary: Array) -> void:
	var sid: String = sk["id"]
	var n = unit_nodes[u.id]
	var col: Color = SKILL_COL.get(sid, Color(1, 1, 1))
	var a_body: Vector2 = n.body_pos()
	var t_body := _tile_body(tgt)
	var dir: Vector2 = (_tile_top(tgt) - n.position).normalized()
	if dir == Vector2.ZERO:
		dir = view.screen_dir(u.facing)
	AudioManager.attack_for_skill(sid)
	match sid:
		"slash":
			n.lunge(dir)
			await _wait(0.14)
			fx.slash(t_body, dir, col)
		"heavy_slash":
			fx.glow(a_body, col, 1.3, 0.28)
			n.flash(col, 0.75, 0.28)
			await _wait(0.16)
			n.lunge(dir, 46.0)
			await _wait(0.14)
			fx.slash(t_body, dir, col, true)
			_shake_cam(10.0)
		"axe":
			n.flash(col, 0.5, 0.2)
			n.lunge(dir, 26.0)
			await _wait(0.14)
			fx.chop(t_body, dir, col)
			_shake_cam(12.0)
		"stab":
			n.lunge(dir, 24.0)
			await _wait(0.12)
			fx.jab(t_body + Vector2(0, -8), dir, col)
			await _wait(0.08)
			fx.jab(t_body + Vector2(0, 10), dir, col)
		"steal":
			fx.glow(a_body, col, 1.0, 0.2)
			n.flash(col, 0.6, 0.2)
			await _wait(0.1)
			n.lunge(dir, 40.0)
			await _wait(0.12)
			fx.jab(t_body, dir, col)
			fx.burst(t_body + Vector2(0, -30), Color(1.0, 0.9, 0.4), 10, 150.0, 0.35, 80.0, 5.0)
		"knockback":
			fx.glow(a_body, col, 1.2, 0.25)
			n.flash(col, 0.7, 0.25)
			await _wait(0.12)
			n.lunge(dir, 50.0)
			await _wait(0.14)
			fx.impact(t_body, col, true)
			fx.streak(t_body - dir * 30.0, dir, 110.0, col)
			_shake_cam(12.0)
		"staff":
			n.lunge(dir, 26.0)
			await _wait(0.14)
			fx.impact(t_body, col)
		"thrust", "pierce":
			if sid == "pierce":
				fx.glow(a_body, col, 1.2, 0.25)
				n.flash(col, 0.6, 0.25)
				await _wait(0.12)
			n.lunge(dir, 40.0)
			await _wait(0.14)
			var reach := 2 if sid == "thrust" else 3
			var end := _tile_body(u.pos + (tgt - u.pos) * reach)
			fx.streak(a_body + dir * 24.0, (end - a_body).normalized(), a_body.distance_to(end), col)
			fx.burst(t_body, col, 8 if sid == "thrust" else 14, 200.0, 0.25, 0.0, 6.0)
			if sid == "pierce":
				fx.ring(t_body, col, 70.0, 0.25)
		"shoot", "aimed_shot":
			if sid == "aimed_shot":
				fx.glow(a_body, col, 1.3, 0.3)
				n.flash(col, 0.6, 0.3)
				fx.ring(t_body, col, 60.0, 0.3)
				await _wait(0.16)
			n.lunge(-dir, 10.0)
			await fx.projectile(a_body + Vector2(0, -10), t_body, "arrow", col)
			if sid == "aimed_shot":
				fx.impact(t_body, col)
		"arrow_rain":
			fx.glow(a_body, col, 1.3, 0.3)
			n.lunge(-dir, 10.0)
			await _wait(0.12)
			var area := Combat.affected_tiles(sk, u.pos, tgt, state.map)
			for i in area.size():
				var p: Vector2i = area[i]
				if p != tgt and state.map.in_bounds(p):
					fx.projectile(a_body + Vector2(-20 + i * 10, -30), _tile_body(p), "arrow", col)
			await fx.projectile(a_body + Vector2(0, -30), t_body, "arrow", col)
			for p in area:
				if state.map.in_bounds(p):
					fx.tile_flash(_tile_top(p), col, 0.3)
		"bolt":
			fx.glow(a_body, col, 0.9, 0.2)
			await _wait(0.08)
			await fx.projectile(a_body + dir * 20.0, t_body, "orb", col)
			fx.burst(t_body, col, 10, 160.0, 0.3, 0.0, 6.0)
		"flame":
			fx.glow(a_body, col, 1.6, 0.3)
			fx.burst(a_body, col, 10, 80.0, 0.3, 120.0, 7.0)
			n.flash(col, 0.6, 0.3)
			await _wait(0.16)
			await fx.projectile(a_body + Vector2(0, -50), t_body, "fireball", col)
			fx.ring(_tile_top(tgt), col, 150.0, 0.35)
			_shake_cam(8.0)
			for p in Combat.affected_tiles(sk, u.pos, tgt, state.map):
				if state.map.in_bounds(p):
					fx.tile_flash(_tile_top(p), col, 0.35)
					fx.burst(_tile_top(p) + Vector2(0, -20), col, 10, 110.0, 0.4, 140.0, 8.0)
		"frost":
			fx.glow(a_body, col, 1.6, 0.3)
			n.flash(col, 0.6, 0.3)
			await _wait(0.18)
			fx.ring(_tile_top(tgt), col, 150.0, 0.35)
			for p in Combat.affected_tiles(sk, u.pos, tgt, state.map):
				if state.map.in_bounds(p):
					fx.tile_flash(_tile_top(p), Color(0.8, 0.95, 1.0), 0.35)
					fx.burst(_tile_top(p) + Vector2(0, -110), col, 10, 60.0, 0.35, -160.0, 7.0)
			await _wait(0.12)
		"heal", "mass_heal":
			fx.glow(a_body, col, 1.4, 0.3)
			n.flash(col, 0.5, 0.3)
			await _wait(0.14)
			if sid == "mass_heal":
				fx.ring(_tile_top(tgt), col, 150.0, 0.4)
				for p in Combat.affected_tiles(sk, u.pos, tgt, state.map):
					if state.map.in_bounds(p):
						fx.tile_flash(_tile_top(p), col, 0.35)
			for e in primary:
				fx.pillar(_tile_top(e["unit"].pos), col)
			await _wait(0.16)
		"guard":
			n.flash(col, 0.6, 0.3)
			await fx.shield(a_body, col).finished
		"dash":
			fx.wind(a_body, col)
			n.lunge(view.screen_dir(u.facing), 18.0)
			await _wait(0.3)
		_:
			n.lunge(dir)
			await _wait(0.14)
			fx.slash(t_body, dir, col)


## Brief screen shake on heavy impacts; uses the camera offset so panning is unaffected.
func _shake_cam(amount := 10.0, dur := 0.22) -> void:
	var tw := create_tween()
	for i in 5:
		var k := 1.0 - i / 5.0
		tw.tween_property(cam, "offset", Vector2(randf_range(-1.0, 1.0), randf_range(-0.6, 0.6)) * amount * k, dur / 6.0)
	tw.tween_property(cam, "offset", Vector2.ZERO, dur / 6.0)


## Impact reaction for one primary event (not awaited: all targets react together).
func _react(e: Dictionary, att: BattleUnit, sk: Dictionary, shown: Dictionary) -> void:
	var t: BattleUnit = e["unit"]
	var n = unit_nodes[t.id]
	var push: Vector2 = n.position - unit_nodes[att.id].position
	if push.length() < 1.0:
		push = Vector2(0, 1)
	var col: Color = SKILL_COL.get(sk["id"], Color(1, 1, 1))
	var above: Vector2 = n.body_pos() + Vector2(0, -78)
	match e["type"]:
		"damage":
			var side: String = e.get("side", "front")
			n.hit(push, side == "back" or HEAVY.has(sk["id"]))
			fx.burst(n.body_pos(), col, 8, 170.0, 0.25, 0.0, 5.0)
			shown[t.id] = int(shown[t.id]) - int(e["amount"])
			n.drain_hp(shown[t.id])
			var tag := "背后" if side == "back" else ("侧面" if side == "side" else "")
			var ncol := Color(1, 0.55, 0.35) if side == "back" else Color(1, 0.92, 0.45)
			fx.number(above, str(e["amount"]), ncol, side != "front", tag)
			if t.guard:
				AudioManager.play_sfx("hit_block")
			elif side == "back" or HEAVY.has(sk["id"]):
				AudioManager.play_sfx("crit")
			else:
				AudioManager.play_sfx("hit_flesh")
			if side == "back" or e.get("killed", false):
				_shake_cam(8.0)
		"miss":
			n.dodge(push)
			fx.number(above, "未命中", Color(0.82, 0.84, 0.9))
		"heal":
			n.flash(Color(0.6, 1, 0.7), 0.7, 0.3)
			fx.burst(n.body_pos(), Color(0.5, 1.0, 0.65), 10, 90.0, 0.45, 140.0, 6.0)
			shown[t.id] = int(shown[t.id]) + int(e["amount"])
			n.drain_hp(shown[t.id])
			fx.number(above, "+%d" % e["amount"], Color(0.5, 1, 0.6))
			AudioManager.play_sfx("heal")


func _secondary(e: Dictionary, att: BattleUnit, shown: Dictionary) -> void:
	var t = e.get("unit")
	var n = unit_nodes[t.id] if t != null else null
	match e["type"]:
		"leap", "retreat":
			var tw := create_tween()
			tw.tween_property(n, "position", _tile_top(e["to"]), 0.16)
			await tw.finished
			n.place_at(e["to"], state.map.get_h(e["to"]))
			n.face()
		"counter", "opportunity":
			var hit_event := e.duplicate()
			hit_event["type"] = "damage" if e["hit"] else "miss"
			_react(hit_event, e["by"], SkillDB.get_skill(e["by"].basic), shown)
			await _wait(0.25)
		"steal":
			var by: BattleUnit = e["by"]
			fx.number(n.body_pos() + Vector2(0, -78), "技力 -%d" % e["amount"], Color(0.6, 0.85, 1.0))
			await fx.projectile(n.body_pos(), unit_nodes[by.id].body_pos(), "orb", Color(0.5, 0.8, 1.0))
			unit_nodes[by.id].flash(Color(0.5, 0.8, 1.0), 0.6, 0.2)
			fx.number(unit_nodes[by.id].body_pos() + Vector2(0, -78), "技力 +%d" % e["amount"], Color(0.6, 0.85, 1.0))
			n.queue_redraw()
			unit_nodes[by.id].queue_redraw()
			await _wait(0.15)
		"delay":
			n.flash(Color(0.6, 0.9, 1.0), 0.8, 0.35)
			fx.burst(n.body_pos(), Color(0.6, 0.9, 1.0), 8, 70.0, 0.3, -120.0, 6.0)
			fx.number(n.body_pos() + Vector2(0, -78), "迟缓", Color(0.6, 0.9, 1.0))
			await _wait(0.25)
		"knockback":
			var tw := create_tween()
			tw.tween_property(n, "position", _tile_top(e["to"]), 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			await tw.finished
			n.place_at(t.pos, state.map.get_h(t.pos))
			fx.burst(_tile_top(t.pos), Color(0.8, 0.7, 0.55), 8, 120.0, 0.3, 0.0, 6.0)
			if int(e["amount"]) > 0:
				n.hit(Vector2(0, 1))
				shown[t.id] = int(shown[t.id]) - int(e["amount"])
				n.drain_hp(shown[t.id])
				fx.number(n.body_pos() + Vector2(0, -78), str(e["amount"]), Color(1, 0.7, 0.4), false, "摔伤")
			await _wait(0.22)
		"collide":
			n.hit(n.position - unit_nodes[att.id].position, true)
			fx.ring(n.position, Color(1, 0.8, 0.5), 60.0, 0.25)
			fx.impact(n.body_pos(), Color(1, 0.8, 0.5))
			_shake_cam(10.0)
			shown[t.id] = int(shown[t.id]) - int(e["amount"])
			n.drain_hp(shown[t.id])
			fx.number(n.body_pos() + Vector2(0, -78), str(e["amount"]), Color(1, 0.7, 0.4), false, "撞击")
			await _wait(0.3)
		"pincer":
			var by: BattleUnit = e["by"]
			var bn = unit_nodes[by.id]
			_banner("夹击！", Color(0.85, 0.65, 1.0), 0.35)
			bn.face()
			var col := Color(0.85, 0.65, 1.0)
			var dir: Vector2 = (n.position - bn.position).normalized()
			fx.glow(bn.body_pos(), col, 1.0, 0.2)
			bn.lunge(dir)
			await _wait(0.14)
			fx.slash(n.body_pos(), dir, col, false)
			if e["hit"]:
				n.hit(dir)
				shown[t.id] = int(shown[t.id]) - int(e["amount"])
				n.drain_hp(shown[t.id])
				fx.number(n.body_pos() + Vector2(0, -78), str(e["amount"]), col, true, "夹击")
			else:
				n.dodge(dir)
				fx.number(n.body_pos() + Vector2(0, -78), "未命中", Color(0.82, 0.84, 0.9))
			await _wait(0.32)
		"terrain":
			_refresh_effects()
		"buff":
			fx.number(n.body_pos() + Vector2(0, -78), e["text"], Color(0.95, 0.92, 0.7))
			n.queue_redraw()
			await _wait(0.2)
	if e.get("killed", false) and t != null:
		AudioManager.play_sfx("unit_down")
		await n.die().finished


func _focus(cell: Vector2i) -> void:
	await _focus_world(view.screen(cell, state.map.get_h(cell)) + Vector2(0, -40))


func _focus_world(dest: Vector2) -> void:
	dest = _clamp_cam(dest)
	if dest.distance_to(cam.position) < 4.0:
		return
	var tw := create_tween()
	tw.tween_property(cam, "position", dest, 0.25).set_trans(Tween.TRANS_SINE)
	await tw.finished


func _recenter() -> void:
	var u := state.current()
	if u != null:
		_focus(u.pos)


func _zoom_step(f: float) -> void:
	_zoom_to(cam.zoom.x * f, get_viewport().get_visible_rect().size * 0.5)


# ================================================================== input / camera

func _process(delta: float) -> void:
	if cam_follow != null:
		cam.position = cam.position.lerp(_clamp_cam(cam_follow.position + Vector2(0, -40)), 0.2)
	if overlay == null and not held_keys.is_empty():
		var pan := Vector2.ZERO
		for key in held_keys:
			# A/S taps are actions; holding them joins WASD panning.
			if key in [KEY_A, KEY_S] and Time.get_ticks_msec() - int(held_keys[key]) < KEY_PAN_DELAY_MS:
				continue
			match key:
				KEY_A, KEY_LEFT: pan.x -= 1.0
				KEY_D, KEY_RIGHT: pan.x += 1.0
				KEY_W, KEY_UP: pan.y -= 1.0
				KEY_S, KEY_DOWN: pan.y += 1.0
		if pan != Vector2.ZERO:
			# A/S used with another pan key belong to that gesture, even if
			# released quickly; a diagonal pan must not open an action menu.
			for key in [KEY_A, KEY_S]:
				if held_keys.has(key):
					held_keys[key] = mini(int(held_keys[key]), Time.get_ticks_msec() - KEY_PAN_DELAY_MS)
			_pan(-pan.normalized() * 640.0 * delta / Engine.time_scale)
	_update_hover()


## Global releases finish gestures even when the pointer ends over the HUD.
## Presses go through unhandled input so GUI buttons keep their own clicks.
func _input(event: InputEvent) -> void:
	if event is InputEventKey:
		if _desktop_key(event):
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and event.device != -1:
		mouse_seen = true
		if mouse_button != 0:
			if event.position.distance_to(mouse_start) > DRAG_THRESHOLD:
				mouse_dragged = true
			if mouse_dragged:
				_pan(event.relative)
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.device != -1 and not event.pressed:
		if event.button_index == mouse_button:
			var released := mouse_button
			mouse_button = 0
			if not mouse_dragged:
				if released == MOUSE_BUTTON_LEFT:
					_on_tap(event.position)
				elif released == MOUSE_BUTTON_RIGHT:
					_cancel()
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.device != -1 and event.pressed:
		# Right cancel and middle/right drag also work over the side menu.
		if event.button_index in [MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE] and overlay == null and mouse_button == 0:
			mouse_seen = true
			mouse_button = event.button_index
			mouse_start = event.position
			mouse_dragged = false
			get_viewport().set_input_as_handled()


func _desktop_key(event: InputEventKey) -> bool:
	var key := event.physical_keycode if event.physical_keycode != 0 else event.keycode
	if event.ctrl_pressed or event.alt_pressed or event.meta_pressed:
		if not event.pressed:
			held_keys.erase(key)
		return false
	var bindings := [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER, KEY_ESCAPE, KEY_A, KEY_S, KEY_Z, KEY_BACKSPACE, KEY_Q, KEY_E, KEY_R, KEY_PLUS, KEY_EQUAL, KEY_KP_ADD, KEY_MINUS, KEY_KP_SUBTRACT, KEY_W, KEY_D, KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT]
	if not bindings.has(key):
		return false
	if event.echo:
		return true
	if not event.pressed:
		var started: int = held_keys.get(key, -1)
		held_keys.erase(key)
		if started >= 0 and key in [KEY_A, KEY_S] and Time.get_ticks_msec() - started < KEY_PAN_DELAY_MS and overlay == null:
			if key == KEY_A and mode == "main" and (state.current().use_gdd_rules or not state.acted):
				_on_attack()
			elif key == KEY_S and mode in ["main", "target"] and (state.current().use_gdd_rules or not state.acted):
				_on_skills()
		return true
	held_keys[key] = Time.get_ticks_msec()
	if overlay != null:
		if key in [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER] and overlay_confirm.is_valid():
			overlay_confirm.call()
		return true
	match key:
		KEY_ESCAPE:
			_cancel()
		KEY_SPACE, KEY_ENTER, KEY_KP_ENTER:
			if mode == "target":
				_confirm()
			elif mode == "main":
				_end_turn()
		KEY_Z, KEY_BACKSPACE:
			if mode in ["main", "target", "skills"] and state.can_undo_move():
				if mode != "main":
					_enter_main()
				_on_undo()
		KEY_Q, KEY_E:
			if mode != "busy":
				_rotate_cam(-1 if key == KEY_Q else 1)
		KEY_R:
			if mode != "busy":
				_reset_camera()
		KEY_PLUS, KEY_EQUAL, KEY_KP_ADD:
			_zoom_step(1.1)
		KEY_MINUS, KEY_KP_SUBTRACT:
			_zoom_step(1.0 / 1.1)
	return true


func _reset_camera() -> void:
	cam_follow = null
	if view.yaw != 0:
		_rotate_cam(-view.yaw)
	cam.zoom = Vector2.ONE * ZOOM_DEFAULT
	_recenter()


func _update_hover() -> void:
	if hover_cursor == null or hover_panel == null:
		return
	var pos := get_viewport().get_mouse_position()
	if not mouse_seen or mouse_button != 0 or not touches.is_empty() or mode == "busy" or _over_ui(pos):
		hover_cursor.hide_cursor()
		hover_panel.hide()
		return
	var cell := _pick(pos)
	if cell == NONE:
		hover_cursor.hide_cursor()
		hover_panel.hide()
		return
	hover_cursor.show_at(view.screen(cell, state.map.get_h(cell)), view.cursor_z(cell) + 1)
	var unit := state.unit_at(cell)
	var ground := "%s · 高度%d · 回避%+d" % [Terrain.info(state.map.get_terrain(cell))["name"], state.map.get_h(cell), state.map.evasion(cell)]
	hover_label.text = "%s · %s · %s\n生命 %d/%d · 技力%d/%d\n%s" % [unit.name, unit.class_label(), "我方" if unit.team == BattleUnit.PLAYER else "敌方", unit.hp, unit.max_hp, unit.tp, unit.max_tp, ground] if unit != null else ground
	hover_panel.reset_size()
	var extent := get_viewport().get_visible_rect().size
	hover_panel.position = (pos + Vector2(22, 22)).clamp(Vector2(24, 24), (extent - hover_panel.size - Vector2(24, 24)).max(Vector2(24, 24)))
	hover_panel.show()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.device == -1:  # Native mouse below owns its emulated touch.
			return
		mouse_seen = false
		if event.pressed:
			if event.index == 0:
				touches.clear()
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
		if event.device == -1:
			return
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
	elif event is InputEventMouseButton and event.device != -1 and event.pressed:
		if _over_ui(event.position):
			return
		mouse_seen = true
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom_to(cam.zoom.x * 1.1, event.position)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom_to(cam.zoom.x / 1.1, event.position)
		elif event.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_MIDDLE, MOUSE_BUTTON_RIGHT] and mouse_button == 0:
			mouse_button = event.button_index
			mouse_start = event.position
			mouse_dragged = false
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
	var bounds := Rect2(view.screen(Vector2i.ZERO, 0), Vector2.ZERO)
	for corner in [Vector2i(state.map.width - 1, 0), Vector2i(0, state.map.height - 1), Vector2i(state.map.width - 1, state.map.height - 1)]:
		bounds = bounds.expand(view.screen(corner, 0))
	bounds = bounds.grow(240.0)
	return Vector2(clampf(p.x, bounds.position.x, bounds.end.x), clampf(p.y, bounds.position.y - 160.0, bounds.end.y))


func _over_ui(pos: Vector2) -> bool:
	if overlay != null:
		return true
	for c in ui_blockers:
		if c.is_visible_in_tree() and c.get_global_rect().has_point(pos):
			return true
	return false


func _pick(screen_pos: Vector2) -> Vector2i:
	# Grid tile under the finger — never unit sprite bounds.
	var wp: Vector2 = get_viewport().get_canvas_transform().affine_inverse() * screen_pos
	return view.pick(wp, state.map)


func _rotate_cam(steps: int) -> void:
	var focus := focus_cell if focus_cell != NONE else (state.current().pos if state.current() != null else Vector2i(state.map.width / 2, state.map.height / 2))
	view.rotate_by(steps)
	for p in tiles:
		tiles[p].relayout()
	for id in unit_nodes:
		var n = unit_nodes[id]
		n.place_at(n.unit.pos, state.map.get_h(n.unit.pos))
		n.face()
	_set_cursor(focus)
	cam.position = _clamp_cam(view.screen(focus, state.map.get_h(focus)) + Vector2(0, -40))
	# Re-apply highlights after relayout (tiles keep hl colors; just redraw).
	for p in tiles:
		tiles[p].queue_redraw()


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
			if state.can_move(u) and not move_info.is_empty() and (move_info["ends"] as Array).has(cell) and cell != u.pos:
				_do_move(cell)
				return
			if other != null and other.team != u.team and (u.use_gdd_rules or not state.acted) and not sel_ground:
				var basic_targets := state.target_tiles(u, u.basic, u.pos)
				if basic_targets.has(cell) and cell != focus_cell:
					_enter_target(u.basic)
					_select_target(cell)
					return
			_inspect(cell, other)
		"target":
			if target_set.has(cell):
				_select_target(cell)
			else:
				# Inspecting another cell must not leave an old, confirmable forecast
				# paired with the newly inspected unit or tile.
				sel_target = NONE
				var skill := SkillDB.get_skill(sel_skill)
				_skill_heading(skill)
				_set_menu([["确认", _confirm, false], ["取消", _enter_main, true]], skill["name"])
				_inspect(cell, other)
		_:
			_inspect(cell, other)


func _inspect(cell: Vector2i, other: BattleUnit) -> void:
	_clear_hl2()
	if cell == focus_cell and other != null:
		sel_ground = not sel_ground
	else:
		sel_ground = false
	_set_cursor(cell)
	if other != null and not sel_ground:
		AudioManager.play_sfx("unit_select")
		_show_info(other)
		if other.team == BattleUnit.ENEMY and mode == "main":
			var r := state.reachable_for(other)
			for p in r["ends"]:
				_set_hl(p, COL_DANGER, true)
			_hint("橙色：%s 的移动范围（再点同格查看地面）" % other.name)
	else:
		_show_tile_info(cell)
		if other != null:
			_hint("地面：%s（再点同格回到单位）" % Terrain.info(state.map.get_terrain(cell))["name"])


func _do_move(cell: Vector2i) -> void:
	mode = "busy"
	_set_menu([])
	_clear_hl()
	_hint("")
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
	state.turn_count = 1
	state.moved = Game.current_battle == "b1"  # classic tutorial lock; wuxia_b1 stays false
	state.move_origin = lord.pos
	lord.tp = 3
	_refresh_all()
	_set_active(lord)
	# Show the complete diorama between the top chips and bottom HUD in captures.
	cam.position = view.screen(Vector2i(4, 4), 0) + Vector2(30, 40)
	cam.zoom = Vector2.ONE * ZOOM_DEFAULT  # 1:1 so unit art is shown at native resolution
	if Game.shot == "battlemain":
		state.moved = false
		_enter_main()
		return
	if Game.current_battle == "b1":
		mode = "main"
		_enter_target(lord.basic)
		_select_target(foe.pos)
		if Game.shot == "battlefx":
			state.always_hit = true
			_confirm()
	else:
		_enter_main()
