extends Node2D
## One isometric map column: stacked side layers by height, top diamond, overlays.
## The node's position is the center of the top diamond.

const TW := 128.0
const TH := 64.0
const HS := 32.0
const DIAMOND := [Vector2(0, -32), Vector2(64, 0), Vector2(0, 32), Vector2(-64, 0)]

static var textures := {}

var cell := Vector2i.ZERO
var h := 0
var terrain := "grass"
var effect := ""
var hl := Color(0, 0, 0, 0)
var hl2 := Color(0, 0, 0, 0)
var edge := Color(0, 0, 0, 0)  # outline-only highlight (attack reach beyond the move range)
var cursor := false  # kept for API compat; outline is drawn by TileCursor above units
var view: IsoView


static func tex(path: String) -> Texture2D:
	if not textures.has(path):
		textures[path] = load(path)
	return textures[path]


## Unrotated iso helper (yaw 0). Prefer IsoView.screen when a view exists.
static func iso(p: Vector2i, height: int) -> Vector2:
	return Vector2((p.x - p.y) * TW * 0.5, (p.x + p.y) * TH * 0.5 - height * HS)


func setup(p: Vector2i, height: int, t: String, v: IsoView) -> void:
	cell = p
	h = height
	terrain = t
	view = v
	relayout()


func relayout() -> void:
	position = view.screen(cell, h)
	z_index = view.tile_z(cell)


## Hit test against the visible column (top face plus side faces), in local coordinates.
func contains_local(l: Vector2) -> bool:
	return view.column_contains(l, h)


func _draw() -> void:
	var art := "water" if terrain == "ford" else terrain
	var side := tex("res://assets/tiles/side_%s.png" % art)
	for i in range(h, 0, -1):
		draw_texture(side, Vector2(-64, i * HS))
	draw_texture(tex("res://assets/tiles/sidetop_%s.png" % art), Vector2(-64, 0))
	draw_texture(tex("res://assets/tiles/top_%s.png" % art), Vector2(-64, -32))
	if terrain == "water":
		_deep_water()
	elif terrain == "ford":
		_ford()
	if effect == "ice":
		draw_texture(tex("res://assets/tiles/fx_ice.png"), Vector2(-64, -32))
	if hl.a > 0.0:
		_diamond(hl, 0.9)
	if edge.a > 0.0:
		_diamond(Color(edge.r, edge.g, edge.b, 0.14), 0.84, edge)
	if hl2.a > 0.0:
		_diamond(hl2, 0.7)
	# Selected outline is drawn by TileCursor (higher z) so it stays above units.
	if terrain == "forest":
		var tree := tex("res://assets/tiles/deco_tree.png")
		draw_texture(tree, Vector2(-46, -70))
		draw_texture(tree, Vector2(8, -78))
	elif terrain == "ruins":
		draw_texture(tex("res://assets/tiles/deco_rubble.png"), Vector2(-10, -40))
	if effect == "fire":
		draw_texture(tex("res://assets/tiles/fx_fire.png"), Vector2(-64, -64))


func _diamond(c: Color, s: float, outline := Color(0, 0, 0, 0)) -> void:
	var pts := PackedVector2Array()
	for v in DIAMOND:
		pts.append(v * s)
	draw_colored_polygon(pts, c)
	var line := outline if outline.a > 0.0 else Color(c.r, c.g, c.b, minf(1.0, c.a + 0.45))
	pts.append(pts[0])
	draw_polyline(pts, line, 4.0 if outline.a > 0.0 else 3.0)


## Deep river: darker, with current ripples, so it reads as "cannot wade here".
func _deep_water() -> void:
	var pts := PackedVector2Array()
	for v in DIAMOND:
		pts.append(v * 0.96)
	draw_colored_polygon(pts, Color(0.02, 0.10, 0.32, 0.42))
	var wave := Color(0.75, 0.9, 1.0, 0.55)
	for row in [-12.0, 2.0, 16.0]:
		var w := 34.0 - absf(row) * 0.9
		var line := PackedVector2Array()
		for i in 7:
			var x := -w + 2.0 * w * i / 6.0
			line.append(Vector2(x, row + sin(i * 1.7 + cell.x + cell.y) * 3.0))
		draw_polyline(line, wave, 2.0)


## Shallow ford: sandy bed showing through, plus stepping stones.
func _ford() -> void:
	var pts := PackedVector2Array()
	for v in DIAMOND:
		pts.append(v * 0.9)
	draw_colored_polygon(pts, Color(0.92, 0.84, 0.58, 0.38))
	for s in [Vector2(-26, -2), Vector2(0, -12), Vector2(4, 10), Vector2(28, 1)]:
		var stone := PackedVector2Array()
		for i in 10:
			var a := TAU * i / 10.0
			stone.append(s + Vector2(cos(a) * 9.0, sin(a) * 5.0))
		draw_colored_polygon(stone, Color(0.62, 0.6, 0.55))
		draw_polyline(stone + PackedVector2Array([stone[0]]), Color(0.3, 0.3, 0.3, 0.7), 1.5)
