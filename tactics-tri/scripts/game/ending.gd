extends Control

var data: Dictionary
var shown := 0
var line_box: VBoxContainer
var back_btn: Button
var hint: Label


func _ready() -> void:
	data = StoryData.ENDINGS[Game.route()]
	var bg := TextureRect.new()
	bg.texture = load(data["bg"])
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(UIKit.full_rect(bg))
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	add_child(UIKit.full_rect(dim))
	var safe := Control.new()
	safe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(safe)
	Game.apply_safe_area(safe)

	var col := UIKit.vbox(26)
	col.set_anchors_preset(Control.PRESET_FULL_RECT)
	col.offset_left = 160
	col.offset_right = -160
	col.offset_top = 60
	col.offset_bottom = -40
	safe.add_child(col)
	var t := UIKit.label(data["title"], 60, Color(1, 0.88, 0.6), 10)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(t)
	line_box = UIKit.vbox(20)
	line_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(line_box)
	for text in data["lines"]:
		var l := UIKit.label(text, 34, Color(0.95, 0.94, 0.9), 6)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.modulate.a = 0.0
		line_box.add_child(l)
	var row := UIKit.hbox()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_child(row)
	hint = UIKit.label("点击画面继续", 28, Color(1, 1, 1, 0.75))
	row.add_child(hint)
	back_btn = UIKit.button("—— 终 ——  返回标题", Game.goto_title, 520, 110)
	back_btn.visible = false
	row.add_child(back_btn)
	_reveal()
	if Game.shot == "ending":
		while shown < line_box.get_child_count():
			_reveal()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_reveal()
		accept_event()


func _reveal() -> void:
	if shown >= line_box.get_child_count():
		return
	var l: Control = line_box.get_child(shown)
	shown += 1
	if Game.shot != "":
		l.modulate.a = 1.0
	else:
		create_tween().tween_property(l, "modulate:a", 1.0, 0.6)
	if shown >= line_box.get_child_count():
		hint.visible = false
		back_btn.visible = true
