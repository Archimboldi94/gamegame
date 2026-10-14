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
var cursor := false


static func iso(p: Vector2i, height: int) -> Vector2:
	return Vector2((p.x - p.y) * TW * 0.5, (p.x + p.y) * TH * 0.5 - height * HS)


static func tex(path: String) -> Texture2D:
	if not textures.has(path):
		textures[path] = load(path)
	return textures[path]


func setup(p: Vector2i, height: int, t: String) -> void:
	cell = p
	h = height
	terrain = t
	position = iso(p, height)
	z_index = (p.x + p.y) * 2


func _draw() -> void:
	var side := tex("res://assets/tiles/side_%s.png" % terrain)
	for i in range(h, 0, -1):
		draw_texture(side, Vector2(-64, i * HS))
	draw_texture(tex("res://assets/tiles/sidetop_%s.png" % terrain), Vector2(-64, 0))
	draw_texture(tex("res://assets/tiles/top_%s.png" % terrain), Vector2(-64, -32))
	if effect == "ice":
		draw_texture(tex("res://assets/tiles/fx_ice.png"), Vector2(-64, -32))
	if hl.a > 0.0:
		_diamond(hl, 0.9)
	if hl2.a > 0.0:
		_diamond(hl2, 0.7)
	if cursor:
		var pts := PackedVector2Array()
		for v in DIAMOND:
			pts.append(v * 0.95)
		pts.append(pts[0])
		draw_polyline(pts, Color(1, 1, 1, 0.95), 5.0)
	if terrain == "forest":
		var tree := tex("res://assets/tiles/deco_tree.png")
		draw_texture(tree, Vector2(-46, -70))
		draw_texture(tree, Vector2(8, -78))
	elif terrain == "ruins":
		draw_texture(tex("res://assets/tiles/deco_rubble.png"), Vector2(-10, -40))
	if effect == "fire":
		draw_texture(tex("res://assets/tiles/fx_fire.png"), Vector2(-64, -64))


func _diamond(c: Color, s: float) -> void:
	var pts := PackedVector2Array()
	for v in DIAMOND:
		pts.append(v * s)
	draw_colored_polygon(pts, c)
	var edge := Color(c.r, c.g, c.b, minf(1.0, c.a + 0.45))
	pts.append(pts[0])
	draw_polyline(pts, edge, 3.0)


## Hit test against the visible column (top face plus side faces), in local coordinates.
func contains_local(l: Vector2) -> bool:
	var ax := absf(l.x)
	if ax > 64.0:
		return false
	var top_edge := -32.0 + ax * 0.5
	var bottom_edge := 32.0 - ax * 0.5 + (h + 1) * HS
	return l.y >= top_edge and l.y <= bottom_edge
