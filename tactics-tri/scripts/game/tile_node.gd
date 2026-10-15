extends Node2D
## One isometric map column: stacked side layers by height, top diamond, overlays.
## The node's position is the center of the top diamond.

const TW := IsoView.TW
const TH := IsoView.TH
const HS := IsoView.HS
const DIAMOND := IsoView.DIAMOND

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
		textures[path] = load(path) if ResourceLoader.exists(path) else null
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
	var info := Terrain.info(terrain)
	var art: String = "water" if terrain == "ford" else String(info.get("art", terrain))
	if not ResourceLoader.exists("res://assets/tiles/top_%s_0.png" % art):
		art = "grass"
	var side := tex("res://assets/tiles/side_%s.png" % art)
	for i in range(h, 0, -1):
		if side:
			draw_texture(side, Vector2(-TW * 0.5, i * HS))
	var sidetop := tex("res://assets/tiles/sidetop_%s.png" % art)
	if sidetop:
		draw_texture(sidetop, Vector2(-TW * 0.5, 0))
	var variant := posmod(cell.x * 7 + cell.y * 11, 4)
	var top := tex("res://assets/tiles/top_%s_%d.png" % [art, variant])
	if top:
		draw_texture(top, Vector2(-TW * 0.5, -TH * 0.5))
	if terrain == "water":
		_deep_water()
	elif terrain == "ford":
		_ford()
	if effect == "ice":
		draw_texture_rect(tex("res://assets/tiles/fx_ice.png"), Rect2(-TW * 0.5, -TH * 0.5, TW, TH), false)
	if hl.a > 0.0:
		_diamond(hl, 0.94)
	if edge.a > 0.0:
		_diamond(Color(edge.r, edge.g, edge.b, 0.045), 0.94, edge)
	if hl2.a > 0.0:
		_diamond(hl2, 0.86)
	# Selected outline is drawn by TileCursor (higher z) so it stays above units.
	if terrain == "forest":
		var tree := tex("res://assets/tiles/deco_tree.png")
		draw_texture(tree, Vector2(-58, -69))
		draw_texture(tree, Vector2(22, -79))
	elif terrain == "ruins":
		draw_texture(tex("res://assets/tiles/deco_rubble.png"), Vector2(-10, -40))
	elif terrain == "crate" or terrain == "cart":
		_draw_box(terrain == "cart")
	elif terrain == "shrine":
		_draw_stele()
	elif terrain == "trap":
		_draw_spikes()
	if effect == "fire":
		draw_texture_rect(tex("res://assets/tiles/fx_fire.png"), Rect2(-TW * 0.5, -TH, TW, TH * 1.5), false)


func _draw_box(tall: bool) -> void:
	var h := 34.0 if tall else 26.0
	draw_rect(Rect2(-18, -h, 36, h), Color(0.56, 0.36, 0.20))
	draw_rect(Rect2(-18, -h, 36, 5), Color(0.74, 0.52, 0.30))
	draw_line(Vector2(-16, -h + 4), Vector2(14, -6), Color(0.32, 0.18, 0.10), 2.0)
	draw_line(Vector2(14, -h + 4), Vector2(-16, -6), Color(0.32, 0.18, 0.10), 2.0)


func _draw_stele() -> void:
	draw_rect(Rect2(-12, -52, 24, 40), Color(0.62, 0.60, 0.54))
	draw_rect(Rect2(-16, -14, 32, 8), Color(0.38, 0.36, 0.32))
	draw_line(Vector2(-6, -44), Vector2(-6, -22), Color(0.40, 0.38, 0.34), 2.0)


func _draw_spikes() -> void:
	draw_colored_polygon(PackedVector2Array([
		Vector2(-20, 8), Vector2(-10, -18), Vector2(0, 4), Vector2(10, -18), Vector2(20, 8)
	]), Color(0.62, 0.28, 0.16, 0.95))


func _diamond(c: Color, s: float, outline := Color(0, 0, 0, 0)) -> void:
	var pts := PackedVector2Array()
	for v in DIAMOND:
		pts.append(v * s)
	draw_colored_polygon(pts, c)
	var line := outline if outline.a > 0.0 else Color(c.r, c.g, c.b, minf(1.0, c.a + 0.45))
	pts.append(pts[0])
	draw_polyline(pts, line, 2.0 if outline.a > 0.0 else 1.5, true)


## Deep river: darker, with current ripples, so it reads as "cannot wade here".
func _deep_water() -> void:
	var pts := PackedVector2Array()
	for v in DIAMOND:
		pts.append(v * 0.96)
	draw_colored_polygon(pts, Color(0.02, 0.14, 0.24, 0.30))
	var wave := Color(0.66, 0.84, 0.83, 0.38)
	for row in [-16.0, 2.0, 20.0]:
		var w := 46.0 - absf(row) * 0.9
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
