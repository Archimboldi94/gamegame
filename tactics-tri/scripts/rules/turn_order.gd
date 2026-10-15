class_name TurnOrder
extends RefCounted
## CT (charge time) timeline. Every unit gains `spd` CT per tick; a unit with CT >= THRESHOLD acts.
## Ending a turn subtracts a cost that depends on what the unit did (waiting delays less).

const THRESHOLD := 100
const COST_FULL := 100
const SAVE_NO_MOVE := 20
const SAVE_NO_ACT := 20

var entries: Dictionary = {}  # id -> {"spd": int, "ct": int}
var use_rounds := false
var round_number := 0
var round_queue: Array = []


static func cost_for(moved: bool, acted: bool) -> int:
	var c := COST_FULL
	if not moved:
		c -= SAVE_NO_MOVE
	if not acted:
		c -= SAVE_NO_ACT
	return c


func add(id: int, spd: int, ct := 0) -> void:
	entries[id] = {"spd": maxi(1, spd), "ct": ct}


func remove(id: int) -> void:
	entries.erase(id)
	round_queue.erase(id)


func has(id: int) -> bool:
	return entries.has(id)


func ct_of(id: int) -> int:
	return entries[id]["ct"] if entries.has(id) else 0


func delay(id: int, amount: int) -> void:
	if entries.has(id):
		entries[id]["ct"] -= amount


func _ready_ids() -> Array:
	var best := -1
	for id in entries:
		if entries[id]["ct"] >= THRESHOLD:
			if best < 0 or _better(id, best):
				best = id
	return [best] if best >= 0 else []


func _better(a: int, b: int) -> bool:
	var ea: Dictionary = entries[a]
	var eb: Dictionary = entries[b]
	if ea["ct"] != eb["ct"]:
		return ea["ct"] > eb["ct"]
	if ea["spd"] != eb["spd"]:
		return ea["spd"] > eb["spd"]
	return a < b


## Advance time until some unit is ready and return its id (-1 if empty).
func next_actor() -> int:
	if entries.is_empty():
		return -1
	if use_rounds:
		if round_queue.is_empty():
			round_number += 1
			round_queue = entries.keys()
			round_queue.sort_custom(func(a, b): return entries[a]["spd"] > entries[b]["spd"] if entries[a]["spd"] != entries[b]["spd"] else a < b)
		return round_queue[0]
	var r := _ready_ids()
	if r.is_empty():
		var min_t := 1 << 30
		for id in entries:
			var e: Dictionary = entries[id]
			var need: int = THRESHOLD - int(e["ct"])
			var t := ceili(float(need) / float(e["spd"]))
			min_t = mini(min_t, t)
		for id in entries:
			entries[id]["ct"] += min_t * int(entries[id]["spd"])
		r = _ready_ids()
	return r[0]


func end_turn(id: int, cost: int) -> void:
	if use_rounds:
		round_queue.erase(id)
		return
	if entries.has(id):
		entries[id]["ct"] -= cost


func duplicate_order() -> TurnOrder:
	var t := TurnOrder.new()
	t.entries = entries.duplicate(true)
	t.use_rounds = use_rounds
	t.round_number = round_number
	t.round_queue = round_queue.duplicate()
	return t


## Predict the next n actors. If `current` >= 0 it is the unit acting right now (listed first,
## assumed to spend a full turn).
func preview(n: int, current := -1) -> Array:
	var sim := duplicate_order()
	var out := []
	if current >= 0 and sim.has(current):
		out.append(current)
		sim.end_turn(current, COST_FULL)
	while out.size() < n and not sim.entries.is_empty():
		var id := sim.next_actor()
		out.append(id)
		sim.end_turn(id, COST_FULL)
	return out
