class_name BattleUnit
extends RefCounted

const DIRS := BattleMap.DIRS
const DIR_NAMES := ["北", "东北", "东", "东南", "南", "西南", "西", "西北"]
const PLAYER := 0
const ENEMY := 1

var id := 0
var key := ""
var name := ""
var title := ""
var cls := "swordsman"
var team := PLAYER
var max_hp := 1
var hp := 1
var atk := 0
var def := 0
var mag := 0
var res := 0
var spd := 1
var mov := 1
var jump := 1
var eva := 0
var tp := 1
var max_tp := 5
var use_gdd_rules := false
var level := 1
var innate_trait := ""
var mastery := ""
var skill_branches: Dictionary = {}
var moved_tiles := 0
var youfeng_used := false
var shouxian_used := false
var tongmai_pending := false
var tongmai_triggered := false
var ningfeng_used := false # mastery 凝锋: first single pierce+1 this action
var huixuan_used := false # mastery 回旋: first retreat leave this action
var jieliu_used := false # mastery 截流 once per round
var chenwen_armor := false # mastery 沉稳 pending armor
var huoluo_pending := false # mastery 活络 next-turn qi
var cangfeng_hits := 0 # 藏锋: next incoming active hit -5%
var move_tax := 0 # 拒敌: extra AP on first move tile
var ap := 6
var max_ap := 6
var qi := 12
var max_qi := 12
var rp := 1
var acc := 0
var block := false
var used_skills: Dictionary = {}
var ap_penalty := 0
var qi_blocked := false  # active during the one action that consumed ap_penalty
var active_skills: Array = []  # three equipped active slots; basic commands are separate
var inner := ""
var lightfoot := ""
var weapon := ""
var pos := Vector2i.ZERO
var facing := 4
var basic := "slash"
var skills: Array = []
var is_leader := false
var is_lord := false
var guard := false
var bonus_move := 0
var flying := false  # only flying units may cross deep water / rivers
var ai := "aggressive"


static func create(p_id: int, p_name: String, p_cls: String, p_team: int, p_pos: Vector2i, p_facing := 4, bonus := {}) -> BattleUnit:
	var u := BattleUnit.new()
	var c: Dictionary = UnitClasses.get_class_data(p_cls)
	u.id = p_id
	u.name = p_name
	u.cls = p_cls
	u.team = p_team
	u.pos = p_pos
	u.facing = p_facing
	u.max_hp = int(c["hp"]) + int(bonus.get("hp", 0))
	u.hp = u.max_hp
	u.atk = int(c["atk"]) + int(bonus.get("atk", 0))
	u.def = int(c["def"]) + int(bonus.get("def", 0))
	u.mag = int(c["mag"]) + int(bonus.get("mag", 0))
	u.res = int(c["res"]) + int(bonus.get("res", 0))
	u.spd = int(c["spd"]) + int(bonus.get("spd", 0))
	u.mov = int(c["mov"]) + int(bonus.get("mov", 0))
	u.jump = int(c["jump"]) + int(bonus.get("jump", 0))
	u.eva = int(c["eva"]) + int(bonus.get("eva", 0))
	u.basic = c["basic"]
	u.skills = (c["skills"] as Array).duplicate()
	u.flying = bool(c.get("flying", false))
	return u


func alive() -> bool:
	return hp > 0


func gain_tp(n: int) -> void:
	tp = clampi(tp + n, 0, max_tp)


func take_damage(n: int) -> int:
	var dealt := mini(hp, maxi(0, n))
	hp -= dealt
	return dealt


func heal(n: int) -> int:
	var amount := mini(max_hp - hp, maxi(0, n))
	hp += amount
	return amount


func class_label() -> String:
	return UnitClasses.class_name_of(cls)


func all_actions() -> Array:
	return [basic] + skills


func skill(sid: String) -> Dictionary:
	return SkillDB.resolve(sid, String(skill_branches.get(sid, "")))



func gain_guard() -> void:
	guard = true
	block = false


func gain_block() -> void:
	block = true
	guard = false
