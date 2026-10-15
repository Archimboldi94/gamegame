class_name PartyState
extends RefCounted
## Chapter-owned progression and preparation. No nodes or scene dependencies.

const MAX_LEVEL := 10
const IDS := ["sword", "spear", "fist"] # B1 player unit IDs 0, 1, 2
const TRAITS := {"sword": "游锋", "spear": "守线", "fist": "通脉"}
const TRAINING := {
	"强身": ["max_hp", 4], "蓄劲": ["strength", 1], "护体": ["armor", 1],
	"凝神": ["accuracy", 3], "腾挪": ["evasion", 3], "迅捷": ["speed", 3], "调元": ["qi", 2],
}
const WEAPONS := {"sword": "剑", "spear": "枪", "fist": "拳掌", "blade": "刀"}
const REQUIREMENTS := {
	"破风剑": "sword", "回锋剑": "sword", "穿云枪": "spear", "挑枪": "spear",
	"横江刀": "blade", "震山掌": "fist", "截脉指": "fist",
}
const TRAIT_TEXT := {
	"游锋": "自身行动累计移动≥2格后，下一次主动单体攻击命中+5%；每行动一次。",
	"守线": "每轮第一次合法离区借机攻击命中+5%。",
	"通脉": "点穴／控制招式命中后，下次自身行动额外恢复1内力；每行动一次。",
}
## GDD 5.8 suggested branches: skill_id -> {branch_id: short desc}
const BRANCHES := {
	"破风剑": {"延锋": "直线射程3→4，内力+1", "凝锋": "改为单体攻击，破甲+2"},
	"回锋剑": {"游身": "本招后撤可安全脱离控制区", "回刺": "舍弃后撤，本次破甲+2"},
	"震山掌": {"摧阵": "合法击退距离1→2", "裂势": "命中前先破势再结算伤害"},
	"截脉指": {"探穴": "攻击距离1→2，内力+1", "封脉": "气脉受阻削减AP 2→3"},
	"归元诀": {"绵长": "内力上限+3", "逆息": "内力不足一半时，行动额外恢复1内力"},
	"燕行步": {"长跃": "轻功距离3→4，内力+1", "藏锋": "落地后下次受主动攻击命中-5%"},
}
const MASTERIES := {
	"sword": ["回旋", "凝锋"],
	"spear": ["拒敌", "沉稳"],
	"fist": ["截流", "活络"],
}
const MASTERY_TEXT := {
	"回旋": "自主后撤首次离开控制区时，借机命中-10%。",
	"凝锋": "本次行动第一次单体攻击固定破甲+1。",
	"拒敌": "反击命中后，目标下次移动首格额外耗1AP。",
	"沉稳": "行动结束剩余AP≥2时，下次受击临时护甲+1。",
	"截流": "气脉受阻对同一敌人首次生效时额外-1AP，每轮一次。",
	"活络": "若本行动调息成功，下次行动开始额外恢复1内力。",
}

var characters: Dictionary = {}
var library: Array[String] = []
var lesson := 0 # shared 武学心得; spent to unlock one refinement per art


func _init() -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/wuxia/b1_combat.json"))
	for i in IDS.size():
		var base: Dictionary = data["units"][i]
		var learned: Array = base["skills"].duplicate()
		# 回锋 is a first-clear reward. Keep only weapon-compatible starting slots.
		learned.erase("回锋剑")
		var active := ["", "", ""]
		var slot := 0
		for sid in learned:
			if compatible(base["weapon"], sid):
				active[slot] = sid
				slot += 1
		learned.append(base["inner"])
		learned.append(base["lightfoot"])
		characters[IDS[i]] = {"level": 1, "exp": 0, "training": {}, "learned": learned,
			"active": active, "inner": base["inner"], "lightfoot": base["lightfoot"], "weapon": base["weapon"],
			"branches": {}, "mastery": ""}
		for sid in learned:
			collect(sid)


static func exp_to_next(level: int) -> int:
	return 0 if level >= MAX_LEVEL else 100 + 40 * (level - 1)


func gain_exp(id: String, amount: int) -> int:
	if not characters.has(id) or amount <= 0:
		return 0
	var c: Dictionary = characters[id]
	var before := int(c["level"])
	if before == MAX_LEVEL:
		return 0
	c["exp"] += amount
	while c["level"] < MAX_LEVEL and c["exp"] >= exp_to_next(c["level"]):
		c["exp"] -= exp_to_next(c["level"])
		c["level"] += 1
	if c["level"] == MAX_LEVEL:
		c["exp"] = 0
	return int(c["level"]) - before


func level_baseline() -> float:
	var levels: Array = []
	for c in characters.values():
		levels.append(int(c["level"]))
	levels.sort()
	levels.reverse()
	levels = levels.slice(0, 3)
	return float(levels[levels.size() / 2]) if levels.size() % 2 else (levels[0] + levels[1]) / 2.0


## Snapshot the baseline before anyone levels; deployed includes fallen participants.
func award_battle_exp(base_exp: int, deployed: Array) -> Dictionary:
	var baseline := level_baseline()
	var awards := {}
	for id in characters:
		# Integer percentages avoid 0.6 * 1.5 rounding 108 down to 107.
		var numerator := 10 if deployed.has(id) else 6
		if baseline - int(characters[id]["level"]) >= 2:
			numerator *= 15
		else:
			numerator *= 10
		awards[id] = maxi(0, base_exp * numerator / 100) if characters[id]["level"] < MAX_LEVEL else 0
	for id in awards:
		gain_exp(id, awards[id])
	return awards


func training_points(id: String) -> int:
	var c: Dictionary = characters[id]
	var spent := 0
	for value in c["training"].values():
		spent += int(value)
	return int(c["level"]) - 1 - spent


func train(id: String, direction: String) -> bool:
	if not characters.has(id) or not TRAINING.has(direction) or training_points(id) <= 0:
		return false
	var allocation: Dictionary = characters[id]["training"]
	if int(allocation.get(direction, 0)) >= 4:
		return false
	allocation[direction] = int(allocation.get(direction, 0)) + 1
	return true


func reset_training(id: String) -> bool:
	if not characters.has(id):
		return false
	characters[id]["training"].clear()
	return true


func stats(id: String) -> Dictionary:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/wuxia/b1_combat.json"))
	var result: Dictionary = data["units"][IDS.find(id)].duplicate(true)
	var c: Dictionary = characters[id]
	result["max_hp"] += (int(c["level"]) - 1) * 3
	for direction in c["training"]:
		var bonus: Array = TRAINING[direction]
		result[bonus[0]] += int(c["training"][direction]) * int(bonus[1])
	result["hp"] = result["max_hp"]
	if String(c.get("branches", {}).get(c.get("inner", ""), "")) == "绵长":
		result["qi"] = int(result["qi"]) + 3
	return result


static func category(sid: String) -> String:
	if not SkillDB.get_inner(sid).is_empty():
		return "内功"
	if not SkillDB.has_skill(sid) or sid in ["普攻", "防御", "调息"]:
		return ""
	var sk := SkillDB.get_skill(sid)
	if not sk.get("gdd", false):
		return ""
	return "轻功" if sk["shape"] == "leap" else "招式"


static func compatible(weapon: String, sid: String) -> bool:
	return not REQUIREMENTS.has(sid) or REQUIREMENTS[sid] == weapon


func collect(sid: String) -> bool:
	if category(sid) == "" or library.has(sid):
		return false
	library.append(sid)
	return true


func learn(id: String, sid: String) -> bool:
	if not characters.has(id) or not library.has(sid) or characters[id]["learned"].has(sid):
		return false
	characters[id]["learned"].append(sid)
	return true


func can_equip(id: String, sid: String) -> bool:
	return characters.has(id) and characters[id]["learned"].has(sid) and compatible(characters[id]["weapon"], sid)


## Active slot 0..2; inner/lightfoot each have their own slot. Empty means unequip.
func equip(id: String, sid: String, slot := 0, kind := "招式") -> bool:
	if not characters.has(id) or not kind in ["招式", "内功", "轻功"] or (kind == "招式" and (slot < 0 or slot > 2)):
		return false
	if sid != "" and (category(sid) != kind or not can_equip(id, sid)):
		return false
	var c: Dictionary = characters[id]
	if kind == "招式":
		if sid != "" and c["active"].has(sid):
			c["active"][c["active"].find(sid)] = ""
		c["active"][slot] = sid
	else:
		c["inner" if kind == "内功" else "lightfoot"] = sid
	return true


func set_weapon(id: String, weapon: String) -> bool:
	if not characters.has(id) or not WEAPONS.has(weapon):
		return false
	var c: Dictionary = characters[id]
	c["weapon"] = weapon
	for i in 3:
		if not compatible(weapon, c["active"][i]):
			c["active"][i] = ""
	return true


func branch_options(sid: String) -> Array:
	if not BRANCHES.has(sid):
		return []
	return BRANCHES[sid].keys()


func can_refine(id: String, sid: String) -> bool:
	if not characters.has(id) or not BRANCHES.has(sid) or lesson < 1:
		return false
	var c: Dictionary = characters[id]
	return c["learned"].has(sid) and not c.get("branches", {}).has(sid)


## Spend 1 insight to unlock both branches; `branch` becomes the active one.
func refine(id: String, sid: String, branch: String) -> bool:
	if not can_refine(id, sid) or not BRANCHES[sid].has(branch):
		return false
	lesson -= 1
	characters[id]["branches"][sid] = branch
	return true


func set_branch(id: String, sid: String, branch: String) -> bool:
	if not characters.has(id) or not BRANCHES.has(sid) or not BRANCHES[sid].has(branch):
		return false
	var c: Dictionary = characters[id]
	if not c.get("branches", {}).has(sid):
		return false
	c["branches"][sid] = branch
	return true


func active_branch(id: String, sid: String) -> String:
	return String(characters.get(id, {}).get("branches", {}).get(sid, ""))


func mastery_options(id: String) -> Array:
	return MASTERIES.get(id, []).duplicate()


func can_choose_mastery(id: String) -> bool:
	return characters.has(id) and int(characters[id]["level"]) >= 4


func set_mastery(id: String, mastery: String) -> bool:
	if not can_choose_mastery(id):
		return false
	if mastery != "" and not MASTERIES.get(id, []).has(mastery):
		return false
	characters[id]["mastery"] = mastery
	return true


func apply_to_unit(u: BattleUnit) -> void:
	if not u.use_gdd_rules or u.team != BattleUnit.PLAYER or u.id < 0 or u.id >= IDS.size():
		return
	var id: String = IDS[u.id]
	var c: Dictionary = characters[id]
	var values := stats(id)
	u.level = int(c["level"])
	u.max_hp = int(values["max_hp"])
	u.hp = u.max_hp
	u.atk = int(values["strength"])
	u.def = int(values["armor"])
	u.acc = int(values["accuracy"])
	u.eva = int(values["evasion"])
	u.spd = int(values["speed"])
	u.max_qi = int(values["qi"])
	u.qi = u.max_qi
	u.weapon = c["weapon"]
	u.active_skills = []
	for sid in c["active"]:
		if sid != "" and can_equip(id, sid):
			u.active_skills.append(sid)
	u.inner = c["inner"]
	u.lightfoot = c["lightfoot"]
	u.skills = u.active_skills.duplicate()
	if u.lightfoot != "":
		u.skills.append(u.lightfoot)
	u.skills.append_array(["防御", "调息"])
	u.skill_branches = c.get("branches", {}).duplicate(true)
	u.mastery = String(c.get("mastery", ""))


func to_dict() -> Dictionary:
	return {"characters": characters.duplicate(true), "library": library.duplicate(), "lesson": lesson}


static func _integer(value: Variant, minimum: int, maximum: int) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and value == int(value) and value >= minimum and value <= maximum


static func from_dict(data: Dictionary) -> PartyState:
	if not data.get("characters") is Dictionary or not data.get("library") is Array or not _integer(data.get("lesson"), 0, 2147483647):
		return null
	var p := PartyState.new()
	p.library.clear()
	for sid in data["library"]:
		if not sid is String or not p.collect(sid):
			return null
	if data["characters"].size() != IDS.size():
		return null
	p.characters = data["characters"].duplicate(true)
	p.lesson = int(data["lesson"])
	for id in IDS:
		if not p.characters.get(id) is Dictionary:
			return null
		var c: Dictionary = p.characters[id]
		if not _integer(c.get("level"), 1, MAX_LEVEL) or not _integer(c.get("exp"), 0, maxi(0, exp_to_next(int(c["level"])) - 1)):
			return null
		if not c.get("training") is Dictionary or not c.get("learned") is Array or not c.get("active") is Array or c["active"].size() != 3 or not WEAPONS.has(c.get("weapon")):
			return null
		if not c.has("branches"):
			c["branches"] = {}
		if not c.has("mastery"):
			c["mastery"] = ""
		if not c.get("branches") is Dictionary or not c.get("mastery") is String:
			return null
		for direction in c["training"]:
			if not TRAINING.has(direction) or not _integer(c["training"][direction], 0, 4):
				return null
		if p.training_points(id) < 0:
			return null
		c["level"] = int(c["level"])
		c["exp"] = int(c["exp"])
		for direction in c["training"]:
			c["training"][direction] = int(c["training"][direction])
		for sid in c["branches"]:
			if not sid is String or not c["learned"].has(sid) or not BRANCHES.has(sid):
				return null
			if not c["branches"][sid] is String or not BRANCHES[sid].has(c["branches"][sid]):
				return null
		if c["mastery"] != "":
			if int(c["level"]) < 4 or not MASTERIES.get(id, []).has(c["mastery"]):
				return null
		var seen := []
		for sid in c["learned"]:
			if not sid is String or not p.library.has(sid) or seen.has(sid):
				return null
			seen.append(sid)
		seen.clear()
		for kind in ["招式", "内功", "轻功"]:
			var slots: Array = c["active"] if kind == "招式" else [c.get("inner" if kind == "内功" else "lightfoot")]
			for sid in slots:
				if not sid is String:
					return null
				if sid != "":
					if not p.can_equip(id, sid) or category(sid) != kind or seen.has(sid):
						return null
					seen.append(sid)
	return p
