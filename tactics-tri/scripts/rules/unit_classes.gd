class_name UnitClasses
extends RefCounted
## Class stat blocks. Each class has a basic attack and exactly two skills.

const CLASSES := {
	"swordsman": {"name": "剑士", "hp": 72, "atk": 20, "def": 11, "mag": 4, "res": 7, "spd": 10, "mov": 4, "jump": 2, "eva": 5,
		"basic": "slash", "skills": ["heavy_slash", "guard"]},
	"lancer": {"name": "枪兵", "hp": 78, "atk": 19, "def": 13, "mag": 2, "res": 5, "spd": 8, "mov": 4, "jump": 1, "eva": 0,
		"basic": "thrust", "skills": ["pierce", "knockback"]},
	"archer": {"name": "弓手", "hp": 56, "atk": 17, "def": 7, "mag": 4, "res": 7, "spd": 11, "mov": 4, "jump": 2, "eva": 10,
		"basic": "shoot", "skills": ["aimed_shot", "arrow_rain"]},
	"mage": {"name": "法师", "hp": 50, "atk": 6, "def": 5, "mag": 20, "res": 12, "spd": 9, "mov": 3, "jump": 1, "eva": 5,
		"basic": "bolt", "skills": ["flame", "frost"]},
	"healer": {"name": "治疗师", "hp": 54, "atk": 10, "def": 6, "mag": 15, "res": 14, "spd": 9, "mov": 4, "jump": 1, "eva": 5,
		"basic": "staff", "skills": ["heal", "mass_heal"]},
	"thief": {"name": "盗贼", "hp": 54, "atk": 16, "def": 7, "mag": 5, "res": 6, "spd": 13, "mov": 5, "jump": 3, "eva": 20,
		"basic": "stab", "skills": ["steal", "dash"]},
	"warlord": {"name": "统领", "hp": 110, "atk": 22, "def": 14, "mag": 4, "res": 9, "spd": 9, "mov": 3, "jump": 2, "eva": 0,
		"basic": "axe", "skills": ["heavy_slash", "guard"]},
}

const STAT_KEYS := ["hp", "atk", "def", "mag", "res", "spd", "mov", "jump", "eva"]


static func get_class_data(cls: String) -> Dictionary:
	return CLASSES[cls]


static func class_name_of(cls: String) -> String:
	return CLASSES[cls]["name"]
