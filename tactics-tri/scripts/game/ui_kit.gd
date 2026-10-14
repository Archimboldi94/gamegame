class_name UIKit
extends RefCounted
## Small helpers for building touch-friendly UI in code.

const MIN_BUTTON_H := 104.0
const INK := Color(0.11, 0.17, 0.26, 0.98)
const GOLD := Color(0.84, 0.69, 0.36)
const IVORY := Color(0.96, 0.92, 0.81)
const MUTED := Color(0.74, 0.78, 0.76)
const ALLY := Color(0.48, 0.83, 0.86)
const FOE := Color(1.0, 0.59, 0.43)


## Nine-patch illuminated parchment rim and lapis ink ground.
static func battle_panel(accent := GOLD, padding := 14.0) -> PanelContainer:
	var p := panel()
	var sb := miniature_skin("battle_panel")
	sb.modulate_color = Color.WHITE.lerp(accent, 0.06)
	sb.content_margin_left = padding
	sb.content_margin_right = padding
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	p.add_theme_stylebox_override("panel", sb)
	return p


static func battle_button(text: String, cb: Callable, min_w := 252.0, min_h := MIN_BUTTON_H) -> Button:
	var b := button(text, cb, min_w, min_h)
	for state in ["normal", "hover", "pressed", "disabled"]:
		b.add_theme_stylebox_override(state, miniature_skin("btn_" + state))
	b.add_theme_font_size_override("font_size", 30)
	b.add_theme_color_override("font_color", IVORY)
	b.add_theme_color_override("font_disabled_color", Color(0.42, 0.48, 0.44))
	return b


static func miniature_skin(asset: String) -> StyleBoxTexture:
	var sb := StyleBoxTexture.new()
	sb.texture = load("res://assets/ui/%s.png" % asset)
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		sb.set_texture_margin(side, 24.0)
		sb.set_content_margin(side, 14.0)
	return sb


static func meter(width: float, height: float, col: Color) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(width, height)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_theme_stylebox_override("background", color_box(Color(0.04, 0.07, 0.07), 3, Color(0.40, 0.43, 0.33), 1))
	bar.add_theme_stylebox_override("fill", color_box(col, 2))
	return bar


static func button(text: String, cb: Callable, min_w := 260.0, min_h := MIN_BUTTON_H) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(min_w, min_h)
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(func():
		var tree := Engine.get_main_loop() as SceneTree
		if tree != null and tree.root.has_node("AudioManager"):
			tree.root.get_node("AudioManager").play_ui("ui_tap")
		cb.call()
	, CONNECT_DEFERRED)
	return b


static func label(text: String, size := 30, color := Color(0.96, 0.94, 0.88), outline := 0) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if outline > 0:
		l.add_theme_constant_override("outline_size", outline)
		l.add_theme_color_override("font_outline_color", Color(0.05, 0.04, 0.08))
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


static func rich(size := 30) -> RichTextLabel:
	var r := RichTextLabel.new()
	r.bbcode_enabled = true
	r.fit_content = true
	r.scroll_active = false
	r.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	r.add_theme_font_size_override("normal_font_size", size)
	r.add_theme_font_size_override("bold_font_size", size)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


static func panel() -> PanelContainer:
	var p := PanelContainer.new()
	p.mouse_filter = Control.MOUSE_FILTER_STOP
	return p


static func vbox(sep := 14) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", sep)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return v


static func hbox(sep := 14) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", sep)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return h


static func full_rect(c: Control) -> Control:
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


static func clear(c: Node) -> void:
	for ch in c.get_children():
		c.remove_child(ch)
		ch.queue_free()


static func color_box(col: Color, radius := 10, border := Color(0, 0, 0, 0), bw := 0) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = col
	sb.set_corner_radius_all(radius)
	if bw > 0:
		sb.border_color = border
		sb.set_border_width_all(bw)
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	return sb
