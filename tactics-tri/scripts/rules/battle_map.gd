class_name BattleMap
extends RefCounted
## Grid of tiles with integer heights, terrain types and temporary effects (fire / ice).

## GDD clockwise indices: N, NE, E, SE, S, SW, W, NW.
const DIRS := [Vector2i(0, -1), Vector2i(1, -1), Vector2i(1, 0), Vector2i(1, 1),
	Vector2i(0, 1), Vector2i(-1, 1), Vector2i(-1, 0), Vector2i(-1, -1)]

var markers: Dictionary = {}

var width := 0
var height := 0
var heights: Array = []
var terrains: Array = []
var effects: Dictionary = {}  # Vector2i -> {"type": String, "turns": int}


static func from_rows(height_rows: Array, terrain_rows: Array) -> BattleMap:
	var m := BattleMap.new()
	m.height = height_rows.size()
	m.width = String(height_rows[0]).length()
	for y in m.height:
		var hr := String(height_rows[y])
		var tr := String(terrain_rows[y])
		for x in m.width:
			m.heights.append(hr.substr(x, 1).to_int())
			m.terrains.append(Terrain.CODES[tr.substr(x, 1)])
	return m



static func from_char_grid(rows: Array, markers := {}) -> BattleMap:
	var m := BattleMap.new()
	m.height = rows.size()
	m.width = String(rows[0]).length()
	m.markers = markers.duplicate(true)
	for y in m.height:
		var row := String(rows[y])
		for x in m.width:
			var ch := row.substr(x, 1)
			var terrain: String = Terrain.CODES.get(ch, "grass")
			m.heights.append(0)
			m.terrains.append(terrain)
	return m

static func flat(w: int, h: int, terrain := "grass") -> BattleMap:
	var m := BattleMap.new()
	m.width = w
	m.height = h
	for i in w * h:
		m.heights.append(0)
		m.terrains.append(terrain)
	return m


func in_bounds(p: Vector2i) -> bool:
	return p.x >= 0 and p.y >= 0 and p.x < width and p.y < height


func _i(p: Vector2i) -> int:
	return p.y * width + p.x


func get_h(p: Vector2i) -> int:
	return heights[_i(p)] if in_bounds(p) else 0


func set_h(p: Vector2i, v: int) -> void:
	heights[_i(p)] = v


func get_terrain(p: Vector2i) -> String:
	return terrains[_i(p)] if in_bounds(p) else "wall"


func set_terrain(p: Vector2i, t: String) -> void:
	terrains[_i(p)] = t


func effect_at(p: Vector2i) -> String:
	if effects.has(p):
		return effects[p]["type"]
	return ""


## Walkable for ground units; flying units may additionally cross deep water.
func is_passable(p: Vector2i, flying := false) -> bool:
	if not in_bounds(p):
		return false
	var info := Terrain.info(get_terrain(p))
	return bool(info["pass"]) or (flying and bool(info.get("fly", false)))


func move_cost(p: Vector2i, flying := false) -> int:
	var t := get_terrain(p)
	if flying and is_passable(p, true):
		return 1
	var c: int = Terrain.info(t)["cost"]
	if effect_at(p) == "ice":
		c = 1 if t == "ford" else c + 1
	return c


func evasion(p: Vector2i) -> int:
	var e: int = Terrain.info(get_terrain(p))["eva"]
	if effect_at(p) == "ice":
		e -= 10
	return e


## Returns true if the effect took hold. Fire cannot burn on a ford (and melts ice); ice freezes fords.
## Deep water and walls take no effects at all.
func apply_effect(p: Vector2i, type: String) -> bool:
	if not is_passable(p):
		return false
	var t := get_terrain(p)
	if type == "fire":
		if t == "ford":
			return false
		if effect_at(p) == "ice":
			effects.erase(p)
			return false
		effects[p] = {"type": "fire", "turns": Terrain.FIRE_TURNS + (4 if t == "forest" else 0)}
		return true
	if type == "ice":
		if effect_at(p) == "fire":
			effects.erase(p)
			return false
		effects[p] = {"type": "ice", "turns": Terrain.ICE_TURNS}
		return true
	return false


func tick_effects() -> void:
	for p in effects.keys():
		effects[p]["turns"] -= 1
		if effects[p]["turns"] <= 0:
			effects.erase(p)


func neighbors(p: Vector2i) -> Array:
	var out := []
	for d in DIRS:
		var n: Vector2i = p + d
		if in_bounds(n):
			out.append(n)
	return out
