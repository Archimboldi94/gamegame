extends Node2D
## Visual for one BattleUnit: team ring, facing arrow, chibi sprite, HP bar, active marker.

const TileNode := preload("res://scripts/game/tile_node.gd")
const ISO_DIR := [Vector2(0.894, -0.447), Vector2(0.894, 0.447), Vector2(-0.894, 0.447), Vector2(-0.894, -0.447)]
const SPRITE_RECT := Rect2(-36, -116, 72, 120)

var unit: BattleUnit
var sprite: Sprite2D
var active := false
var t := 0.0


func setup(u: BattleUnit) -> void:
	unit = u
	sprite = Sprite2D.new()
	var team := "player" if u.team == BattleUnit.PLAYER else "enemy"
	sprite.texture = load("res://assets/units/%s_%s.png" % [u.cls, team])
	sprite.centered = false
	sprite.position = Vector2(-48, -116)
	add_child(sprite)
	refresh()


func cell_z(p: Vector2i) -> int:
	return (p.x + p.y) * 2 + 1


func place_at(p: Vector2i, h: int) -> void:
	position = TileNode.iso(p, h)
	z_index = cell_z(p)


func refresh() -> void:
	sprite.flip_h = unit.facing == 2 or unit.facing == 3
	visible = unit.alive()
	queue_redraw()


func _process(delta: float) -> void:
	if active:
		t += delta
		queue_redraw()


func _draw() -> void:
	var col := Color(0.35, 0.65, 1.0) if unit.team == BattleUnit.PLAYER else Color(1.0, 0.35, 0.3)
	var ring := PackedVector2Array()
	for i in 25:
		var a := TAU * i / 24.0
		ring.append(Vector2(cos(a) * 38.0, sin(a) * 19.0))
	draw_colored_polygon(ring, Color(0, 0, 0, 0.35))
	draw_polyline(ring, col, 4.0 if active else 3.0)
	var v: Vector2 = ISO_DIR[unit.facing]
	var perp := Vector2(-v.y, v.x)
	var tip := Vector2(v.x * 62.0, v.y * 62.0)
	var base := Vector2(v.x * 40.0, v.y * 40.0)
	draw_colored_polygon(PackedVector2Array([tip, base + perp * 13.0, base - perp * 13.0]), col.lightened(0.2))
	draw_polyline(PackedVector2Array([tip, base + perp * 13.0, base - perp * 13.0, tip]), Color(0, 0, 0, 0.6), 2.0)
	var ratio := float(unit.hp) / float(unit.max_hp)
	draw_rect(Rect2(-38, -132, 76, 12), Color(0, 0, 0, 0.75))
	var hp_col := Color(0.35, 0.9, 0.4) if ratio > 0.5 else (Color(1.0, 0.8, 0.25) if ratio > 0.25 else Color(1.0, 0.3, 0.25))
	draw_rect(Rect2(-36, -130, 72.0 * ratio, 8), hp_col)
	for i in unit.max_tp:
		var c := Color(0.55, 0.85, 1.0) if i < unit.tp else Color(0.2, 0.22, 0.3)
		draw_rect(Rect2(-36 + i * 15, -142, 12, 7), c)
	if unit.is_leader:
		_star(Vector2(48, -128), 12.0, Color(1.0, 0.82, 0.3))
	if unit.is_lord:
		_star(Vector2(48, -128), 12.0, Color(0.6, 0.85, 1.0))
	if active:
		var y := -170.0 + sin(t * 5.0) * 6.0
		draw_colored_polygon(PackedVector2Array([Vector2(-14, y), Vector2(14, y), Vector2(0, y + 18)]), Color(1, 0.9, 0.4))


func _star(c: Vector2, r: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 10:
		var a := -PI / 2 + i * PI / 5
		var rr := r if i % 2 == 0 else r * 0.45
		pts.append(c + Vector2(cos(a), sin(a)) * rr)
	draw_colored_polygon(pts, col)
