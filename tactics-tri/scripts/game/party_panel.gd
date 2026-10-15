extends Control
## Preparation overlay shared by the inn library and the exploration pause menu.

signal closed
signal changed
signal return_to_title

var mode := "library"
var selected_character := ""
var selected_art := "回锋剑"
var library_category := "招式"
var content: VBoxContainer
var notice := ""
var learn_button: Button
var equip_buttons: Array[Button] = []


func _ready() -> void:
	UIKit.full_rect(self)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0.025, 0.05, 0.07, 0.88)
	add_child(UIKit.full_rect(dim))
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var frame := UIKit.battle_panel(UIKit.GOLD, 32)
	add_child(frame)
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	frame.offset_left = 72
	frame.offset_right = -72
	frame.offset_top = 66
	frame.offset_bottom = -66
	content = UIKit.vbox(16)
	frame.add_child(content)
	hide()


func open(page: String, character := "") -> void:
	mode = page
	selected_character = character
	if mode == "party" and selected_character == "":
		selected_character = "sword"
	notice = ""
	_render()
	show()


func close() -> void:
	hide()
	closed.emit()


func _button(text: String, callback: Callable, width := 130.0, height := 58.0) -> Button:
	var b := UIKit.battle_button(text, callback, width, height)
	b.add_theme_font_size_override("font_size", 23)
	for state in ["normal", "hover", "pressed", "disabled"]:
		var skin := b.get_theme_stylebox(state)
		skin.set_content_margin(SIDE_TOP, 6)
		skin.set_content_margin(SIDE_BOTTOM, 6)
	return b


func _text(parent: Node, value: String, size := 24, color := UIKit.IVORY) -> Label:
	var l := UIKit.label(value, size, color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(l)
	return l


func _scroll(parent: Node, ratio: float) -> VBoxContainer:
	var panel := UIKit.battle_panel(UIKit.GOLD, 20)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_stretch_ratio = ratio
	parent.add_child(panel)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)
	var col := UIKit.vbox(8)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(col)
	return col


func _render() -> void:
	UIKit.clear(content)
	learn_button = null
	equip_buttons.clear()
	var title := UIKit.hbox(16)
	content.add_child(title)
	var heading := UIKit.label("听雨客栈 · 武学谱库" if mode == "library" else "同行 · 队伍成长", 38, UIKit.GOLD)
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_child(heading)
	title.add_child(_button("武学谱库", open.bind("library"), 160))
	title.add_child(_button("队伍成长", open.bind("party", selected_character), 160))
	title.add_child(_button("关闭 [Esc]", close, 170))
	_text(content, "队伍已收录 · 共用传承，分别习得；学习免费，同一秘籍可供多人学习。" if mode == "library" else "每人独立积累经验与训练点 · 每升一级气血 +3、训练点 +1 · 单项最多4点，免费重置。", 23, UIKit.MUTED)
	var row := UIKit.hbox(20)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(row)
	var left := _scroll(row, 1.05 if mode == "library" else 0.7)
	var right := _scroll(row, 1.0)
	if mode == "library":
		_library(left, right)
	else:
		_party(left, right)
	var foot := UIKit.hbox(16)
	content.add_child(foot)
	var footer := _text(foot, notice if notice != "" else "武学心得 %d · 精进暂未开放    /    行路与整备自动保存" % Game.chapter.party.lesson, 22, UIKit.MUTED)
	footer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	foot.add_child(_button("保存并返回标题", func(): return_to_title.emit(), 240))


func _select_character(id: String) -> void:
	selected_character = id
	notice = ""
	_render()


func _select_art(sid: String) -> void:
	selected_art = sid
	notice = ""
	_render()


func _select_category(kind: String) -> void:
	library_category = kind
	_render()


func _mutate(action: Callable, message: String) -> void:
	var before := Game.chapter.to_dict()
	if not action.call():
		notice = "当前条件不满足，未作更改。"
	elif Game.save_chapter():
		notice = message
		changed.emit()
	else:
		Game.chapter = ChapterState.from_dict(before)
		notice = "存档未能写入，本次调整已撤回，请重试。"
	_render()


func _preview(sid: String) -> String:
	if PartyState.category(sid) == "内功":
		return "AP 0 / 内力 0 · 范围：自身（被动）\n定位：" + String(SkillDB.get_inner(sid).get("desc", ""))
	var sk := SkillDB.get_skill(sid)
	var area := "自身" if sk["shape"] == "self" else "%d格" % int(sk["rmax"])
	if sk["shape"] == "line":
		area += " · 八向直线"
	elif sk["shape"] == "arc3":
		area += " · 前方三格"
	elif sk["shape"] == "leap":
		area += " · 移动落点"
	return "AP %d / 内力 %d · 范围：%s\n定位：%s" % [sk.get("ap", 0), sk.get("qi", 0), area, sk["desc"]]


func _library(left: VBoxContainer, right: VBoxContainer) -> void:
	var p := Game.chapter.party
	if not p.library.has(selected_art):
		selected_art = p.library[0]
	_text(left, "队伍已收录", 30, UIKit.GOLD)
	var categories := UIKit.hbox(10)
	left.add_child(categories)
	for kind in ["招式", "内功", "轻功"]:
		categories.add_child(_button(("● " if library_category == kind else "") + kind, _select_category.bind(kind), 140, 50))
	_text(left, "选择武学预览 AP、内力、范围与定位。", 21, UIKit.MUTED)
	for sid in p.library:
		if PartyState.category(sid) != library_category:
			continue
		var compatible := selected_character == "" or PartyState.compatible(p.characters[selected_character]["weapon"], sid)
		var name_text: String = "《回锋剑谱》 · 回锋剑" if sid == "回锋剑" else sid
		var b := _button(("▸ " if selected_art == sid else "") + name_text + (" · 兵器不兼容" if not compatible else ""), _select_art.bind(sid), 0, 52)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		if not compatible or selected_art == sid:
			b.add_theme_color_override("font_color", UIKit.FOE if not compatible else UIKit.GOLD)
		left.add_child(b)
	var selectors := UIKit.hbox(10)
	right.add_child(selectors)
	for id in PartyState.IDS:
		var values := p.stats(id)
		selectors.add_child(_button(("● " if selected_character == id else "") + values["name"], _select_character.bind(id), 140))
	if selected_character == "":
		_text(right, selected_art + " · 队伍已收录", 28, UIKit.GOLD)
		_text(right, _preview(selected_art), 24)
		_text(right, "谱库属于队伍。\n先选择一名角色，再学习或调整其 3＋1＋1 槽位。", 26)
		return
	var c: Dictionary = p.characters[selected_character]
	_text(right, "%s · Lv.%d · 兵器：%s · 固有特质：%s" % [p.stats(selected_character)["name"], c["level"], PartyState.WEAPONS[c["weapon"]], PartyState.TRAITS[selected_character]], 23, UIKit.MUTED)
	var known: bool = c["learned"].has(selected_art)
	var equipped: bool = c["active"].has(selected_art) or c["inner"] == selected_art or c["lightfoot"] == selected_art
	_text(right, selected_art + "  /  " + ("已习得" if known else "未习得") + (" · 已装配" if equipped else " · 未装配"), 28, UIKit.GOLD)
	_text(right, _preview(selected_art), 22)
	var allowed := PartyState.compatible(c["weapon"], selected_art)
	_text(right, "兵器要求：" + PartyState.WEAPONS.get(PartyState.REQUIREMENTS.get(selected_art, ""), "通用") + (" · 兵器不兼容，可学习，不可装配" if not allowed else " · 可装配"), 22, UIKit.FOE if not allowed else UIKit.ALLY)
	learn_button = _button("已习得" if known else "免费学习", _mutate.bind(p.learn.bind(selected_character, selected_art), "已习得「%s」。其他同行仍可学习。" % selected_art), 130, 48)
	learn_button.disabled = known
	right.add_child(learn_button)
	_text(right, "个人装配 · 3 招式 ＋ 1 内功 ＋ 1 轻功", 25, UIKit.GOLD)
	for i in 3:
		_slot(right, "主动%d" % (i + 1), c["active"][i], "招式", i)
	_slot(right, "内功", c["inner"], "内功", 0)
	_slot(right, "轻功", c["lightfoot"], "轻功", 0)
	_text(right, "个人已学：" + "、".join(c["learned"]), 21, UIKit.MUTED)


func _slot(parent: Node, label: String, current: String, kind: String, index: int) -> void:
	var p := Game.chapter.party
	var row := UIKit.hbox(8)
	parent.add_child(row)
	_text(row, label + " · " + ("空槽" if current == "" else current), 23)
	var equip := _button("装入", _mutate.bind(p.equip.bind(selected_character, selected_art, index, kind), "装配已保存。"), 90, 46)
	equip.disabled = PartyState.category(selected_art) != kind or not p.can_equip(selected_character, selected_art) or current == selected_art
	equip_buttons.append(equip)
	row.add_child(equip)
	var remove := _button("卸下", _mutate.bind(p.equip.bind(selected_character, "", index, kind), "已卸下。"), 90, 46)
	remove.disabled = current == ""
	row.add_child(remove)


func _party(left: VBoxContainer, right: VBoxContainer) -> void:
	var p := Game.chapter.party
	_text(left, "同行三人 · 各自成长", 28, UIKit.GOLD)
	for id in PartyState.IDS:
		var c: Dictionary = p.characters[id]
		var values := p.stats(id)
		left.add_child(_button(("▸ " if selected_character == id else "") + "%s    Lv.%d" % [values["name"], c["level"]], _select_character.bind(id), 0, 62))
		_text(left, "EXP %d / %s    可用训练点 %d" % [c["exp"], str(PartyState.exp_to_next(c["level"])) if c["level"] < 10 else "已满级", p.training_points(id)], 23)
		var bar := UIKit.meter(0, 10, UIKit.GOLD)
		bar.max_value = maxi(1, PartyState.exp_to_next(c["level"]))
		bar.value = c["exp"]
		left.add_child(bar)
		_text(left, PartyState.TRAITS[id] + " · " + PartyState.TRAIT_TEXT[PartyState.TRAITS[id]], 22, UIKit.MUTED)
	_text(left, "胜利经验：出战 ×1.0，替补 ×0.6。\n落后队伍基准至少2级时再 ×1.5。\n倒地与最后一击均不影响个人分配。", 21, UIKit.MUTED)
	var id := selected_character
	var c: Dictionary = p.characters[id]
	var values := p.stats(id)
	_text(right, "%s · Lv.%d    可用训练点 %d" % [values["name"], c["level"], p.training_points(id)], 30, UIKit.GOLD)
	_text(right, "气血 %d    劲力 %d    护体 %d    眼力 %+d\n身法 %+d    速度 %d    内力 %d" % [values["max_hp"], values["strength"], values["armor"], values["accuracy"], values["evasion"], values["speed"], values["qi"]], 25)
	_text(right, "速度影响行动顺序 · 每次行动6 AP / 每轮1 RP", 21, UIKit.MUTED)
	var gains := {"强身": "气血 +4", "蓄劲": "劲力 +1", "护体": "护体 +1", "凝神": "眼力 +3%", "腾挪": "身法 +3%", "迅捷": "速度 +3", "调元": "内力上限 +2"}
	for direction in PartyState.TRAINING:
		var row := UIKit.hbox(10)
		right.add_child(row)
		var spent := int(c["training"].get(direction, 0))
		_text(row, "%s    %s    %d / 4" % [direction, gains[direction], spent], 24)
		var b := _button("＋ 分配", _mutate.bind(p.train.bind(id, direction), "训练点已分配。"), 135, 50)
		b.disabled = spent >= 4 or p.training_points(id) <= 0
		row.add_child(b)
	right.add_child(_button("免费重置训练点", _mutate.bind(p.reset_training.bind(id), "已返还全部训练点。"), 230, 58))
