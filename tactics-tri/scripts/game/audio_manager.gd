extends Node
## Autoload "AudioManager": SFX/BGM buses, one-shot SFX pool, single BGM + ambience players.
## Placeholder clips live under res://audio/; swap files in place without code changes.
## BGM/ambience never stack: play_* is idempotent and resume restarts the same players only.

const SFX_DIR := "res://audio/sfx/"
const BGM_DIR := "res://audio/bgm/"

const SFX_IDS := [
	"ui_tap", "ui_confirm", "ui_cancel", "unit_select",
	"move_step_grass", "move_step_stone", "move_step_water",
	"atk_sword", "atk_bow", "atk_shield",
	"hit_flesh", "hit_block", "crit", "heal", "skill_cast", "unit_down",
	"turn_start_ally", "turn_start_enemy", "victory", "defeat", "amb_night_wind",
]

const BGM_IDS := ["bgm_battle_loop"]

const BUS_MASTER := "Master"
const BUS_BGM := "BGM"
const BUS_SFX := "SFX"

var _streams := {}
var _sfx_pool: Array = []
var _sfx_i := 0
var _bgm: AudioStreamPlayer
var _amb: AudioStreamPlayer
var _bgm_id := ""
var _amb_id := ""
var _bgm_wanted := false
var _amb_wanted := false
var _inited := false


func _ready() -> void:
	_ensure_init()


## Safe to call from headless tests before the node receives NOTIFICATION_READY.
func _ensure_init() -> void:
	if _inited:
		return
	_inited = true
	_ensure_buses()
	_load_streams()
	_bgm = _make_player(BUS_BGM)
	_amb = _make_player(BUS_SFX)
	_amb.volume_db = -8.0
	for i in 8:
		_sfx_pool.append(_make_player(BUS_SFX))
	process_mode = Node.PROCESS_MODE_ALWAYS


func _notification(what: int) -> void:
	# Pause/resume must not spawn extra BGM players; only restart the singleton streams.
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		pass
	elif what == NOTIFICATION_APPLICATION_RESUMED or what == NOTIFICATION_WM_WINDOW_FOCUS_IN:
		_ensure_init()
		_resync_looping()


func _ensure_buses() -> void:
	_add_bus(BUS_BGM)
	_add_bus(BUS_SFX)
	var bgm_i := AudioServer.get_bus_index(BUS_BGM)
	var sfx_i := AudioServer.get_bus_index(BUS_SFX)
	if bgm_i >= 0:
		AudioServer.set_bus_send(bgm_i, BUS_MASTER)
		AudioServer.set_bus_volume_db(bgm_i, -4.0)
	if sfx_i >= 0:
		AudioServer.set_bus_send(sfx_i, BUS_MASTER)


func _add_bus(name: String) -> void:
	if AudioServer.get_bus_index(name) >= 0:
		return
	var idx := AudioServer.bus_count
	AudioServer.add_bus(idx)
	AudioServer.set_bus_name(idx, name)


func _make_player(bus: String) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.bus = bus
	add_child(p)
	return p


func _load_streams() -> void:
	for id in SFX_IDS:
		var path: String = SFX_DIR + id + ".ogg"
		if ResourceLoader.exists(path):
			_streams[id] = load(path)
	for id in BGM_IDS:
		var path: String = BGM_DIR + id + ".ogg"
		if ResourceLoader.exists(path):
			var st: AudioStream = load(path)
			if st is AudioStreamOggVorbis:
				(st as AudioStreamOggVorbis).loop = true
			_streams[id] = st
	# Ambience loops
	if _streams.has("amb_night_wind") and _streams["amb_night_wind"] is AudioStreamOggVorbis:
		(_streams["amb_night_wind"] as AudioStreamOggVorbis).loop = true


func has_clip(id: String) -> bool:
	_ensure_init()
	return _streams.has(id)


func play_sfx(id: String, pitch_scale := 1.0, volume_db := 0.0) -> void:
	_ensure_init()
	if not _streams.has(id):
		return
	var p: AudioStreamPlayer = _sfx_pool[_sfx_i]
	_sfx_i = (_sfx_i + 1) % _sfx_pool.size()
	p.stop()
	p.stream = _streams[id]
	p.pitch_scale = pitch_scale
	p.volume_db = volume_db
	p.play()


func play_ui(id: String) -> void:
	play_sfx(id)


func play_bgm(id: String) -> void:
	_ensure_init()
	_bgm_wanted = true
	if not _streams.has(id):
		return
	if _bgm_id == id and _bgm.playing:
		return
	_bgm_id = id
	if _bgm.playing:
		_bgm.stop()
	_bgm.stream = _streams[id]
	_bgm.play()


func stop_bgm() -> void:
	_ensure_init()
	_bgm_wanted = false
	_bgm_id = ""
	if _bgm.playing:
		_bgm.stop()


func play_ambience(id: String = "amb_night_wind") -> void:
	_ensure_init()
	_amb_wanted = true
	if not _streams.has(id):
		return
	if _amb_id == id and _amb.playing:
		return
	_amb_id = id
	if _amb.playing:
		_amb.stop()
	_amb.stream = _streams[id]
	_amb.play()


func stop_ambience() -> void:
	_ensure_init()
	_amb_wanted = false
	_amb_id = ""
	if _amb.playing:
		_amb.stop()


func stop_battle_audio() -> void:
	stop_bgm()
	stop_ambience()


func _resync_looping() -> void:
	_ensure_init()
	if _bgm_wanted and _bgm_id != "" and _streams.has(_bgm_id):
		if not _bgm.playing:
			if _bgm.stream != _streams[_bgm_id]:
				_bgm.stream = _streams[_bgm_id]
			_bgm.play()
	if _amb_wanted and _amb_id != "" and _streams.has(_amb_id):
		if not _amb.playing:
			if _amb.stream != _streams[_amb_id]:
				_amb.stream = _streams[_amb_id]
			_amb.play()


func step_for_terrain(terrain: String) -> void:
	match terrain:
		"stone", "ruins", "bridge":
			play_sfx("move_step_stone", randf_range(0.95, 1.05))
		"ford", "water":
			play_sfx("move_step_water", randf_range(0.95, 1.05))
		_:
			play_sfx("move_step_grass", randf_range(0.92, 1.08))


func attack_for_skill(sid: String) -> void:
	match sid:
		"shoot", "aimed_shot", "arrow_rain":
			play_sfx("atk_bow")
		"guard":
			play_sfx("atk_shield")
		"bolt", "flame", "frost", "heal", "mass_heal", "dash":
			play_sfx("skill_cast")
		_:
			play_sfx("atk_sword")
