extends Control


func _ready() -> void:
	var bg := TextureRect.new()
	bg.texture = load("res://assets/bg/title.png")
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(UIKit.full_rect(bg))

	var shade := ColorRect.new()
	shade.color = Color(0.02, 0.02, 0.06, 0.35)
	add_child(UIKit.full_rect(shade))

	var safe := Control.new()
	safe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(safe)
	Game.apply_safe_area(safe)

	var col := UIKit.vbox(18)
	col.set_anchors_preset(Control.PRESET_FULL_RECT)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	safe.add_child(col)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 260)
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(spacer)
	var title := UIKit.label("《天平之誓》", 128, Color(1.0, 0.9, 0.62), 18)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)
	var sub := UIKit.label("一场关于信念与抉择的战术物语", 36, Color(0.92, 0.9, 0.98), 8)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(sub)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 30)
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(gap)

	var buttons := UIKit.hbox(36)
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_child(buttons)
	buttons.add_child(UIKit.button("开始游戏", Game.new_game, 360, 112))
	buttons.add_child(UIKit.button("直接开战", Game.start_battle_demo, 360, 112))
	if OS.get_name() != "Web":
		buttons.add_child(UIKit.button("退出", func(): get_tree().quit(), 240, 112))

	var foot := UIKit.label("v1.0 · 全部美术为程序生成 · 点击按钮开始", 28, Color(0.85, 0.85, 0.9), 6)
	foot.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	foot.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	foot.grow_vertical = Control.GROW_DIRECTION_BEGIN
	safe.add_child(foot)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		get_tree().quit()
