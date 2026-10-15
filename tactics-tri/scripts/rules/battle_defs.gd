class_name BattleDefs
extends RefCounted
## Battle maps (10x10). heights: one digit per tile; terrain codes see Terrain.CODES
## ("w" = deep water / river, impassable on foot; "d" = ford, "b" = bridge).
## x grows to the east, y grows to the south.

const DEFS := {
	"b1": {
		"name": "第一战 · 青石渡石桥",
		"win": "all", "win_text": "击败全部敌人", "lose_text": "林砚倒下，或我方全灭",
		"sky": Color(0.42, 0.62, 0.80),
		"heights": [
			"3322111223",
			"3321111123",
			"2211111112",
			"1111111111",
			"0000110000",
			"0000110000",
			"1111111111",
			"1122111111",
			"2222211211",
			"2233211111",
		],
		"terrain": [
			"ffgggsgffr",
			"fgggssgggr",
			"ggggsgggfg",
			"gggrsrgggg",
			"wwwwbbwwdw",
			"wwwwbbwwdw",
			"ggrgsggggg",
			"gfggsgfggg",
			"ffggsgggfg",
			"ffgggsggff",
		],
		"party": [
			["linyan", Vector2i(4, 8), 0], ["gelan", Vector2i(5, 7), 0], ["suzhi", Vector2i(2, 8), 0],
			["wenzhou", Vector2i(3, 9), 0], ["baitang", Vector2i(5, 9), 0], ["moqi", Vector2i(7, 8), 0],
		],
		"enemies": [
			{"name": "鸦卒甲", "cls": "swordsman", "pos": Vector2i(3, 2), "facing": 4, "bonus": {"hp": -8, "atk": -2}},
			{"name": "鸦卒乙", "cls": "swordsman", "pos": Vector2i(6, 1), "facing": 4, "bonus": {"hp": -8, "atk": -2}},
			{"name": "鸦枪", "cls": "lancer", "pos": Vector2i(5, 3), "facing": 4, "bonus": {"hp": -8, "atk": -2}},
			{"name": "鸦弩", "cls": "archer", "pos": Vector2i(1, 0), "facing": 4, "bonus": {"hp": -6, "atk": -2}},
			{"name": "鸦巫", "cls": "mage", "pos": Vector2i(8, 1), "facing": 4, "bonus": {"hp": -6, "mag": -3}},
		],
	},
	"b2A": {
		"name": "第二战 · 雪岭隘口",
		"win": "leader", "win_text": "击败斥候长「隼目」", "lose_text": "林砚倒下，或我方全灭",
		"sky": Color(0.70, 0.76, 0.86),
		"heights": [
			"6644322366",
			"6543211236",
			"4432111234",
			"4421111123",
			"3321001122",
			"3211001122",
			"2211111111",
			"2111111211",
			"1111112221",
			"1111122222",
		],
		"terrain": [
			"xxnnnsnnxx",
			"xnnnsssnnx",
			"nnnssfsnnn",
			"nnfsssssnn",
			"nnsswwssnn",
			"nfsswwssfn",
			"nnsssssnnn",
			"nnnssrsnnn",
			"nfnsssnnfn",
			"nnnssnnnnn",
		],
		"party": [
			["linyan", Vector2i(4, 8), 0], ["gelan", Vector2i(3, 8), 0], ["suzhi", Vector2i(1, 9), 0],
			["wenzhou", Vector2i(5, 9), 0], ["baitang", Vector2i(4, 9), 0], ["moqi", Vector2i(6, 8), 0],
		],
		"enemies": [
			{"name": "隼目", "title": "灰鸦斥候长", "cls": "archer", "pos": Vector2i(2, 1), "facing": 4, "leader": true, "ai": "hold",
				"bonus": {"hp": 12, "def": 2}},
			{"name": "鸦弩甲", "cls": "archer", "pos": Vector2i(7, 1), "facing": 4, "bonus": {"hp": -10, "atk": -3}},
			{"name": "鸦弩乙", "cls": "archer", "pos": Vector2i(1, 3), "facing": 4, "bonus": {"hp": -10, "atk": -3}},
			{"name": "鸦卒甲", "cls": "swordsman", "pos": Vector2i(3, 4), "facing": 4, "bonus": {"hp": -8, "atk": -2}},
			{"name": "鸦卒乙", "cls": "swordsman", "pos": Vector2i(6, 4), "facing": 4, "bonus": {"hp": -8, "atk": -2}},
			{"name": "鸦影", "cls": "thief", "pos": Vector2i(8, 3), "facing": 4, "bonus": {"hp": -6, "atk": -2}},
		],
	},
	"b2B": {
		"name": "第二战 · 渡口城寨",
		"win": "leader", "win_text": "击败灰鸦统领「铁喙」", "lose_text": "林砚倒下，或我方全灭",
		"sky": Color(0.56, 0.66, 0.78),
		"heights": [
			"4433333344",
			"3322222233",
			"3222222223",
			"4343223434",
			"1111111111",
			"1111111111",
			"1110001111",
			"1100000111",
			"1111001111",
			"1111111111",
		],
		"terrain": [
			"ssssssssss",
			"sgggssgggs",
			"sgfgssgfgs",
			"xsxssssxsx",
			"ggrggggrgg",
			"gggggsgggg",
			"gggdwdgfgg",
			"gfdwwwdggg",
			"ggggddgggg",
			"gggsssggfg",
		],
		"party": [
			["linyan", Vector2i(4, 2), 4], ["gelan", Vector2i(5, 3), 4], ["suzhi", Vector2i(3, 3), 4],
			["wenzhou", Vector2i(6, 2), 4], ["baitang", Vector2i(5, 1), 4], ["moqi", Vector2i(8, 3), 4],
		],
		"enemies": [
			{"name": "铁喙", "title": "灰鸦统领", "cls": "warlord", "pos": Vector2i(4, 9), "facing": 0, "leader": true, "ai": "hold",
				"bonus": {"hp": 6}},
			{"name": "鸦枪甲", "cls": "lancer", "pos": Vector2i(2, 5), "facing": 0, "bonus": {"hp": -8, "atk": -2}},
			{"name": "鸦枪乙", "cls": "lancer", "pos": Vector2i(7, 5), "facing": 0, "bonus": {"hp": -8, "atk": -2}},
			{"name": "鸦卒", "cls": "swordsman", "pos": Vector2i(1, 4), "facing": 0, "bonus": {"hp": -8, "atk": -2}},
			{"name": "鸦弩", "cls": "archer", "pos": Vector2i(6, 8), "facing": 0, "bonus": {"hp": -8, "atk": -2}},
			{"name": "鸦巫", "cls": "mage", "pos": Vector2i(2, 8), "facing": 0, "bonus": {"hp": -6, "mag": -3}},
			{"name": "鸦医", "cls": "healer", "pos": Vector2i(5, 9), "facing": 0},
		],
	},
}


static func get_def(id: String) -> Dictionary:
	if id == "wuxia_b1":
		return {"name": "青崖渡 · 渡口截箱", "win": "all", "win_text": "击败全部劫客", "lose_text": "我方全灭", "sky": Color(0.45, 0.62, 0.78)}
	return DEFS[id]


static func build_map(id: String) -> BattleMap:
	if id == "wuxia_b1":
		var map_raw: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/wuxia/b1_map.json"))
		return BattleMap.from_char_grid(map_raw["terrain_grid"], map_raw.get("markers", {}))
	var d: Dictionary = DEFS[id]
	return BattleMap.from_rows(d["heights"], d["terrain"])


static func _vec_facing(arr: Array) -> int:
	return Combat.dir_toward(Vector2i.ZERO, Vector2i(int(arr[0]), int(arr[1])), 4)


static func build_wuxia_b1(seed := 7) -> BattleState:
	var map_raw: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/wuxia/b1_map.json"))
	var combat_raw: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/wuxia/b1_combat.json"))
	var map := BattleMap.from_char_grid(map_raw["terrain_grid"], map_raw.get("markers", {}))
	var markers: Dictionary = map_raw.get("markers", {})
	var units: Array = []
	for definition in combat_raw["units"]:
		var u := BattleUnit.new()
		u.id = int(definition["id"])
		u.name = String(definition["name"])
		u.key = u.name
		u.use_gdd_rules = true
		u.team = BattleUnit.PLAYER if definition["side"] == "player" else BattleUnit.ENEMY
		u.max_hp = int(definition["max_hp"])
		u.hp = int(definition["hp"])
		u.atk = int(definition["strength"])
		u.def = int(definition["armor"])
		u.acc = int(definition.get("accuracy", 0))
		u.eva = int(definition.get("evasion", 0))
		u.spd = int(definition["speed"])
		u.max_qi = int(definition.get("qi", 12))
		u.qi = u.max_qi
		u.max_ap = 6
		u.ap = 6
		u.rp = 1
		u.jump = 99
		u.mov = 6
		u.basic = "普攻"
		u.active_skills = (definition.get("skills", []) as Array).duplicate()
		u.inner = String(definition.get("inner", ""))
		u.lightfoot = String(definition.get("lightfoot", ""))
		u.weapon = String(definition.get("weapon", ""))
		u.skills = u.active_skills.duplicate()
		if u.lightfoot != "":
			u.skills.append(u.lightfoot)
		u.skills.append("防御")
		u.skills.append("调息")
		var marker_key := String(definition["marker"])
		var spots: Array = markers[marker_key]
		u.pos = Vector2i(int(spots[0][0]), int(spots[0][1]))
		u.facing = _vec_facing(definition["facing"])
		# B1 is lost only when the whole party falls (GDD 25.1).
		u.is_lord = false
		u.title = "青崖渡同行" if u.team == BattleUnit.PLAYER else "渡口劫匪"
		u.ai = "aggressive"
		u.cls = "lancer" if u.weapon == "spear" else "swordsman"
		units.append(u)
	var s := BattleState.new()
	s.setup(map, units, "all", seed)
	return s


static func build_state(id: String, seed := 7) -> BattleState:
	if id == "wuxia_b1":
		return build_wuxia_b1(seed)
	var d: Dictionary = DEFS[id]
	var units := []
	var next_id := 0
	for entry in d["party"]:
		var key: String = entry[0]
		var p: Dictionary = StoryData.PARTY[key]
		var u := BattleUnit.create(next_id, p["name"], p["cls"], BattleUnit.PLAYER, entry[1], entry[2], p.get("bonus", {}))
		u.key = key
		u.title = p["title"]
		u.is_lord = bool(p.get("lord", false))
		units.append(u)
		next_id += 1
	next_id = 10
	for e in d["enemies"]:
		var u := BattleUnit.create(next_id, e["name"], e["cls"], BattleUnit.ENEMY, e["pos"], e.get("facing", 4), e.get("bonus", {}))
		u.title = e.get("title", "灰鸦军 · " + UnitClasses.class_name_of(e["cls"]))
		u.is_leader = bool(e.get("leader", false))
		u.ai = e.get("ai", "aggressive")
		units.append(u)
		next_id += 1
	var s := BattleState.new()
	s.setup(build_map(id), units, d["win"], seed)
	return s
