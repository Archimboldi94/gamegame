class_name BattleMap
extends RefCounted
## Grid of tiles with integer heights, terrain types and temporary effects (fire / ice).

const DIRS := [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]

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


func is_passable(p: Vector2i) -> bool:
	return in_bounds(p) and bool(Terrain.info(get_terrain(p))["pass"])


func move_cost(p: Vector2i) -> int:
	var t := get_terrain(p)
	var c: int = Terrain.info(t)["cost"]
	if effect_at(p) == "ice":
		c = 1 if t == "water" else c + 1
	return c


func evasion(p: Vector2i) -> int:
	var e: int = Terrain.info(get_terrain(p))["eva"]
	if effect_at(p) == "ice":
		e -= 10
	return e


## Returns true if the effect took hold. Fire cannot burn on water (and melts ice); ice freezes water.
func apply_effect(p: Vector2i, type: String) -> bool:
	if not is_passable(p):
		return false
	var t := get_terrain(p)
	if type == "fire":
		if t == "water":
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
