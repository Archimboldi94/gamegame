class_name VoteSystem
extends RefCounted
## 信念天平: each companion leans toward option "A" or "B" according to how well the option's
## appeal matches their convictions (仁 ren / 智 zhi / 勇 yong). Exactly equal appeal = 弃权 (abstain).
## The player may persuade up to MAX_PERSUADE members once each; an argument succeeds when the
## member values the argument's virtue at least as much as their resolve (the protagonist's own
## strong conviction in that virtue adds +1). Majority wins. Tie-break: the protagonist's
## (持秤者) convictions decide; if those are also even, option A (the first option) wins.

const VIRTUES := ["ren", "zhi", "yong"]
const VIRTUE_NAMES := {"ren": "仁", "zhi": "智", "yong": "勇"}
const MAX_PERSUADE := 2
const LEADER_BONUS_AT := 3

var options: Dictionary = {}       # "A"/"B" -> {"name", "desc", "appeal": {virtue: int}}
var members: Array = []            # [{"id","name","values","resolve","vote","persuaded"}]
var leader_values: Dictionary = {"ren": 1, "zhi": 1, "yong": 1}
var persuasions_left := MAX_PERSUADE


func setup(p_options: Dictionary, p_members: Array, p_leader_values: Dictionary) -> void:
	options = p_options.duplicate(true)
	leader_values = p_leader_values.duplicate()
	members = []
	persuasions_left = MAX_PERSUADE
	for m in p_members:
		var mm: Dictionary = (m as Dictionary).duplicate(true)
		mm["persuaded"] = false
		mm["vote"] = lean(mm["values"])
		members.append(mm)


static func score(values: Dictionary, appeal: Dictionary) -> int:
	var s := 0
	for v in VIRTUES:
		s += int(values.get(v, 0)) * int(appeal.get(v, 0))
	return s


func lean(values: Dictionary) -> String:
	var a := score(values, options["A"]["appeal"])
	var b := score(values, options["B"]["appeal"])
	if a > b:
		return "A"
	if b > a:
		return "B"
	return ""


func member(id: String) -> Dictionary:
	for m in members:
		if m["id"] == id:
			return m
	return {}


func can_persuade(id: String) -> bool:
	var m := member(id)
	return persuasions_left > 0 and not m.is_empty() and not m["persuaded"]


func persuasion_score(m: Dictionary, virtue: String) -> int:
	var s: int = int(m["values"].get(virtue, 0))
	if int(leader_values.get(virtue, 0)) >= LEADER_BONUS_AT:
		s += 1
	return s


## Returns {"ok": bool, "success": bool, "msg": String}
func persuade(id: String, virtue: String, option: String) -> Dictionary:
	if not can_persuade(id):
		return {"ok": false, "success": false, "msg": "无法再说服此人。"}
	var m := member(id)
	if m["vote"] == option:
		return {"ok": false, "success": false, "msg": "%s本就支持这个选择。" % m["name"]}
	persuasions_left -= 1
	m["persuaded"] = true
	var success := persuasion_score(m, virtue) >= int(m["resolve"])
	if success:
		m["vote"] = option
		return {"ok": true, "success": true, "msg": "%s被你的话打动了，改为支持「%s」。" % [m["name"], options[option]["name"]]}
	return {"ok": true, "success": false, "msg": "%s不为所动。" % m["name"]}


func tally() -> Dictionary:
	var t := {"A": 0, "B": 0, "abstain": 0}
	for m in members:
		if m["vote"] == "A" or m["vote"] == "B":
			t[m["vote"]] += 1
		else:
			t["abstain"] += 1
	return t


## {"winner": "A"/"B", "counts": tally, "tie": bool, "tie_rule": "leader"/"default"/""}
func result() -> Dictionary:
	var t := tally()
	if t["A"] > t["B"]:
		return {"winner": "A", "counts": t, "tie": false, "tie_rule": ""}
	if t["B"] > t["A"]:
		return {"winner": "B", "counts": t, "tie": false, "tie_rule": ""}
	var l := lean(leader_values)
	if l != "":
		return {"winner": l, "counts": t, "tie": true, "tie_rule": "leader"}
	return {"winner": "A", "counts": t, "tie": true, "tie_rule": "default"}
