extends Node2D
## Selected/hovered tile outline drawn above units so the diamond stays readable.

const DIAMOND := IsoView.DIAMOND

var active := false
var color := Color(1, 0.91, 0.63, 0.95)
var subtle := false


func show_at(world: Vector2, z: int) -> void:
	position = world
	z_index = z
	active = true
	visible = true
	queue_redraw()


func hide_cursor() -> void:
	active = false
	visible = false
	queue_redraw()


func _draw() -> void:
	if not active:
		return
	var pts := PackedVector2Array()
	for v in DIAMOND:
		pts.append(v * 0.95)
	pts.append(pts[0])
	draw_polyline(pts, Color(0.16, 0.15, 0.1, 0.8), 3.0 if subtle else 6.0, true)
	draw_polyline(pts, color, 1.5 if subtle else 3.0, true)
	# Inner soft fill so the tile reads under translucent units.
	var fill := PackedVector2Array()
	for v in DIAMOND:
		fill.append(v * 0.82)
	draw_colored_polygon(fill, Color(color.r, color.g, color.b, 0.055 if subtle else 0.12))
