class_name Terrain
extends RefCounted
## Static terrain table. cost = movement points to enter, eva = evasion bonus for a unit standing on it.

const DATA := {
	"grass": {"name": "草地", "cost": 1, "eva": 0, "pass": true},
	"forest": {"name": "树林", "cost": 2, "eva": 15, "pass": true},
	"water": {"name": "浅水", "cost": 2, "eva": -10, "pass": true},
	"stone": {"name": "石板", "cost": 1, "eva": 0, "pass": true},
	"ruins": {"name": "废墟", "cost": 2, "eva": 10, "pass": true},
	"snow": {"name": "积雪", "cost": 2, "eva": 0, "pass": true},
	"bridge": {"name": "木桥", "cost": 1, "eva": 0, "pass": true},
	"wall": {"name": "高墙", "cost": 99, "eva": 0, "pass": false},
}

const CODES := {
	"g": "grass", "f": "forest", "w": "water", "s": "stone",
	"r": "ruins", "n": "snow", "b": "bridge", "x": "wall",
}

const EFFECT_NAMES := {"fire": "燃烧", "ice": "冰冻"}
const FIRE_TURNS := 8
const ICE_TURNS := 10


static func info(t: String) -> Dictionary:
	return DATA.get(t, DATA["grass"])
