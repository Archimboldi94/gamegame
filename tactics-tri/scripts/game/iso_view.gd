class_name IsoView
extends RefCounted
## Isometric display mapping with 90° yaw. Logical battle cells never change;
## only screen positions / draw order / facing arrows rotate with the camera.

const TW := 160.0
const TH := 80.0
const HS := 40.0
const DIAMOND := [Vector2(0, -TH * 0.5), Vector2(TW * 0.5, 0), Vector2(0, TH * 0.5), Vector2(-TW * 0.5, 0)]
const ISO_DIR := [
	Vector2(0.894, -0.447), Vector2(1, 0), Vector2(0.894, 0.447), Vector2(0, 1),
	Vector2(-0.894, 0.447), Vector2(-1, 0), Vector2(-0.894, -0.447), Vector2(0, -1),
]

var yaw := 0
var map_w := 1
var map_h := 1


func configure(w: int, h: int, start_yaw := 0) -> void:
	map_w = w
	map_h = h
	yaw = posmod(start_yaw, 4)


func rotate_by(steps: int) -> void:
	yaw = posmod(yaw + steps, 4)


## Logical cell -> display cell for the current yaw (clockwise quarters).
func to_display(p: Vector2i) -> Vector2i:
	match yaw:
		1:
			return Vector2i(p.y, map_w - 1 - p.x)
		2:
			return Vector2i(map_w - 1 - p.x, map_h - 1 - p.y)
		3:
			return Vector2i(map_h - 1 - p.y, p.x)
		_:
			return p


## Display cell -> logical cell.
func to_logical(d: Vector2i) -> Vector2i:
	match yaw:
		1:
			return Vector2i(map_w - 1 - d.y, d.x)
		2:
			return Vector2i(map_w - 1 - d.x, map_h - 1 - d.y)
		3:
			return Vector2i(d.y, map_h - 1 - d.x)
		_:
			return d


func screen(p: Vector2i, height: int) -> Vector2:
	var d := to_display(p)
	return Vector2((d.x - d.y) * TW * 0.5, (d.x + d.y) * TH * 0.5 - height * HS)


func tile_z(p: Vector2i) -> int:
	var d := to_display(p)
	return (d.x + d.y) * 2


func unit_z(p: Vector2i) -> int:
	return tile_z(p) + 1


func cursor_z(p: Vector2i) -> int:
	return tile_z(p) + 8


func facing_view(facing: int) -> int:
	return posmod(facing - yaw * 2, 8)


func screen_dir(facing: int) -> Vector2:
	return ISO_DIR[facing_view(facing)]


func faces_left(facing: int) -> bool:
	return screen_dir(facing).x < 0


## Hit-test against one isometric column (top diamond + side faces), local space.
## Tips are excluded so neighbouring diamonds do not share an edge pixel.
func column_contains(local: Vector2, height: int) -> bool:
	var ax := absf(local.x)
	if ax >= TW * 0.5:
		return false
	var top_edge := -TH * 0.5 + ax * TH / TW
	var bottom_edge := TH * 0.5 - ax * TH / TW + (height + 1) * HS
	return local.y >= top_edge and local.y <= bottom_edge


## Top diamond only (ignores side faces). Preferred for finger picking.
func top_contains(local: Vector2) -> bool:
	var ax := absf(local.x)
	if ax >= TW * 0.5:
		return false
	var top_edge := -TH * 0.5 + ax * TH / TW
	var bottom_edge := TH * 0.5 - ax * TH / TW
	return local.y >= top_edge and local.y <= bottom_edge


## Grid pick under a world-space point. Uses tile geometry only — never unit sprites.
## Prefers a top-face hit (so a taller front tile's side wall does not steal the cell
## behind it); among top hits, the diamond centre closest to the finger wins.
## Column hits are a fallback, preferring front-most z.
func pick(world: Vector2, map: BattleMap) -> Vector2i:
	var best := Vector2i(-1, -1)
	var best_z := -1
	var best_dist := INF
	var best_on_top := false
	for y in map.height:
		for x in map.width:
			var logical := Vector2i(x, y)
			var ht := map.get_h(logical)
			var pos := screen(logical, ht)
			var local := world - pos
			var on_top := top_contains(local)
			if not on_top and not column_contains(local, ht):
				continue
			var z := tile_z(logical)
			# Weight x a bit more: iso diamonds are wider than tall.
			var dist := absf(local.x) * 0.5 + absf(local.y)
			var better := false
			if on_top and not best_on_top:
				better = true
			elif on_top and best_on_top:
				better = dist < best_dist - 0.01
			elif not on_top and not best_on_top:
				if z > best_z or (z == best_z and dist < best_dist):
					better = true
			if better:
				best_on_top = on_top
				best_z = z
				best_dist = dist
				best = logical
	return best


## Static helpers used by headless tests without constructing a view.
static func rotate_cell(p: Vector2i, yaw_q: int, w: int, h: int) -> Vector2i:
	var v := IsoView.new()
	v.configure(w, h, yaw_q)
	return v.to_display(p)


static func unrotate_cell(d: Vector2i, yaw_q: int, w: int, h: int) -> Vector2i:
	var v := IsoView.new()
	v.configure(w, h, yaw_q)
	return v.to_logical(d)
