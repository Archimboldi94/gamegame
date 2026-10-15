extends RefCounted
## Pure board/grid rules. 8-direction move: orthogonal/diagonal cost 1, mud cost 2.
const DIRECTIONS: Array[Vector2i] = [Vector2i(-1,-1), Vector2i(0,-1), Vector2i(1,-1), Vector2i(-1,0), Vector2i(1,0), Vector2i(-1,1), Vector2i(0,1), Vector2i(1,1)]
var cells: Array[String] = []
var width: int = 0
var height: int = 0

func load_from(path: String) -> bool:
    var file: FileAccess = FileAccess.open(path, FileAccess.READ)
    if file == null:
        push_error("Unable to open map: " + path)
        return false
    var raw: Variant = JSON.parse_string(file.get_as_text())
    if not (raw is Dictionary):
        push_error("Map JSON invalid")
        return false
    width = int(raw.get("width", 0))
    height = int(raw.get("height", 0))
    cells.clear()
    for line in raw.get("terrain_grid", []):
        cells.append(str(line))
    if cells.size() != height:
        push_error("Map height mismatch")
        return false
    for row in cells:
        if row.length() != width:
            push_error("Map width mismatch")
            return false
    return true

func inside(p: Vector2i) -> bool:
    return p.x >= 0 and p.y >= 0 and p.x < width and p.y < height

func tile(p: Vector2i) -> String:
    if not inside(p):
        return "#"
    return cells[p.y].substr(p.x, 1)

func solid(p: Vector2i) -> bool:
    return tile(p) in ["#", "~", "C", "h", "H"]

func travel_cost(p: Vector2i) -> int:
    return 2 if tile(p) == "m" else 1

func occupied(p: Vector2i, units: Array[Dictionary], ignore_id: int = -1) -> bool:
    for u in units:
        if int(u["id"]) != ignore_id and int(u["hp"]) > 0 and u["pos"] == p:
            return true
    return false

func can_step(at: Vector2i, nxt: Vector2i, units: Array[Dictionary], ignore_id: int = -1) -> bool:
    if solid(nxt) or occupied(nxt, units, ignore_id):
        return false
    var d: Vector2i = nxt-at
    if maxi(absi(d.x),absi(d.y)) != 1:
        return false
    # A sealed diagonal corner cannot be crossed.
    if d.x != 0 and d.y != 0:
        if solid(at+Vector2i(d.x,0)) and solid(at+Vector2i(0,d.y)):
            return false
    return true

func path(start: Vector2i, goal: Vector2i, units: Array[Dictionary], ignore_id: int = -1) -> Array[Vector2i]:
    var empty: Array[Vector2i] = []
    if start == goal or solid(goal) or occupied(goal, units, ignore_id):
        return empty
    var open_set: Array[Vector2i] = [start]
    var dist: Dictionary = {start: 0}
    var previous: Dictionary = {}
    while not open_set.is_empty():
        var best: int = 0
        for i in range(1,open_set.size()):
            if int(dist[open_set[i]]) < int(dist[open_set[best]]):
                best = i
        var cur: Vector2i = open_set[best]
        open_set.remove_at(best)
        if cur == goal:
            break
        for d in DIRECTIONS:
            var nxt: Vector2i = cur+d
            if not can_step(cur,nxt,units,ignore_id):
                continue
            var candidate: int = int(dist[cur])+travel_cost(nxt)
            if not dist.has(nxt) or candidate < int(dist[nxt]):
                dist[nxt] = candidate
                previous[nxt] = cur
                if nxt not in open_set:
                    open_set.append(nxt)
    if not dist.has(goal):
        return empty
    var answer: Array[Vector2i] = []
    var cur: Vector2i = goal
    while cur != start:
        answer.push_front(cur)
        cur = previous[cur]
    return answer

func path_ap(route: Array[Vector2i]) -> int:
    var total: int = 0
    for p in route:
        total += travel_cost(p)
    return total

func leap_allowed(start: Vector2i, goal: Vector2i, units: Array[Dictionary], ignore_id: int) -> bool:
    if solid(goal) or occupied(goal,units,ignore_id):
        return false
    var d: Vector2i = goal-start
    var steps: int = maxi(absi(d.x),absi(d.y))
    if steps < 1 or steps > 3:
        return false
    # Only short walls/low obstacles can be cleared; no phasing through solid buildings or crates.
    for i in range(1,steps):
        var t: float = float(i)/float(steps)
        var p: Vector2i = Vector2i(roundi(float(start.x)+float(d.x)*t),roundi(float(start.y)+float(d.y)*t))
        if tile(p) in ["#","H","C"]:
            return false
    return true

func chebyshev(a: Vector2i, b: Vector2i) -> int:
    return maxi(absi(a.x-b.x),absi(a.y-b.y))

func in_line(a: Vector2i, b: Vector2i, max_distance: int) -> bool:
    var d: Vector2i = b-a
    var length: int = maxi(absi(d.x),absi(d.y))
    return length >= 1 and length <= max_distance and (d.x == 0 or d.y == 0 or absi(d.x)==absi(d.y))

func line_clear(a: Vector2i, b: Vector2i) -> bool:
    if not in_line(a,b,99):
        return false
    var d: Vector2i = b-a
    var step: Vector2i = Vector2i(signi(d.x),signi(d.y))
    var cursor: Vector2i = a+step
    while cursor != b:
        if solid(cursor):
            return false
        cursor += step
    return not solid(b)
