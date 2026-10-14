extends Control
## Animated balance scale. tilt > 0 means the A (left) pan is heavier.

var tilt := 0.0:
	set(v):
		tilt = v
		queue_redraw()
var stones_a := 0
var stones_b := 0
var label_a := "A"
var label_b := "B"


func _draw() -> void:
	var w := size.x
	var h := size.y
	var gold := Color(0.95, 0.8, 0.45)
	var dark := Color(0.45, 0.34, 0.18)
	var cx := w * 0.5
	var top := h * 0.18
	draw_rect(Rect2(cx - 8, top, 16, h * 0.68), gold)
	draw_colored_polygon(PackedVector2Array([Vector2(cx - 90, h * 0.92), Vector2(cx + 90, h * 0.92), Vector2(cx, h * 0.8)]), gold)
	draw_circle(Vector2(cx, top), 18, gold)
	var arm := w * 0.38
	var ang := clampf(tilt, -1.0, 1.0) * 0.32
	var left := Vector2(cx, top) + Vector2(-arm, 0).rotated(-ang)
	var right := Vector2(cx, top) + Vector2(arm, 0).rotated(-ang)
	draw_line(left, right, gold, 10.0)
	_pan(left, stones_a, label_a, gold, dark, Color(0.5, 0.7, 1.0))
	_pan(right, stones_b, label_b, gold, dark, Color(1.0, 0.6, 0.45))


func _pan(p: Vector2, stones: int, text: String, gold: Color, dark: Color, stone_col: Color) -> void:
	var drop := 110.0
	draw_line(p, p + Vector2(-70, drop), gold, 3.0)
	draw_line(p, p + Vector2(70, drop), gold, 3.0)
	var bowl := PackedVector2Array()
	for i in 17:
		var a := PI * i / 16.0
		bowl.append(p + Vector2(0, drop) + Vector2(cos(a) * 86, sin(a) * 34))
	draw_colored_polygon(bowl, gold)
	draw_polyline(bowl, dark, 3.0)
	for i in stones:
		var sp := p + Vector2(-48 + (i % 4) * 32, drop - 10 - (i / 4) * 22)
		draw_circle(sp, 13, stone_col)
		draw_arc(sp, 13, 0, TAU, 20, stone_col.darkened(0.5), 2.0)
	var font := get_theme_default_font()
	draw_string(font, p + Vector2(-60, drop + 80), text, HORIZONTAL_ALIGNMENT_CENTER, 120, 34, Color(1, 0.95, 0.85))
