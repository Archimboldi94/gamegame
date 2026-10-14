extends Control
## Dialogue scene: miniature backdrop and portraits, name box, typewriter text, tap to advance,
## optional choice (records a conviction for the protagonist).

const Silhouette := preload("res://scripts/game/silhouette.gd")
const CHARS_PER_SEC := 40.0

var data: Dictionary
var lines: Array = []
var index := -1
var typing := false
var in_choice := false
var queued_reply := ""
var left_who := ""
var right_who := ""

var sil_left: Control
var sil_right: Control
var name_panel: PanelContainer
var name_label: Label
var text_label: Label
var narration: Label
var choice_box: VBoxContainer
var hint: Label
var title_label: Label
var tween: Tween


func _ready() -> void:
	data = StoryData.DIALOGUES.get(Game.current_dialogue, StoryData.DIALOGUES["prologue"])
	lines = data["lines"]
	_build()
	_next()
	if Game.shot == "dialogue":
		for i in 4:
			_next()
		_finish_typing()


func _build() -> void:
	var bg := TextureRect.new()
	bg.texture = load(data["bg"])
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	add_child(UIKit.full_rect(bg))
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.25)
	add_child(UIKit.full_rect(dim))

	var safe := Control.new()
	safe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(safe)
	Game.apply_safe_area(safe)

	sil_left = Silhouette.new()
	sil_right = Silhouette.new()
	for s in [sil_left, sil_right]:
		s.mouse_filter = Control.MOUSE_FILTER_IGNORE
		s.custom_minimum_size = Vector2(360, 520)
		s.size = Vector2(360, 520)
		s.visible = false
		safe.add_child(s)
	sil_left.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	sil_left.offset_left = 120
	sil_left.offset_right = 480
	sil_left.offset_top = -820
	sil_left.offset_bottom = -300
	sil_right.flip = true
	sil_right.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	sil_right.offset_left = -480
	sil_right.offset_right = -120
	sil_right.offset_top = -820
	sil_right.offset_bottom = -300

	title_label = UIKit.label(data["title"], 40, Color(1, 0.9, 0.6), 8)
	title_label.position = Vector2(8, 4)
	safe.add_child(title_label)

	var skip := UIKit.button("跳过", _skip, 200, 100)
	skip.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	skip.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	safe.add_child(skip)

	var box := UIKit.panel()
	box.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	box.offset_top = -290
	box.offset_left = 40
	box.offset_right = -40
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	safe.add_child(box)
	text_label = UIKit.label("", 36)
	text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	text_label.custom_minimum_size = Vector2(0, 200)
	box.add_child(text_label)

	name_panel = PanelContainer.new()
	name_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_panel.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	name_panel.offset_left = 80
	name_panel.offset_top = -360
	name_panel.offset_bottom = -280
	safe.add_child(name_panel)
	name_label = UIKit.label("", 36, Color(1, 0.92, 0.7))
	name_panel.add_child(name_label)

	hint = UIKit.label("▼ 点击继续", 28, Color(1, 1, 1, 0.8))
	hint.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	hint.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	hint.grow_vertical = Control.GROW_DIRECTION_BEGIN
	hint.offset_right = -70
	hint.offset_bottom = -24
	safe.add_child(hint)

	choice_box = UIKit.vbox(20)
	choice_box.set_anchors_preset(Control.PRESET_CENTER)
	choice_box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	choice_box.grow_vertical = Control.GROW_DIRECTION_BOTH
	choice_box.visible = false
	safe.add_child(choice_box)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_advance()
		accept_event()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept"):
		_advance()


func _advance() -> void:
	if in_choice:
		return
	if typing:
		_finish_typing()
		return
	_next()


func _next() -> void:
	if queued_reply != "":
		var reply := queued_reply
		queued_reply = ""
		_show_line({"who": "linyan", "text": reply})
		return
	index += 1
	if index >= lines.size():
		Game.advance()
		return
	var line: Dictionary = lines[index]
	if line.has("choice"):
		_show_choice(line["choice"])
	else:
		_show_line(line)


func _show_line(line: Dictionary) -> void:
	var who: String = line.get("who", "")
	var sp := StoryData.speaker(who)
	if who == "":
		name_panel.visible = false
		text_label.add_theme_color_override("font_color", Color(0.85, 0.9, 1.0))
	else:
		name_panel.visible = true
		name_label.text = sp["name"]
		text_label.add_theme_color_override("font_color", Color(0.98, 0.96, 0.9))
		_place_speaker(who, sp)
	text_label.text = line["text"]
	text_label.visible_characters = 0
	typing = true
	hint.visible = false
	if tween:
		tween.kill()
	tween = create_tween()
	tween.tween_property(text_label, "visible_characters", text_label.text.length(), text_label.text.length() / CHARS_PER_SEC)
	tween.finished.connect(_finish_typing)


func _place_speaker(who: String, sp: Dictionary) -> void:
	var cls := ""
	if StoryData.PARTY.has(who):
		cls = StoryData.PARTY[who]["cls"]
	elif who == "tieh":
		cls = "warlord"
	var on_left := who == "linyan"
	var target: Control = sil_left if on_left else sil_right
	if on_left:
		left_who = who
	else:
		right_who = who
	target.color = sp["color"]
	target.cls = cls
	target.who = who
	target.visible = true
	sil_left.active = on_left
	sil_right.active = not on_left
	sil_left.queue_redraw()
	sil_right.queue_redraw()


func _finish_typing() -> void:
	if tween:
		tween.kill()
	text_label.visible_characters = -1
	typing = false
	hint.visible = true


func _show_choice(options: Array) -> void:
	in_choice = true
	hint.visible = false
	name_panel.visible = true
	name_label.text = "林砚"
	text_label.text = "（你的选择会影响林砚的信念，并在之后的天平表决中左右平票。）"
	text_label.visible_characters = -1
	UIKit.clear(choice_box)
	for opt in options:
		var o: Dictionary = opt
		var tag: String = VoteSystem.VIRTUE_NAMES[o["virtue"]]
		choice_box.add_child(UIKit.button("【%s】%s" % [tag, o["text"]], _choose.bind(o), 1100, 110))
	choice_box.visible = true


func _choose(o: Dictionary) -> void:
	Game.add_conviction(o["virtue"])
	choice_box.visible = false
	in_choice = false
	queued_reply = ""
	_show_line({"who": "linyan", "text": o["reply"]})


func _skip() -> void:
	if in_choice:
		return
	for i in range(index + 1, lines.size()):
		if lines[i].has("choice"):
			index = i - 1
			queued_reply = ""
			_next()
			return
	Game.advance()
