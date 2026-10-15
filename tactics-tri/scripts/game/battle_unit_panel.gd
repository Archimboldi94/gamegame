class_name BattleUnitPanel
extends PanelContainer
## Mirrored portrait / vitals cards shared by selection and combat forecasts.

var portrait: TextureRect
var heading: Label
var unit_name: Label
var role: Label
var hp_text: Label
var tp_text: Label
var hp_bar: ProgressBar
var tp_bar: ProgressBar
var details: Label
var terrain_text: Label


func build(caption: String, mirrored := false) -> void:
	custom_minimum_size = Vector2(540, 216)
	var chrome := UIKit.battle_panel()
	var style := chrome.get_theme_stylebox("panel").duplicate()
	chrome.free()
	add_theme_stylebox_override("panel", style)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var row := UIKit.hbox(12)
	add_child(row)
	var frame := UIKit.battle_panel(UIKit.GOLD, 0)
	frame.custom_minimum_size = Vector2(144, 0)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	portrait = TextureRect.new()
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(portrait)
	var stats := UIKit.vbox(3)
	stats.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if mirrored:
		row.add_child(stats)
		row.add_child(frame)
	else:
		row.add_child(frame)
		row.add_child(stats)
	heading = UIKit.label(caption, 17, UIKit.GOLD.lightened(0.18))
	stats.add_child(heading)
	unit_name = UIKit.label("选择单位", 29, UIKit.IVORY)
	stats.add_child(unit_name)
	role = UIKit.label("", 19, UIKit.MUTED)
	stats.add_child(role)
	var vitals := UIKit.hbox(10)
	stats.add_child(vitals)
	var life := UIKit.vbox(4)
	life.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vitals.add_child(life)
	hp_text = UIKit.label("", 21, UIKit.IVORY)
	life.add_child(hp_text)
	hp_bar = UIKit.meter(190, 10, Color(0.59, 0.73, 0.42))
	life.add_child(hp_bar)
	var power := UIKit.vbox(4)
	vitals.add_child(power)
	tp_text = UIKit.label("", 20, UIKit.ALLY)
	power.add_child(tp_text)
	tp_bar = UIKit.meter(88, 10, Color(0.41, 0.65, 0.72))
	power.add_child(tp_bar)
	details = UIKit.label("", 18, UIKit.MUTED)
	stats.add_child(details)
	terrain_text = UIKit.label("", 18, UIKit.MUTED)
	terrain_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stats.add_child(terrain_text)
	show_empty()


func show_unit(u: BattleUnit, map: BattleMap, after := -1) -> void:
	var team := "我方" if u.team == BattleUnit.PLAYER else "敌方"
	var key := u.key if u.key != "" else "%s_%s" % [u.cls, "player" if u.team == BattleUnit.PLAYER else "enemy"]
	var portrait_path := "res://assets/battle_portraits/%s.png" % key
	portrait.texture = load(portrait_path) if ResourceLoader.exists(portrait_path) else load("res://assets/battle_portraits/empty.png")
	portrait.modulate = Color.WHITE
	unit_name.text = u.name
	unit_name.add_theme_color_override("font_color", UIKit.ALLY if u.team == BattleUnit.PLAYER else UIKit.FOE)
	role.text = "%s · %s" % [team, u.class_label()]
	hp_text.text = "生命 %d/%d" % [u.hp, u.max_hp]
	if after >= 0:
		hp_text.text += " →%d" % after
	hp_bar.max_value = u.max_hp
	hp_bar.value = u.hp
	hp_bar.show()
	if u.use_gdd_rules:
		tp_text.text = "AP %d/%d · 内力 %d/%d · RP %d" % [u.ap, u.max_ap, u.qi, u.max_qi, u.rp]
		tp_bar.max_value = u.max_ap
		tp_bar.value = u.ap
	else:
		tp_text.text = "技力 %d/%d" % [u.tp, u.max_tp]
		tp_bar.max_value = u.max_tp
		tp_bar.value = u.tp
	tp_text.show()
	tp_bar.show()
	details.text = "攻%d  防%d  魔%d  抗%d  速%d" % [u.atk, u.def, u.mag, u.res, u.spd]
	tooltip_text = "%s\n移动%d · 跳跃%d · 朝向%s%s" % [u.title, u.mov, u.jump, BattleUnit.DIR_NAMES[u.facing], " · 守势" if u.guard else ""]
	var terrain := Terrain.info(map.get_terrain(u.pos))
	if u.use_gdd_rules:
		terrain_text.text = "%s · AP%d 内力%d · 朝%s%s" % [terrain["name"], u.ap, u.qi, BattleUnit.DIR_NAMES[u.facing], " · 护势" if u.guard else (" · 格挡" if u.block else "")]
	else:
		terrain_text.text = "%s · 高%d · 移%d 跳%d · 朝%s%s" % [terrain["name"], map.get_h(u.pos), u.mov, u.jump, BattleUnit.DIR_NAMES[u.facing], " · 守势" if u.guard else ""]
	terrain_text.tooltip_text = "地形回避 %+d · 移动消耗 %d" % [map.evasion(u.pos), map.move_cost(u.pos)]


func show_ground(p: Vector2i, map: BattleMap) -> void:
	var terrain := Terrain.info(map.get_terrain(p))
	tooltip_text = "地面 · 高度%d · 回避%+d" % [map.get_h(p), map.evasion(p)]
	var tkey: String = "water" if map.get_terrain(p) == "ford" else String(Terrain.info(map.get_terrain(p)).get("art", map.get_terrain(p)))
	var tile_path := "res://assets/tiles/top_%s_0.png" % tkey
	portrait.texture = load(tile_path) if ResourceLoader.exists(tile_path) else load("res://assets/tiles/top_grass_0.png")
	portrait.modulate = Color(0.75, 0.83, 0.67)
	unit_name.text = terrain["name"]
	unit_name.add_theme_color_override("font_color", UIKit.IVORY)
	role.text = "地面 · 再点同格查看单位"
	hp_bar.hide()
	tp_bar.hide()
	tp_text.hide()
	hp_text.text = "高度 %d  ·  回避 %+d" % [map.get_h(p), map.evasion(p)]
	details.text = "移动消耗 %d" % map.move_cost(p) if terrain["pass"] else "无法进入%s" % (" · 仅飞行单位可越过" if terrain.get("fly", false) else "")
	var effect := map.effect_at(p)
	terrain_text.text = Terrain.EFFECT_NAMES[effect] if effect != "" else "选中格始终按地面位置拾取"


func show_empty() -> void:
	portrait.texture = load("res://assets/battle_portraits/empty.png")
	portrait.modulate = Color(0.63, 0.65, 0.51)
	unit_name.text = "等待目标"
	unit_name.add_theme_color_override("font_color", UIKit.MUTED)
	role.text = "选择攻击或技能后点选目标"
	tooltip_text = ""
	hp_text.text = "生命  — / —"
	hp_bar.hide()
	tp_text.text = "技力  — / —"
	tp_text.show()
	tp_bar.hide()
	details.text = ""
	terrain_text.text = ""
