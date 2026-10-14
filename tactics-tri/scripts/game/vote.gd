extends Control
## 信念天平 vote scene: view leanings, persuade up to two companions, then tally.

const ScaleView := preload("res://scripts/game/scale_view.gd")
const VOTE_COLORS := {"A": Color(0.45, 0.65, 1.0), "B": Color(1.0, 0.58, 0.42), "": Color(0.7, 0.7, 0.72)}

var vote := VoteSystem.new()
var scale_view: Control
var cards := {}
var left_label: Label
var msg_label: Label
var tally_btn: Button
var popup: Control
var popup_box: VBoxContainer
var phase := "persuade"


func _ready() -> void:
	vote.setup(StoryData.VOTE["options"], StoryData.VOTE["members"], Game.leader_values)
	_build()
	_refresh()
	if Game.shot == "vote":
		var r := vote.persuade("wenzhou", "zhi", "A")
		msg_label.text = r["msg"]
		_refresh()
		_open_persuade("moqi")


func _opt(k: String) -> Dictionary:
	return vote.options[k]


func _build() -> void:
	var bg := TextureRect.new()
	bg.texture = load("res://assets/bg/night.png")
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(UIKit.full_rect(bg))
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.45)
	add_child(UIKit.full_rect(dim))
	var safe := Control.new()
	safe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(safe)
	Game.apply_safe_area(safe)

	var col := UIKit.vbox(16)
	col.set_anchors_preset(Control.PRESET_FULL_RECT)
	safe.add_child(col)

	var head := UIKit.hbox(30)
	head.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_child(head)
	head.add_child(UIKit.label("信念天平", 56, Color(1, 0.88, 0.58), 10))
	head.add_child(UIKit.label(StoryData.VOTE["question"], 34, Color(0.95, 0.95, 1.0), 6))

	var mid := UIKit.hbox(24)
	mid.alignment = BoxContainer.ALIGNMENT_CENTER
	mid.custom_minimum_size = Vector2(0, 310)
	col.add_child(mid)
	mid.add_child(_option_card("A"))
	scale_view = ScaleView.new()
	scale_view.custom_minimum_size = Vector2(560, 310)
	scale_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scale_view.label_a = "A · " + _opt("A")["name"]
	scale_view.label_b = "B · " + _opt("B")["name"]
	mid.add_child(scale_view)
	mid.add_child(_option_card("B"))

	var row := UIKit.hbox(16)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(row)
	for m in vote.members:
		row.add_child(_member_card(m))

	var bottom := UIKit.hbox(24)
	bottom.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_child(bottom)
	left_label = UIKit.label("", 32, Color(1, 0.9, 0.6), 6)
	bottom.add_child(left_label)
	msg_label = UIKit.label("点选同伴下方的「说服」，用合适的说辞改变其倾向（最多2人）。", 30, Color(0.92, 0.94, 1.0), 6)
	msg_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	msg_label.custom_minimum_size = Vector2(900, 0)
	bottom.add_child(msg_label)
	tally_btn = UIKit.button("投下石子 · 开始表决", _start_tally, 420, 104)
	bottom.add_child(tally_btn)

	popup = ColorRect.new()
	(popup as ColorRect).color = Color(0, 0, 0, 0.6)
	popup.set_anchors_preset(Control.PRESET_FULL_RECT)
	popup.mouse_filter = Control.MOUSE_FILTER_STOP
	popup.visible = false
	add_child(popup)
	var pp := UIKit.panel()
	pp.set_anchors_preset(Control.PRESET_CENTER)
	pp.grow_horizontal = Control.GROW_DIRECTION_BOTH
	pp.grow_vertical = Control.GROW_DIRECTION_BOTH
	popup.add_child(pp)
	popup_box = UIKit.vbox(10)
	pp.add_child(popup_box)


func _option_card(k: String) -> Control:
	var p := UIKit.panel()
	p.custom_minimum_size = Vector2(520, 300)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var v := UIKit.vbox(10)
	p.add_child(v)
	v.add_child(UIKit.label("选项 %s" % k, 30, VOTE_COLORS[k]))
	v.add_child(UIKit.label(_opt(k)["name"], 44, Color(1, 0.95, 0.85), 4))
	var d := UIKit.label(_opt(k)["desc"], 30)
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(d)
	var ap: Dictionary = _opt(k)["appeal"]
	var tags := []
	for virtue in VoteSystem.VIRTUES:
		if int(ap[virtue]) > 0:
			tags.append("%s%s" % [VoteSystem.VIRTUE_NAMES[virtue], "★".repeat(int(ap[virtue]))])
	v.add_child(UIKit.label("契合：" + "  ".join(tags), 28, Color(0.85, 0.85, 0.7)))
	return p


func _member_card(m: Dictionary) -> Control:
	var p := UIKit.panel()
	p.custom_minimum_size = Vector2(340, 0)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var v := UIKit.vbox(8)
	p.add_child(v)
	var party: Dictionary = StoryData.PARTY[m["id"]]
	var top := UIKit.hbox(10)
	v.add_child(top)
	var icon := TextureRect.new()
	icon.texture = load("res://assets/icons/%s.png" % party["cls"])
	icon.custom_minimum_size = Vector2(48, 48)
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	top.add_child(icon)
	top.add_child(UIKit.label("%s · %s" % [m["name"], UnitClasses.class_name_of(party["cls"])], 34, party["color"].lightened(0.3)))
	var q := UIKit.label(m["quote"], 28, Color(0.9, 0.9, 0.95))
	q.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	q.custom_minimum_size = Vector2(300, 80)
	v.add_child(q)
	v.add_child(UIKit.label(m["hint"], 28, Color(0.9, 0.82, 0.6)))
	var badge := UIKit.label("", 32)
	v.add_child(badge)
	var btn := UIKit.button("说服", _open_persuade.bind(m["id"]), 300, 100)
	v.add_child(btn)
	cards[m["id"]] = {"badge": badge, "button": btn}
	return p


func _refresh() -> void:
	var t := vote.tally()
	scale_view.stones_a = t["A"] if phase == "result" else 0
	scale_view.stones_b = t["B"] if phase == "result" else 0
	for m in vote.members:
		var c: Dictionary = cards[m["id"]]
		var v: String = m["vote"]
		var txt := "倾向：" + ("弃权" if v == "" else "%s %s" % [v, _opt(v)["name"]])
		(c["badge"] as Label).text = txt
		(c["badge"] as Label).add_theme_color_override("font_color", VOTE_COLORS[v])
		var b: Button = c["button"]
		b.disabled = phase != "persuade" or not vote.can_persuade(m["id"])
		b.text = "已交谈" if m["persuaded"] else "说服"
	left_label.text = "剩余说服：%d 次" % vote.persuasions_left
	scale_view.queue_redraw()


func _open_persuade(id: String) -> void:
	if phase != "persuade" or not vote.can_persuade(id):
		return
	var m := vote.member(id)
	UIKit.clear(popup_box)
	popup_box.add_child(UIKit.label("说服 %s    %s  %s" % [m["name"], m["quote"], m["hint"]], 36, Color(1, 0.9, 0.6), 4))
	popup_box.add_child(UIKit.label("选择你的说辞（同一人只能交谈一次）：", 30))
	for k in ["A", "B"]:
		if m["vote"] == k:
			continue
		popup_box.add_child(UIKit.label("—— 劝其支持 %s「%s」——" % [k, _opt(k)["name"]], 30, VOTE_COLORS[k]))
		for virtue in VoteSystem.VIRTUES:
			var text: String = StoryData.VOTE["arguments"][k][virtue]
			var b := UIKit.button("【%s】%s" % [VoteSystem.VIRTUE_NAMES[virtue], text], _do_persuade.bind(id, virtue, k), 1240, 96)
			b.alignment = HORIZONTAL_ALIGNMENT_LEFT
			b.add_theme_font_size_override("font_size", 30)
			popup_box.add_child(b)
	popup_box.add_child(UIKit.button("算了", func(): popup.visible = false, 240, 96))
	popup.visible = true


func _do_persuade(id: String, virtue: String, option: String) -> void:
	popup.visible = false
	var r := vote.persuade(id, virtue, option)
	msg_label.text = r["msg"]
	_refresh()


func _start_tally() -> void:
	if phase != "persuade":
		return
	phase = "tally"
	tally_btn.disabled = true
	_refresh()
	var a := 0
	var b := 0
	for m in vote.members:
		var v: String = m["vote"]
		if v == "A":
			a += 1
		elif v == "B":
			b += 1
		scale_view.stones_a = a
		scale_view.stones_b = b
		msg_label.text = "%s投下了石子……%s" % [m["name"], "弃权" if v == "" else "「%s」" % _opt(v)["name"]]
		var tw := create_tween()
		tw.tween_property(scale_view, "tilt", clampf((a - b) / 3.0, -1.0, 1.0), 0.5).set_trans(Tween.TRANS_BACK)
		await get_tree().create_timer(0.8).timeout
	var res := vote.result()
	phase = "result"
	_refresh()
	var w: String = res["winner"]
	var text := "表决结果：A %d 票，B %d 票，弃权 %d。" % [res["counts"]["A"], res["counts"]["B"], res["counts"]["abstain"]]
	if res["tie"]:
		if res["tie_rule"] == "leader":
			text += "\n平票！依天平之誓，由持秤者林砚的信念裁决——"
		else:
			text += "\n平票，且林砚的信念亦不偏不倚——依古例，取第一个选项。"
		create_tween().tween_property(scale_view, "tilt", 0.6 if w == "A" else -0.6, 0.6)
	text += "\n天平倾向了「%s」。" % _opt(w)["name"]
	msg_label.text = text
	Game.vote_result = w
	tally_btn.text = "继续"
	tally_btn.disabled = false
	tally_btn.pressed.disconnect(_start_tally)
	tally_btn.pressed.connect(Game.advance)
