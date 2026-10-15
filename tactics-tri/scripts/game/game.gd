extends Node
## Autoload "Game": story flow, shared theme, safe-area helper and the --shot screenshot mode.

const SCENES := {
	"title": "res://scenes/title.tscn",
	"dialogue": "res://scenes/dialogue.tscn",
	"battle": "res://scenes/battle.tscn",
	"vote": "res://scenes/vote.tscn",
	"ending": "res://scenes/ending.tscn",
	"explore": "res://scenes/explore.tscn",
}

const FLOW := [
	{"type": "dialogue", "id": "prologue"},
	{"type": "dialogue", "id": "scout"},
	{"type": "battle", "id": "b1"},
	{"type": "dialogue", "id": "aftermath"},
	{"type": "vote"},
	{"type": "dialogue", "id": "pre2"},
	{"type": "battle", "id": "b2"},
	{"type": "ending"},
]

var step := -1
var leader_values := {"ren": 1, "zhi": 1, "yong": 1}
var vote_result := ""
var current_dialogue := "prologue"
var current_battle := "b1"
var theme: Theme
var shot := ""
var shot_out := ""
var shot_frames := 45
var autoplay := ""  # --autoplay=<battle id>: AI plays both sides through the real battle scene, then quits
var sim := ""  # --sim=<battle id>: headless both-sides AI batch, prints win-rate then quits
var sim_seeds := 20
var sim_out := ""
var chapter := ChapterState.new()
var chapter_loaded := false
var exploration_battle: Dictionary = {}
var explore_notice := ""


func _ready() -> void:
	theme = _build_theme()
	get_tree().root.theme = theme
	_configure_exploration_inputs()
	_parse_args()
	if shot != "":
		_do_shot.call_deferred()
	elif sim != "":
		_run_sim.call_deferred()
	elif autoplay != "":
		current_battle = autoplay
		_change.call_deferred("battle")


# ------------------------------------------------------------------ flow

func new_game() -> void:
	exploration_battle.clear()
	step = -1
	leader_values = {"ren": 1, "zhi": 1, "yong": 1}
	vote_result = ""
	advance()


func start_battle_demo() -> void:
	exploration_battle.clear()
	leader_values = {"ren": 1, "zhi": 1, "yong": 1}
	current_battle = "wuxia_b1"
	_change("battle")


func advance() -> void:
	step += 1
	if step >= FLOW.size():
		goto_title()
		return
	var s: Dictionary = FLOW[step]
	match s["type"]:
		"dialogue":
			current_dialogue = _resolve(s["id"])
			_change("dialogue")
		"battle":
			current_battle = _resolve(s["id"])
			_change("battle")
		"vote":
			_change("vote")
		"ending":
			_change("ending")


func retry_battle() -> void:
	_change("battle")


func goto_title() -> void:
	step = -1
	exploration_battle.clear()
	_change("title")


func start_exploration() -> void:
	exploration_battle.clear()
	if not chapter_loaded:
		var saved := ChapterState.load_from_file()
		chapter = saved if saved != null else ChapterState.new()
		chapter_loaded = true
	chapter.player_position = ExplorationRules.valid_spawn(chapter.scene_id, chapter.player_position)
	_change("explore")


func save_chapter() -> bool:
	# Screenshot fixtures never overwrite the player's real save.
	if shot in ["explore", "inn", "library", "party"]:
		return true
	return chapter.save_to_file() == OK


func commit_chapter_event(event_id: String, context: Dictionary = {}) -> bool:
	var before := chapter.to_dict()
	if not chapter.apply_event(event_id, context):
		return false
	if not save_chapter():
		chapter = ChapterState.from_dict(before)
		return false
	return true


func begin_ferry_battle(entry_position: Vector2) -> bool:
	return _begin_exploration_battle("ferry_battle_start", "wuxia_b1", entry_position)


func begin_bamboo_battle(entry_position: Vector2) -> bool:
	return _begin_exploration_battle("bamboo_battle_start", "wuxia_b2", entry_position)


func begin_shrine_battle(entry_position: Vector2) -> bool:
	return _begin_exploration_battle("shrine_battle_start", "wuxia_b3", entry_position)


func _begin_exploration_battle(event_id: String, battle_id: String, entry_position: Vector2) -> bool:
	if not chapter.can_event(event_id) or not exploration_battle.is_empty():
		return false
	chapter.scene_id = "outdoor"
	chapter.player_position = ExplorationRules.valid_spawn("outdoor", entry_position)
	if not save_chapter():
		return false
	exploration_battle = {"battle_id": battle_id, "snapshot": chapter.to_dict(), "deployed": PartyState.IDS.duplicate()}
	current_battle = battle_id
	_change("battle")
	return true


func is_exploration_battle() -> bool:
	return not exploration_battle.is_empty() and current_battle == exploration_battle.get("battle_id", "")


## Only the exploration-origin result button calls this. Story FLOW is untouched.
func finish_exploration_battle(result: String) -> bool:
	if not is_exploration_battle():
		return false
	var before := chapter.to_dict()
	var battle_id: String = String(exploration_battle.get("battle_id", ""))
	chapter = ChapterState.from_dict(exploration_battle["snapshot"])
	if result == "win":
		var clear_event := "b1_clear"
		if battle_id == "wuxia_b2":
			clear_event = "b2_clear"
		elif battle_id == "wuxia_b3":
			clear_event = "b3_clear"
		if not chapter.apply_event(clear_event, {"result": "win", "deployed": exploration_battle.get("deployed", PartyState.IDS)}):
			chapter = ChapterState.from_dict(before)
			return false
		if battle_id == "wuxia_b2":
			chapter.player_position = ExplorationRules.center(Vector2i(16, 8))
		elif battle_id == "wuxia_b3":
			chapter.player_position = ExplorationRules.center(Vector2i(37, 10))
		else:
			chapter.player_position = ExplorationRules.center(Vector2i(37, 22))
	if not save_chapter():
		chapter = ChapterState.from_dict(before)
		return false
	if result == "win":
		if battle_id == "wuxia_b2":
			explore_notice = "竹林首通 · 队伍收录《截脉指》 · 出战成员各得 80 EXP\n可回客栈谱库复习指法；废祠不要求先完成竹林。"
		elif battle_id == "wuxia_b3":
			explore_notice = "废祠首通 · 渡簿入手 · 出战成员各得 140 EXP\n不重复发放《回锋剑谱》。青崖渡调查到此结束。"
		else:
			explore_notice = "首胜 · 队伍收录《回锋剑谱》 · 出战成员各得 100 EXP\n可回听雨客栈：谱库学习装配、Esc 分配训练点、演武区领心得。"
	else:
		if battle_id == "wuxia_b2":
			explore_notice = "已退回战前入口，可再次调查。"
		elif battle_id == "wuxia_b3":
			explore_notice = "已退回废祠门口，可再次调查。"
		else:
			explore_notice = "已退回战前入口，可再次调查渡口。"
	exploration_battle.clear()
	_change("explore")
	return true


func _configure_exploration_inputs() -> void:
	var bindings := {
		"explore_left": [KEY_A, KEY_LEFT], "explore_right": [KEY_D, KEY_RIGHT],
		"explore_up": [KEY_W, KEY_UP], "explore_down": [KEY_S, KEY_DOWN],
		"explore_interact": [KEY_E, KEY_ENTER], "explore_journal": [KEY_TAB],
	}
	for action in bindings:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
			for key in bindings[action]:
				var event := InputEventKey.new()
				event.physical_keycode = key
				InputMap.action_add_event(action, event)


func add_conviction(virtue: String, amount := 2) -> void:
	leader_values[virtue] = int(leader_values.get(virtue, 0)) + amount


func route() -> String:
	return vote_result if vote_result != "" else "A"


func _resolve(id: String) -> String:
	if id == "pre2":
		return "pre_2" + route()
	if id == "b2":
		return "b2" + route()
	return id


func _change(key: String) -> void:
	get_tree().change_scene_to_file(SCENES[key])


# ------------------------------------------------------------------ safe area

## Margins (left, top, right, bottom) in viewport units that keep UI clear of notches/cutouts.
func safe_margins(vp: Viewport) -> Dictionary:
	var m := {"left": 24.0, "top": 16.0, "right": 24.0, "bottom": 16.0}
	if DisplayServer.get_name() == "headless":
		return m
	var win := DisplayServer.window_get_size()
	var safe := DisplayServer.get_display_safe_area()
	if win.x <= 0 or win.y <= 0 or safe.size.x <= 0 or safe.size.y <= 0:
		return m
	var screen := DisplayServer.screen_get_size()
	if screen != win:
		return m
	var vis := vp.get_visible_rect().size
	var sx := vis.x / float(win.x)
	var sy := vis.y / float(win.y)
	m["left"] = clampf(safe.position.x * sx, 24.0, vis.x * 0.15)
	m["top"] = clampf(safe.position.y * sy, 16.0, vis.y * 0.15)
	m["right"] = clampf((win.x - safe.end.x) * sx, 24.0, vis.x * 0.15)
	m["bottom"] = clampf((win.y - safe.end.y) * sy, 16.0, vis.y * 0.15)
	return m


func apply_safe_area(c: Control) -> void:
	var m := safe_margins(c.get_viewport())
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.offset_left = m["left"]
	c.offset_top = m["top"]
	c.offset_right = -m["right"]
	c.offset_bottom = -m["bottom"]


# ------------------------------------------------------------------ theme

func _build_theme() -> Theme:
	var t := Theme.new()
	var f = load("res://fonts/DroidSansFallbackFull.ttf")
	if f is Font:
		t.default_font = f
	t.default_font_size = 30
	t.set_stylebox("normal", "Button", _sbt("res://assets/ui/btn_normal.png"))
	t.set_stylebox("hover", "Button", _sbt("res://assets/ui/btn_hover.png"))
	t.set_stylebox("pressed", "Button", _sbt("res://assets/ui/btn_pressed.png"))
	t.set_stylebox("hover_pressed", "Button", _sbt("res://assets/ui/btn_pressed.png"))
	t.set_stylebox("disabled", "Button", _sbt("res://assets/ui/btn_disabled.png"))
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	t.set_font_size("font_size", "Button", 34)
	t.set_color("font_color", "Button", Color(1.0, 0.96, 0.86))
	t.set_color("font_hover_color", "Button", Color(1.0, 1.0, 0.92))
	t.set_color("font_pressed_color", "Button", Color(1.0, 0.86, 0.5))
	t.set_color("font_hover_pressed_color", "Button", Color(1.0, 0.86, 0.5))
	t.set_color("font_focus_color", "Button", Color(1.0, 0.96, 0.86))
	t.set_color("font_disabled_color", "Button", Color(0.62, 0.62, 0.64))
	var panel := _sbt("res://assets/ui/panel.png", 14.0, 22.0)
	t.set_stylebox("panel", "PanelContainer", panel)
	t.set_stylebox("panel", "Panel", panel)
	t.set_font_size("font_size", "Label", 30)
	t.set_color("font_color", "Label", Color(0.96, 0.94, 0.88))
	t.set_font_size("normal_font_size", "RichTextLabel", 30)
	t.set_font_size("bold_font_size", "RichTextLabel", 30)
	t.set_color("default_color", "RichTextLabel", Color(0.96, 0.94, 0.88))
	t.set_constant("separation", "VBoxContainer", 14)
	t.set_constant("separation", "HBoxContainer", 14)
	return t


func _sbt(path: String, margin := 16.0, content := 20.0) -> StyleBox:
	var tex = load(path)
	if not (tex is Texture2D):
		var flat := StyleBoxFlat.new()
		flat.bg_color = Color(0.2, 0.24, 0.36)
		return flat
	var sb := StyleBoxTexture.new()
	sb.texture = tex
	sb.texture_margin_left = margin
	sb.texture_margin_top = margin
	sb.texture_margin_right = margin
	sb.texture_margin_bottom = margin
	sb.content_margin_left = content
	sb.content_margin_right = content
	sb.content_margin_top = content * 0.6
	sb.content_margin_bottom = content * 0.6
	return sb


# ------------------------------------------------------------------ screenshot mode

func _parse_args() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shot="):
			shot = a.substr(7)
		elif a.begins_with("--out="):
			shot_out = a.substr(6)
		elif a.begins_with("--frames="):
			shot_frames = maxi(5, a.substr(9).to_int())
		elif a.begins_with("--autoplay="):
			autoplay = a.substr(11)
		elif a.begins_with("--sim="):
			sim = a.substr(6)
		elif a.begins_with("--seeds="):
			sim_seeds = maxi(1, a.substr(8).to_int())
		elif a.begins_with("--sim-out="):
			sim_out = a.substr(10)


func _do_shot() -> void:
	match shot:
		"explore", "explore_wide", "explore_ferry", "explore_shrine", "explore_bamboo", "inn", "library", "party":
			chapter = ChapterState.new()
			chapter_loaded = true
			chapter.scene_id = "inn" if shot in ["inn", "library", "party"] else "outdoor"
			var shot_cell := Vector2i(8, 23)
			if shot in ["inn", "library", "party"]:
				shot_cell = Vector2i(6, 8)
			elif shot == "explore_ferry":
				shot_cell = Vector2i(37, 22)
			elif shot == "explore_shrine":
				shot_cell = Vector2i(34, 12)
			elif shot == "explore_bamboo":
				shot_cell = Vector2i(16, 12)
			elif shot == "explore_wide":
				shot_cell = Vector2i(24, 15)
			chapter.player_position = ExplorationRules.center(shot_cell)
			if shot in ["library", "party"]:
				chapter.apply_event("quest_start")
				chapter.apply_event("b1_clear", {"result": "win"})
				chapter.apply_event("reversal_lesson")
				chapter.party.learn("sword", "回锋剑")
				if shot == "library":
					chapter.party.refine("sword", "破风剑", "延锋")
				if shot == "party":
					chapter.party.gain_exp("sword", 420)
					chapter.party.train("sword", "凝神")
					chapter.party.set_mastery("sword", "回旋")
			_change("explore")
		"title":
			_change("title")
		"dialogue":
			current_dialogue = "prologue"
			_change("dialogue")
		"vote":
			step = 4
			_change("vote")
		"battle", "battlemain", "battlefx", "wuxia", "wuxia_b1", "wuxia_b2", "wuxia_b3":
			step = 2
			if shot == "wuxia_b2":
				current_battle = "wuxia_b2"
			elif shot == "wuxia_b3":
				current_battle = "wuxia_b3"
			elif shot in ["wuxia", "wuxia_b1"]:
				current_battle = "wuxia_b1"
			else:
				current_battle = "b1"
			_change("battle")
		"battle2a", "battle2b":
			step = 6
			current_battle = "b2A" if shot == "battle2a" else "b2B"
			_change("battle")
		"ending":
			vote_result = "B"
			_change("ending")
		_:
			push_error("unknown --shot value: " + shot)
	for i in shot_frames:
		await get_tree().process_frame
	var img := get_viewport().get_texture().get_image()
	var path := shot_out if shot_out != "" else "shots/%s.png" % shot
	if not path.is_absolute_path():
		path = ProjectSettings.globalize_path("res://").path_join(path)
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var err := img.save_png(path)
	print("SHOT %s saved to %s (%dx%d) err=%d" % [shot, path, img.get_width(), img.get_height(), err])
	get_tree().quit(0 if err == OK else 1)


func _run_sim() -> void:
	var seeds: Array = []
	for i in sim_seeds:
		seeds.append(i + 1)
	var stats := BattleSim.batch(sim, seeds)
	print(BattleSim.format_summary(stats))
	if sim_out != "":
		var path := sim_out if sim_out.is_absolute_path() else ProjectSettings.globalize_path("res://").path_join(sim_out)
		DirAccess.make_dir_recursive_absolute(path.get_base_dir())
		var f := FileAccess.open(path, FileAccess.WRITE)
		if f:
			f.store_string(JSON.stringify(stats, "\t"))
			print("SIM wrote %s" % path)
	get_tree().quit(0 if int(stats["timeouts"]) == 0 else 1)
