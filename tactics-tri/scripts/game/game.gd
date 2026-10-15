extends Node
## Autoload "Game": story flow, shared theme, safe-area helper and the --shot screenshot mode.

const SCENES := {
	"title": "res://scenes/title.tscn",
	"dialogue": "res://scenes/dialogue.tscn",
	"battle": "res://scenes/battle.tscn",
	"vote": "res://scenes/vote.tscn",
	"ending": "res://scenes/ending.tscn",
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


func _ready() -> void:
	theme = _build_theme()
	get_tree().root.theme = theme
	_parse_args()
	if shot != "":
		_do_shot.call_deferred()
	elif autoplay != "":
		current_battle = autoplay
		_change.call_deferred("battle")


# ------------------------------------------------------------------ flow

func new_game() -> void:
	step = -1
	leader_values = {"ren": 1, "zhi": 1, "yong": 1}
	vote_result = ""
	advance()


func start_battle_demo() -> void:
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
	_change("title")


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
	var panel := _sbt("res://assets/ui/panel.png", 24.0, 22.0)
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


func _sbt(path: String, margin := 24.0, content := 20.0) -> StyleBox:
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


func _do_shot() -> void:
	match shot:
		"title":
			_change("title")
		"dialogue":
			current_dialogue = "prologue"
			_change("dialogue")
		"vote":
			step = 4
			_change("vote")
		"battle", "battlemain", "battlefx", "wuxia", "wuxia_b1":
			step = 2
			current_battle = "wuxia_b1"
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
