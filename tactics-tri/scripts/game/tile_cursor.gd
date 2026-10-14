extends Node2D
## Selected/hovered tile outline drawn above units so the diamond stays readable.

const DIAMOND := [Vector2(0, -32), Vector2(64, 0), Vector2(0, 32), Vector2(-64, 0)]

var active := false
var color := Color(1, 1, 1, 0.95)


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
	draw_polyline(pts, color, 5.0)
	# Inner soft fill so the tile reads under translucent units.
	var fill := PackedVector2Array()
	for v in DIAMOND:
		fill.append(v * 0.82)
	draw_colored_polygon(fill, Color(color.r, color.g, color.b, 0.12))
