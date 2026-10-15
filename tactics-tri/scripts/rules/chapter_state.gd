class_name ChapterState
extends RefCounted
## Chapter-one progress. No nodes, battle actors or scene dependencies.

enum QuestState { S0_ARRIVED, S1_TO_FERRY, S2_AFTER_B1, S3_ROUTE_SET, S4_FINAL, S5_COMPLETE }

const SAVE_PATH := "user://ch01_save.json"
const QUEST_TEXT := [
	"到听雨客栈询问失踪封箱", "前往青崖渡口核查货物",
	"返回客栈整理剑谱，听取两派解释", "前往废祠追查渡簿；竹林为可选线索",
	"取回渡簿，查出伪造名单的线索", "青崖渡调查结束",
]

var quest_accepted := false
var b1_clear := false
var lesson_received := false
var stance := ""
var unlocked_manuals: Array[String] = []
var experience := 0
var insights := 0
var escort_relation := 0
var sect_relation := 0
# Reserved progress for the later B2/B3 slice; no premature chapter completion.
var b2_clear := false
var b3_clear := false
var ledger_received := false
var complete := false
var scene_id := "outdoor"
var player_position := Vector2(408, 1128)
var outdoor_return := Vector2(408, 1080)
var facing := "S"
var visited_areas: Array[String] = []

var quest_state: QuestState:
	get:
		if complete:
			return QuestState.S5_COMPLETE
		if b3_clear and ledger_received:
			return QuestState.S4_FINAL
		if stance != "":
			return QuestState.S3_ROUTE_SET
		if b1_clear:
			return QuestState.S2_AFTER_B1
		return QuestState.S1_TO_FERRY if quest_accepted else QuestState.S0_ARRIVED


func objective() -> String:
	return QUEST_TEXT[quest_state]


func can_event(event_id: String, context: Dictionary = {}) -> bool:
	match event_id:
		"quest_start":
			return not quest_accepted
		"ferry_battle_start":
			return quest_accepted and not b1_clear
		"b1_clear":
			return quest_accepted and not b1_clear and context.get("result", "") == "win"
		"reversal_lesson":
			return b1_clear and not lesson_received
		"choose_escort", "choose_sect":
			return b1_clear and stance == ""
		"bamboo_battle_start":
			return b1_clear and stance != "" and not b2_clear
		"shrine_battle_start":
			return b1_clear and stance != "" and not b3_clear
	return false


## Returns false without changing anything when a condition fails.
func apply_event(event_id: String, context: Dictionary = {}) -> bool:
	if not can_event(event_id, context):
		return false
	match event_id:
		"quest_start":
			quest_accepted = true
		"b1_clear":
			b1_clear = true
			if not unlocked_manuals.has("回锋剑谱"):
				unlocked_manuals.append("回锋剑谱")
			experience += 100
		"reversal_lesson":
			lesson_received = true
			insights += 1
		"choose_escort":
			stance = "escort"
			escort_relation += 1
		"choose_sect":
			stance = "sect"
			sect_relation += 1
	# Battle-start events deliberately grant and change nothing.
	return true


func to_dict() -> Dictionary:
	return {
		"version": 1, "quest_accepted": quest_accepted, "b1_clear": b1_clear,
		"lesson_received": lesson_received, "stance": stance,
		"unlocked_manuals": unlocked_manuals.duplicate(), "experience": experience,
		"insights": insights, "escort_relation": escort_relation, "sect_relation": sect_relation,
		"b2_clear": b2_clear, "b3_clear": b3_clear, "ledger_received": ledger_received,
		"complete": complete, "scene_id": scene_id,
		"player_position": [player_position.x, player_position.y],
		"outdoor_return": [outdoor_return.x, outdoor_return.y],
		"facing": facing, "visited_areas": visited_areas.duplicate(),
	}


static func from_dict(data: Dictionary) -> ChapterState:
	if data.get("version", 0) != 1:
		return null
	var s := ChapterState.new()
	for key in ["quest_accepted", "b1_clear", "lesson_received", "b2_clear", "b3_clear", "ledger_received", "complete"]:
		if not data.get(key) is bool:
			return null
		s.set(key, data[key])
	if not data.get("stance") in ["", "escort", "sect"] or not data.get("scene_id") in ["outdoor", "inn"]:
		return null
	s.stance = data["stance"]
	s.scene_id = data["scene_id"]
	if not data.get("facing") in ["S", "SW", "W", "NW", "N", "NE", "E", "SE"]:
		return null
	s.facing = data["facing"]
	for key in ["experience", "insights", "escort_relation", "sect_relation"]:
		var value = data.get(key)
		if not (value is int or value is float) or not is_finite(float(value)) or value < 0 or value != int(value):
			return null
		s.set(key, int(value))
	for key in ["player_position", "outdoor_return"]:
		var value = data.get(key)
		if not value is Array or value.size() != 2:
			return null
		for axis in value:
			if not (axis is int or axis is float) or not is_finite(float(axis)):
				return null
		s.set(key, Vector2(value[0], value[1]))
	for key in ["unlocked_manuals", "visited_areas"]:
		if not data.get(key) is Array:
			return null
		for value in data[key]:
			if not value is String:
				return null
			if not s.get(key).has(value):
				s.get(key).append(value)
	if s.b1_clear and (not s.quest_accepted or not s.unlocked_manuals.has("回锋剑谱") or s.experience < 100):
		return null
	if (s.lesson_received or s.stance != "" or s.b2_clear or s.b3_clear) and not s.b1_clear:
		return null
	if s.lesson_received and s.insights < 1:
		return null
	if s.complete and not (s.b3_clear and s.ledger_received):
		return null
	return s


## Write flags and rewards together; a failed write leaves the previous file intact.
func save_to_file(path := SAVE_PATH) -> Error:
	var tmp := path + ".tmp"
	var file := FileAccess.open(tmp, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(to_dict(), "\t"))
	file.flush()
	var err := file.get_error()
	file.close()
	if err != OK:
		return err
	return DirAccess.rename_absolute(ProjectSettings.globalize_path(tmp), ProjectSettings.globalize_path(path))


static func load_from_file(path := SAVE_PATH) -> ChapterState:
	if not FileAccess.file_exists(path):
		return null
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return null
	var data = JSON.parse_string(file.get_as_text())
	return from_dict(data) if data is Dictionary else null
