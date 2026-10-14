extends Control
## Simple colored character silhouette (head + shoulders + class hint) for dialogue scenes.

var color := Color(0.5, 0.5, 0.6)
var active := true
var flip := false
var cls := ""


func _draw() -> void:
	var c := color if active else color.darkened(0.55)
	c.a = 1.0 if active else 0.75
	var w := size.x
	var h := size.y
	var cx := w * 0.5
	var edge := c.darkened(0.45)
	var body := PackedVector2Array([
		Vector2(cx - w * 0.42, h), Vector2(cx - w * 0.36, h * 0.62), Vector2(cx - w * 0.16, h * 0.52),
		Vector2(cx + w * 0.16, h * 0.52), Vector2(cx + w * 0.36, h * 0.62), Vector2(cx + w * 0.42, h),
	])
	draw_colored_polygon(body, c.darkened(0.15))
	draw_polyline(body, edge, 4.0)
	draw_circle(Vector2(cx, h * 0.36), w * 0.2, c)
	draw_arc(Vector2(cx, h * 0.36), w * 0.2, 0, TAU, 48, edge, 4.0)
	var dir := -1.0 if flip else 1.0
	match cls:
		"mage":
			draw_colored_polygon(PackedVector2Array([Vector2(cx - w * 0.26, h * 0.24), Vector2(cx + w * 0.26, h * 0.24), Vector2(cx + dir * w * 0.08, h * 0.0)]), c.darkened(0.3))
		"lancer", "warlord":
			draw_line(Vector2(cx + dir * w * 0.38, h * 0.08), Vector2(cx + dir * w * 0.38, h), c.darkened(0.35), 8.0)
		"archer":
			draw_arc(Vector2(cx + dir * w * 0.3, h * 0.66), w * 0.16, -PI / 2, PI / 2, 24, c.darkened(0.35), 6.0)
		"healer":
			draw_rect(Rect2(cx - 8, h * 0.62, 16, 56), Color(0.85, 0.3, 0.3))
			draw_rect(Rect2(cx - 26, h * 0.62 + 18, 52, 16), Color(0.85, 0.3, 0.3))
		"swordsman":
			draw_line(Vector2(cx + dir * w * 0.3, h * 0.5), Vector2(cx + dir * w * 0.46, h * 0.95), Color(0.85, 0.88, 0.95), 7.0)
		"thief":
			draw_rect(Rect2(cx - w * 0.2, h * 0.38, w * 0.4, h * 0.06), c.darkened(0.5))
	if active:
		draw_arc(Vector2(cx, h * 0.36), w * 0.24, 0, TAU, 48, Color(1, 0.9, 0.6, 0.6), 3.0)
