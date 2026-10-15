class_name SkillDB
extends RefCounted
## Basic attacks (tp 0) and skills.
## kind: phys / mag / heal / self. shape: single / line2 / line3 / area1 (center + 4 neighbors) / self.
## height_range: ranged attack that gains +1 range per 2 height above the target.

const DEFAULTS := {
	"tp": 0, "kind": "phys", "power": 1.0, "rmin": 1, "rmax": 1, "shape": "single",
	"effect": "", "hit_bonus": 0, "height_range": false, "desc": "",
}

const SKILLS := {
	"slash": {"name": "斩击", "desc": "以剑攻击相邻敌人。"},
	"heavy_slash": {"name": "破军斩", "tp": 2, "power": 1.6, "desc": "全力劈砍，造成1.6倍伤害。"},
	"guard": {"name": "不动架势", "tp": 1, "kind": "self", "shape": "self", "rmin": 0, "rmax": 0, "effect": "guard",
		"desc": "直到下次行动前，所受伤害减半。"},
	"thrust": {"name": "突刺", "shape": "line2", "desc": "长枪贯穿前方直线两格的敌人。"},
	"pierce": {"name": "穿云枪", "tp": 2, "power": 1.3, "shape": "line3", "desc": "贯穿前方直线三格，1.3倍伤害。"},
	"knockback": {"name": "震退", "tp": 2, "power": 1.0, "effect": "knockback",
		"desc": "将敌人击退一格；撞到障碍追加伤害，坠落造成摔伤。"},
	"shoot": {"name": "射击", "rmin": 2, "rmax": 4, "height_range": true, "desc": "远程射击。居高临下时射程增加。"},
	"aimed_shot": {"name": "鹰眼射", "tp": 2, "power": 1.4, "rmin": 2, "rmax": 4, "height_range": true, "hit_bonus": 20,
		"desc": "瞄准要害，1.4倍伤害且命中提升。"},
	"arrow_rain": {"name": "箭雨", "tp": 3, "power": 0.8, "rmin": 2, "rmax": 5, "shape": "area1", "height_range": true,
		"desc": "向十字范围倾泻箭矢。"},
	"bolt": {"name": "魔弹", "kind": "mag", "power": 0.8, "rmin": 1, "rmax": 3, "desc": "发射魔力弹，必定命中。"},
	"flame": {"name": "烈焰", "tp": 3, "kind": "mag", "power": 1.1, "rmin": 1, "rmax": 4, "shape": "area1", "effect": "fire",
		"desc": "十字范围火焰魔法，并使地面燃烧（站在上面的单位回合开始时受伤）。"},
	"frost": {"name": "寒霜", "tp": 2, "kind": "mag", "power": 0.9, "rmin": 1, "rmax": 4, "shape": "area1", "effect": "ice",
		"desc": "十字范围冰霜魔法，迟缓敌人行动并冻结地面（浅滩结冰后更易通行，深水无法冻结）。"},
	"staff": {"name": "杖击", "power": 0.8, "desc": "以法杖敲击相邻敌人。"},
	"heal": {"name": "治愈", "tp": 2, "kind": "heal", "power": 1.5, "rmin": 0, "rmax": 3, "desc": "恢复一名同伴的生命。"},
	"mass_heal": {"name": "圣愈之环", "tp": 3, "kind": "heal", "power": 1.0, "rmin": 0, "rmax": 3, "shape": "area1",
		"desc": "恢复十字范围内所有同伴的生命。"},
	"stab": {"name": "短刃", "desc": "以短刃攻击相邻敌人。"},
	"steal": {"name": "窃取", "tp": 1, "power": 0.7, "effect": "steal", "desc": "攻击并偷取目标最多2点TP。"},
	"dash": {"name": "疾风步", "tp": 2, "kind": "self", "shape": "self", "rmin": 0, "rmax": 0, "effect": "dash",
		"desc": "本回合可以再次移动，且移动力+2。"},
	"axe": {"name": "裂地斧", "power": 1.1, "desc": "沉重的斧击。"},
}

static var wuxia_skills: Dictionary = {}


static func _load_wuxia() -> void:
	if not wuxia_skills.is_empty():
		return
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/wuxia/b1_combat.json"))
	for name in data["skills"]:
		var spec: Dictionary = data["skills"][name]
		var sk := DEFAULTS.duplicate()
		sk.merge(spec, true)
		sk.merge({"id": name, "name": name, "gdd": true, "rmax": int(spec.get("range", 1)), "shape": "single", "kind": "phys"}, true)
		match spec["kind"]:
			"line_aoe", "spear", "push_spear", "seal":
				sk["shape"] = "line" if spec["kind"] != "seal" else "single"
			"shield", "guard", "rest":
				sk.merge({"kind": "self", "shape": "self", "rmin": 0, "rmax": 0, "power": 0, "effect": spec["kind"]}, true)
			"leap":
				sk.merge({"kind": "self", "shape": "leap", "rmax": 3, "power": 0, "effect": "leap", "once": true}, true)
			"push":
				sk["effect"] = "wuxia_push"
			"melee_retreat":
				sk["effect"] = "retreat"
		if spec["kind"] == "push_spear":
			sk["effect"] = "wuxia_push"
		if spec["kind"] == "seal":
			sk["effect"] = "seal"
		if spec["kind"] == "rest":
			sk["once"] = true
		var descriptions := {
			"普攻": "攻击相邻敌人。", "破风剑": "沿八向直线攻击至多3格；实体障碍挡线，破甲1。",
			"回锋剑": "命中后安全后撤一格；每次行动至多后撤一次。", "穿云枪": "直线攻击至多2格，破甲1。",
			"挑枪": "直线攻击至多2格，命中后击退一格。", "震山掌": "命中后击退一格。",
			"截脉指": "命中后使目标下次行动少1AP，不叠加。", "守关式": "护势：下一次命中伤害减免25%；与格挡互斥。",
			"防御": "格挡：下一次命中时护甲+2；与护势互斥。", "调息": "恢复4点内力，每次行动限一次。",
			"燕行步": "沿合法路径移动至多3步，免离区借机；每次行动限一次。暂不跨越障碍。",
		}
		sk["desc"] = descriptions.get(name, name)
		wuxia_skills[name] = sk


static func get_skill(id: String) -> Dictionary:
	if not SKILLS.has(id):
		_load_wuxia()
		return wuxia_skills[id].duplicate(true)
	var d: Dictionary = DEFAULTS.duplicate()
	d.merge(SKILLS[id], true)
	d["id"] = id
	return d


static func has_skill(id: String) -> bool:
	_load_wuxia()
	return SKILLS.has(id) or wuxia_skills.has(id)
