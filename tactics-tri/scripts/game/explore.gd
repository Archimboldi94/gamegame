extends Node2D
## Qingyadu / Tingyu Inn: a continuous world, separate from the tactical grid.

const Player := preload("res://scripts/game/explore_player.gd")
const Minimap := preload("res://scripts/game/explore_minimap.gd")
const PreparationPanel := preload("res://scripts/game/party_panel.gd")
const TILE := ExplorationRules.TILE

var area := "outdoor"
var rows: Array[String] = []
var objects: Array[Dictionary] = []
var player: CharacterBody2D
var camera: Camera2D
var actors: Node2D
var ui: Control
var objective_label: Label
var status_label: Label
var prompt: PanelContainer
var prompt_label: Label
var place_label: Label
var modal: Control
var modal_title: Label
var modal_text: Label
var modal_buttons: HBoxContainer
var modal_action: Callable
var nearest := ""
var font := preload("res://fonts/DroidSansFallbackFull.ttf")
var tile_tex := {}
var deco_tree: Texture2D
var deco_crate: Texture2D
var npc_actors: Array = []
var autosave_time := 0.0
var last_saved_position := Vector2.ZERO
var minimap: Node2D
var party_panel: Control


func _ready() -> void:
	area = Game.chapter.scene_id
	rows = ExplorationRules.grid(area)
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_load_explore_art()
	_build_objects()
	_build_collision()
	actors = Node2D.new()
	actors.y_sort_enabled = true
	add_child(actors)
	_build_npcs()
	player = Player.new()
	player.position = ExplorationRules.valid_spawn(area, Game.chapter.player_position)
	player.facing = Game.chapter.facing
	actors.add_child(player)
	if player.sprite:
		player.sprite.visible = false
	last_saved_position = player.position
	camera = Camera2D.new()
	# Iso diamonds are ~160×80; zoom out so a river bend fits the view.
	camera.zoom = Vector2.ONE * (0.72 if area == "inn" else 0.48)
	camera.position_smoothing_enabled = false
	add_child(camera)
	_update_camera()
	_build_ui()
	_refresh_ui()
	_update_nearest()
	if not Game.chapter.visited_areas.has(area):
		Game.chapter.visited_areas.append(area)
		place_label.text = "听雨客栈 · 一盏茶问江湖" if area == "inn" else "青崖渡 · 第一章"
		var tween := create_tween()
		tween.tween_interval(2.5)
		tween.tween_property(place_label, "modulate:a", 0.0, 1.0)
	else:
		place_label.hide()
	_save_position()
	if Game.explore_notice != "":
		_show_dialogue("渡口见闻", Game.explore_notice)
		Game.explore_notice = ""
	queue_redraw()
	if Game.shot in ["library", "party"]:
		place_label.hide()
		_show_preparation(Game.shot, "sword")


func _build_objects() -> void:
	if area == "outdoor":
		objects = [
			{"id": "inn_door", "name": "听雨客栈", "verb": "进入"},
			{"id": "ferry_event", "name": "渡口封箱", "verb": "调查"},
			{"id": "bamboo_event", "name": "竹林旧道", "verb": "调查"},
			{"id": "shrine_event", "name": "废祠", "verb": "调查"},
		]
	else:
		objects = [
			{"id": "exit", "name": "青崖渡", "verb": "离开"},
			{"id": "keeper", "name": "掌柜", "verb": "交谈", "cls": "thief"},
			{"id": "meng", "name": "孟秋白", "verb": "交谈", "cls": "lancer"},
			{"id": "luo", "name": "洛青禾", "verb": "交谈", "cls": "healer"},
			{"id": "codex", "name": "武学谱库", "verb": "调查"},
			{"id": "training", "name": "演武区", "verb": "调查"},
		]
	var points: Dictionary = ExplorationRules.OUTDOOR_POINTS if area == "outdoor" else ExplorationRules.INN_POINTS
	for obj in objects:
		obj["position"] = ExplorationRules.center(points[obj["id"]])


func _build_collision() -> void:
	var body := StaticBody2D.new()
	body.collision_layer = 1
	body.collision_mask = 2
	add_child(body)
	# Merge each horizontal run of solid design tiles into one physics rectangle.
	for y in rows.size():
		var x := 0
		while x < rows[y].length():
			if not ExplorationRules.is_blocked(rows, Vector2i(x, y)):
				x += 1
				continue
			var start := x
			while x < rows[y].length() and ExplorationRules.is_blocked(rows, Vector2i(x, y)):
				x += 1
			_add_rectangle(body, Vector2((start + x) * TILE / 2.0, (y + 0.5) * TILE), Vector2((x - start) * TILE, TILE))
	# Boundaries include the door opening; doors require explicit interaction.
	var size := Vector2(rows[0].length(), rows.size()) * TILE
	_add_rectangle(body, Vector2(size.x / 2, -24), Vector2(size.x, 48))
	_add_rectangle(body, Vector2(size.x / 2, size.y + 24), Vector2(size.x, 48))
	_add_rectangle(body, Vector2(-24, size.y / 2), Vector2(48, size.y))
	_add_rectangle(body, Vector2(size.x + 24, size.y / 2), Vector2(48, size.y))
	if area == "inn":
		for obj in objects:
			if obj["id"] == "exit":
				continue
			var shape := CollisionShape2D.new()
			var circle := CircleShape2D.new()
			circle.radius = 14
			shape.shape = circle
			shape.position = obj["position"]
			body.add_child(shape)


func _add_rectangle(body: StaticBody2D, point: Vector2, dimensions: Vector2) -> void:
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = dimensions
	shape.shape = rect
	shape.position = point
	body.add_child(shape)


func _load_explore_art() -> void:
	for art in ["grass", "grassdirt", "stone", "water", "bridge", "forest", "wall", "mud", "ruins"]:
		for i in 4:
			var path := "res://assets/tiles/top_%s_%d.png" % [art, i]
			if ResourceLoader.exists(path):
				tile_tex["%s_%d" % [art, i]] = load(path)
		var side := "res://assets/tiles/side_%s.png" % art
		if ResourceLoader.exists(side):
			tile_tex["side_%s" % art] = load(side)
		var sidetop := "res://assets/tiles/sidetop_%s.png" % art
		if ResourceLoader.exists(sidetop):
			tile_tex["sidetop_%s" % art] = load(sidetop)
	deco_tree = load("res://assets/tiles/deco_tree.png") if ResourceLoader.exists("res://assets/tiles/deco_tree.png") else null
	deco_crate = load("res://assets/tiles/deco_rubble.png") if ResourceLoader.exists("res://assets/tiles/deco_rubble.png") else null


func _build_npcs() -> void:
	npc_actors.clear()
	for obj in objects:
		if not obj.has("cls"):
			continue
		var actor := Node2D.new()
		actor.set_meta("logical", obj["position"])
		actor.position = ExploreIso.world_to_iso(obj["position"])
		actor.z_index = int(actor.position.y)
		actors.add_child(actor)
		var sprite := Sprite2D.new()
		sprite.texture = load("res://assets/units/dirs/%s_player_S.png" % obj["cls"])
		sprite.centered = false
		sprite.scale = Vector2.ONE * 0.42
		sprite.position = Vector2(-80, -196) * 0.42
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		actor.add_child(sprite)
		var name_tag := UIKit.label(obj["name"], 18, UIKit.IVORY, 3)
		name_tag.position = Vector2(-48, -92)
		name_tag.size.x = 96
		name_tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		actor.add_child(name_tag)
		npc_actors.append(actor)


func _physics_process(delta: float) -> void:
	if not is_instance_valid(player):
		return
	player.blocked = modal.visible or party_panel.visible
	_update_camera()
	_update_nearest()
	autosave_time += delta
	if autosave_time >= 3.0:
		autosave_time = 0
		if player.position.distance_to(last_saved_position) > 1:
			_save_position()


func _update_camera() -> void:
	var view := get_viewport_rect().size / camera.zoom
	var bounds := ExploreIso.iso_bounds(rows[0].length(), rows.size())
	var desired := ExploreIso.world_to_iso(player.position)
	for axis in [0, 1]:
		var half := view[axis] / 2
		if bounds.size[axis] > view[axis]:
			desired[axis] = clampf(desired[axis], bounds.position[axis] + half, bounds.end[axis] - half)
		else:
			desired[axis] = bounds.get_center()[axis]
	camera.position = desired
	for actor in npc_actors:
		if not is_instance_valid(actor):
			continue
		var logical: Vector2 = actor.get_meta("logical")
		actor.position = ExploreIso.world_to_iso(logical)
		actor.z_index = int(actor.position.y)
	queue_redraw()


func _update_nearest() -> void:
	var best := ""
	var distance := INF
	for obj in objects:
		var point: Vector2 = obj["position"]
		var d := player.position.distance_squared_to(point)
		if ExplorationRules.in_interaction_radius(player.position, point) and d < distance:
			best = obj["id"]
			distance = d
	if best != nearest:
		nearest = best
		queue_redraw()
	prompt.visible = nearest != "" and not modal.visible and not party_panel.visible
	for obj in objects:
		if obj["id"] == nearest:
			prompt_label.text = "%s   [E]%s" % [obj["name"], obj["verb"]]


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.echo:
		return
	if party_panel.visible:
		if event.is_action_pressed("ui_cancel") or event.is_action_pressed("explore_journal"):
			party_panel.close()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("explore_journal"):
		if modal.visible:
			_close_dialogue()
		else:
			_show_journal()
	elif event.is_action_pressed("ui_cancel"):
		if modal.visible:
			_close_dialogue()
		else:
			_show_pause()
	elif event.is_action_pressed("explore_interact"):
		if modal.visible:
			# Confirmations always need an explicit button / Enter, never a repeated E.
			if event is InputEventKey and event.physical_keycode == KEY_ENTER and modal_action.is_valid():
				modal_action.call()
			elif not modal_action.is_valid():
				_close_dialogue()
		else:
			interact(nearest)
	else:
		return
	get_viewport().set_input_as_handled()


## Rechecks distance even when invoked directly; UI cannot remotely enter a location.
func interact(object_id: String) -> bool:
	var target: Dictionary = {}
	for obj in objects:
		if obj["id"] == object_id:
			target = obj
	if target.is_empty() or not ExplorationRules.in_interaction_radius(player.position, target["position"]):
		return false
	match object_id:
		"inn_door":
			_transfer("inn")
		"exit":
			_transfer("outdoor")
		"keeper":
			if not Game.chapter.quest_accepted:
				_show_dialogue("掌柜 · 两份货单", "昨夜三辆镖车过渡，今早只回来了两辆。奇的是，失的那一辆，货单却有两份。\n劳烦你去渡口，查一查留下的封箱。", "接受调查", _commit_dialogue.bind("quest_start", "委托已记入任务日志。沿客栈门外河岸主路向东，到渡口调查封箱。"))
			else:
				_show_dialogue("掌柜", Game.chapter.objective() + "。\n" + ("谱库在左侧，演武区在右侧。孟秋白与洛青禾都在等你的答复。" if Game.chapter.b1_clear else "出门向东，沿河岸主路便是渡口。"))
		"ferry_event":
			if Game.chapter.b1_clear:
				_show_dialogue("渡口 · 封箱旧迹", "封箱已夺回，奖励已收录。两份货单的字迹相同，印泥却不一样。\n回客栈听听两派的解释，再去查废祠的渡簿。")
			elif not Game.chapter.can_event("ferry_battle_start"):
				_show_dialogue("渡口 · 线索不足", "渡夫守着封箱，不愿多言。先去听雨客栈找掌柜，问清失踪镖车的来历。")
			else:
				_show_dialogue("渡口截箱 · 战前确认", "有人正在转移封箱。是否上前截下？\n出战：剑客、枪客、拳师。\n胜利后回到渡口；失败返回当前入口，可重新调查。", "确认出战", _start_ferry_battle)
		"meng", "luo":
			_stance_dialogue(object_id)
		"codex":
			_show_preparation("library")
		"training":
			if not Game.chapter.b1_clear:
				_show_dialogue("演武区", "先去渡口历练。夺回封箱后，可在此整理反击的体会，领取一份武学心得。")
			elif Game.chapter.lesson_received:
				_show_dialogue("演武区", "这份回锋心得已领过。静心温习，不再重复领取。\n当前武学心得：%d" % Game.chapter.insights)
			else:
				_show_dialogue("演武区 · 回锋心得", "借来势，收剑再回锋。将渡口一战的体会记下来，可得武学心得 +1。", "整理心得", _commit_dialogue.bind("reversal_lesson", "武学心得 +1。可随时回访，立场选择不会影响这份心得。"))
			modal_buttons.add_child(UIKit.battle_button("队伍成长", _show_preparation.bind("party"), 220, 84))
		"bamboo_event":
			if Game.chapter.b2_clear:
				_show_dialogue("竹林 · 空匣旧迹", "遗匣已被取走。匣底残留半截青岚印记拓片，旁边有匆忙撤离的足迹。\n废祠渡簿仍是主线；此处不再开战。")
			elif not Game.chapter.can_event("bamboo_battle_start"):
				_show_dialogue(target["name"] + " · 线索不足", "此处有旧日车辙，却还不能确认来历。\n先调查渡口，再回客栈听取两派解释并选择立场。")
			else:
				_show_dialogue("竹林遗匣 · 战前确认", "竹影深处有一只封漆旧匣，有人守着不肯离开。\n目标：相邻格花费 2AP 取匣，再至少一人抵达撤离点。\n出战：剑客、枪客、拳师。可选支线，不完成也能去废祠。", "确认出战", _start_bamboo_battle)
		"shrine_event":
			if not Game.chapter.can_event("shrine_battle_start"):
				_show_dialogue(target["name"] + " · 线索不足", "此处有旧日车辙，却还不能确认来历。\n先调查渡口，再回客栈听取两派解释并选择立场。")
			else:
				_show_dialogue(target["name"] + " · 后续开放", "线索已经明确。可直接追查废祠渡簿，无需先去竹林。\n此处战斗后续开放。")
	return true


func _stance_dialogue(id: String) -> void:
	var escort := id == "meng"
	var speaker := "孟秋白 · 白鹭镖局" if escort else "洛青禾 · 青岚门"
	var text := "先把货箱护住。箱子在，押镖人的口供就不会变。" if escort else "印信只是表面。祠后小路和一道暗记，才是他们真正要藏的。"
	if not Game.chapter.b1_clear:
		_show_dialogue(speaker, text + "\n先到渡口核查封箱，再定下一步。")
	elif Game.chapter.stance != "":
		_show_dialogue(speaker, text + "\n你的立场已经确定：" + ("守约护箱（白鹭镖局）。" if Game.chapter.stance == "escort" else "核验暗记（青岚门）。") + "此事不再改选。")
	else:
		text += "\n\n选择后仅能确定一次。\n" + ("守约护箱：镖局关系 +1；废祠将有可利用的货车。" if escort else "核验暗记：青岚门关系 +1；废祠可从侧翼部署，并预先排除一处陷阱。")
		_show_dialogue(speaker, text, "确认：守约护箱" if escort else "确认：核验暗记", _commit_dialogue.bind("choose_escort" if escort else "choose_sect", "立场已确定。可前往废祠门口追查渡簿，或先去竹林《遗匣》可选关卡。\nB3 废祠战斗后续开放。"))


func _commit_dialogue(event_id: String, message: String) -> void:
	_sync_position()
	if Game.commit_chapter_event(event_id):
		_show_dialogue("江湖记事", message)
	else:
		_show_dialogue("江湖记事", "条件已变化或存档未能写入，本次未提交。可重新交谈。")
	_refresh_ui()


func _start_ferry_battle() -> void:
	_sync_position()
	if not Game.begin_ferry_battle(player.position):
		_show_dialogue("渡口", "条件已变化或存档未能写入，请重新调查。")


func _start_bamboo_battle() -> void:
	_sync_position()
	if not Game.begin_bamboo_battle(player.position):
		_show_dialogue("竹林", "条件已变化或存档未能写入，请重新调查。")


func _transfer(destination: String) -> void:
	var before := Game.chapter.to_dict()
	if destination == "inn":
		Game.chapter.outdoor_return = ExplorationRules.valid_spawn("outdoor", player.position)
		Game.chapter.player_position = ExplorationRules.center(ExplorationRules.INN_POINTS["inn_spawn"])
	else:
		Game.chapter.player_position = ExplorationRules.valid_spawn("outdoor", Game.chapter.outdoor_return)
	Game.chapter.scene_id = destination
	Game.chapter.facing = "N" if destination == "inn" else "S"
	if not Game.save_chapter():
		Game.chapter = ChapterState.from_dict(before)
		_show_dialogue("行路", "存档未能写入，暂未切换区域。请重试。")
		return
	Game._change("explore")


func _sync_position() -> void:
	Game.chapter.scene_id = area
	Game.chapter.player_position = ExplorationRules.valid_spawn(area, player.position)
	Game.chapter.facing = player.facing


func _save_position() -> void:
	_sync_position()
	if Game.save_chapter():
		last_saved_position = player.position


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	ui = Control.new()
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(UIKit.full_rect(ui))
	var header := UIKit.battle_panel(UIKit.GOLD, 22)
	header.position = Vector2(24, 20)
	header.custom_minimum_size = Vector2(1080, 122)
	ui.add_child(header)
	var column := UIKit.vbox(8)
	header.add_child(column)
	column.add_child(UIKit.label("江湖 · " + ("听雨客栈" if area == "inn" else "青崖渡") + "    /    第一章", 34, UIKit.GOLD))
	objective_label = UIKit.label("", 27, UIKit.IVORY)
	column.add_child(objective_label)
	status_label = UIKit.label("", 21, UIKit.MUTED)
	column.add_child(status_label)
	minimap = Minimap.new()
	minimap.rows = rows
	minimap.objects = objects
	minimap.player = player
	minimap.position = Vector2(get_viewport_rect().size.x - 294, 20)
	layer.add_child(minimap)
	get_viewport().size_changed.connect(_position_minimap)
	var footer := UIKit.battle_panel(UIKit.GOLD, 22)
	footer.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	footer.offset_left = 24
	footer.offset_right = -24
	footer.offset_top = -104
	footer.offset_bottom = -20
	ui.add_child(footer)
	var row := UIKit.hbox(24)
	footer.add_child(row)
	var help := UIKit.label("WASD / 方向键  行走    E / Enter  交互\nTab  任务日志    Esc  队伍成长与存档    客栈谱库可整备武学", 24, UIKit.IVORY)
	help.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(help)
	row.add_child(UIKit.label("剑客 · 枪客 · 拳师\n" + ("门外主路向东 → 渡口" if area == "inn" else "北行 ↑ 竹林 / 废祠    东行 → 渡口"), 23, UIKit.MUTED))
	prompt = UIKit.battle_panel(UIKit.GOLD, 28)
	prompt.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	prompt.grow_horizontal = Control.GROW_DIRECTION_BOTH
	prompt.grow_vertical = Control.GROW_DIRECTION_BEGIN
	prompt.offset_left = -290
	prompt.offset_right = 290
	prompt.offset_top = -194
	prompt.offset_bottom = -128
	ui.add_child(prompt)
	prompt_label = UIKit.label("", 30, UIKit.GOLD)
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt.add_child(prompt_label)
	place_label = UIKit.label("", 46, UIKit.IVORY, 8)
	place_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	place_label.offset_left = -400
	place_label.offset_right = 400
	place_label.offset_top = 184
	place_label.offset_bottom = 264
	place_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ui.add_child(place_label)
	_build_modal()
	party_panel = PreparationPanel.new()
	ui.add_child(party_panel)
	party_panel.closed.connect(func():
		player.blocked = false
		minimap.show()
		_update_nearest()
	)
	party_panel.changed.connect(_refresh_ui)
	party_panel.return_to_title.connect(_save_and_title)


func _position_minimap() -> void:
	minimap.position.x = get_viewport_rect().size.x - 294


func _build_modal() -> void:
	modal = Control.new()
	ui.add_child(UIKit.full_rect(modal))
	var dim := ColorRect.new()
	dim.color = Color(0.025, 0.05, 0.07, 0.78)
	modal.add_child(UIKit.full_rect(dim))
	var panel := UIKit.battle_panel(UIKit.GOLD, 32)
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -550
	panel.offset_right = 550
	panel.offset_top = -280
	panel.offset_bottom = 280
	modal.add_child(panel)
	var col := UIKit.vbox(26)
	panel.add_child(col)
	modal_title = UIKit.label("", 42, UIKit.GOLD)
	col.add_child(modal_title)
	modal_text = UIKit.label("", 30, UIKit.IVORY)
	modal_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	modal_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(modal_text)
	modal_buttons = UIKit.hbox(24)
	modal_buttons.alignment = BoxContainer.ALIGNMENT_END
	col.add_child(modal_buttons)
	modal.hide()


func _show_dialogue(title: String, text: String, confirm_text := "", action := Callable()) -> void:
	if is_instance_valid(party_panel) and party_panel.visible:
		party_panel.close()
	modal_title.text = title
	modal_text.text = text
	UIKit.clear(modal_buttons)
	modal_action = action
	if action.is_valid():
		modal_buttons.add_child(UIKit.battle_button("暂不决定", _close_dialogue, 220, 84))
		modal_buttons.add_child(UIKit.battle_button(confirm_text, action, 330, 84))
	else:
		modal_buttons.add_child(UIKit.battle_button("继续 [E]", _close_dialogue, 240, 84))
	modal.show()
	player.blocked = true
	prompt.hide()


func _close_dialogue() -> void:
	modal.hide()
	modal_action = Callable()
	player.blocked = false
	_update_nearest()


func _show_journal() -> void:
	var s := Game.chapter
	var text := "当前：" + s.objective() + "\n\n"
	text += ("已接委托" if s.quest_accepted else "尚未接取委托") + "  ·  " + ("渡口已查清" if s.b1_clear else "渡口待调查") + "\n"
	text += "演武心得：" + ("已领取" if s.lesson_received else "B1 后可领取") + "\n"
	text += "立场：" + ({"": "尚未选择", "escort": "守约护箱 · 白鹭镖局", "sect": "核验暗记 · 青岚门"}[s.stance]) + "\n"
	text += "同行：" + _party_summary() + "\n"
	text += "队伍谱库 %d 门 · 武学心得 %d\n" % [s.party.library.size(), s.party.lesson]
	text += "Esc 打开队伍成长；客栈谱库可免费学习与装配。\n"
	text += ("竹林遗匣：已取匣" if s.b2_clear else "竹林遗匣：可选支线") + "  ·  废祠不要求先完成竹林\n"
	text += "B3 废祠战斗后续开放。"
	_show_dialogue("任务日志 [Tab]", text)


func _show_pause() -> void:
	_sync_position()
	_show_preparation("party")


func _show_preparation(page: String, character := "") -> void:
	_close_dialogue()
	_sync_position()
	party_panel.open(page, character)
	minimap.hide()
	player.blocked = true
	prompt.hide()


func _save_and_title() -> void:
	_sync_position()
	if Game.save_chapter():
		Game.goto_title()
	else:
		_show_dialogue("存档未能写入", "请重试保存，当前章节进度仍保留在此处。")


func _party_summary() -> String:
	var parts: Array[String] = []
	for id in PartyState.IDS:
		var c: Dictionary = Game.chapter.party.characters[id]
		parts.append("%s Lv.%d·%s" % [Game.chapter.party.stats(id)["name"], c["level"], PartyState.TRAITS[id]])
	return " / ".join(parts)


func _refresh_ui() -> void:
	objective_label.text = "当前 · " + Game.chapter.objective()
	status_label.text = "%s    心得 %d    谱库 %d" % [_party_summary(), Game.chapter.party.lesson, Game.chapter.party.library.size()]



func _draw() -> void:
	draw_rect(Rect2(-20000, -20000, 40000, 40000), Color("152028"))
	# Painter's algorithm: back-to-front along iso depth (x+y).
	var cells: Array[Vector2i] = []
	for y in rows.size():
		for x in rows[y].length():
			cells.append(Vector2i(x, y))
	cells.sort_custom(func(a, b): return (a.x + a.y) < (b.x + b.y))
	for cell in cells:
		_draw_iso_tile(cell, rows[cell.y][cell.x])
	if area == "outdoor":
		_draw_iso_building(Vector2i(4, 18), Vector2i(9, 4), "听雨客栈", Vector2i(8, 21))
		_draw_iso_building(Vector2i(32, 3), Vector2i(9, 6), "废祠", Vector2i(37, 8))
		_draw_iso_sign(Vector2i(15, 21), "渡口 →")
		_draw_iso_sign(Vector2i(20, 12), "竹林 ↑")
		_draw_iso_sign(Vector2i(33, 14), "废祠 ↑")
		_draw_ferry_boat()
		_draw_outdoor_props()
	else:
		_draw_iso_inn_furniture()
	for obj in objects:
		var iso := ExploreIso.world_to_iso(obj["position"])
		var selected: bool = obj["id"] == nearest
		var col := UIKit.GOLD if selected else Color(0.84, 0.76, 0.51, 0.55)
		_draw_iso_marker(iso, col)
		if not obj.has("cls") and obj["id"] not in ["inn_door", "shrine_event"]:
			draw_string(font, iso + Vector2(-70, -56), obj["name"], HORIZONTAL_ALIGNMENT_CENTER, 140, 20, UIKit.IVORY)
	# Player sprite in IsoView space (collision body stays in design-space).
	if is_instance_valid(player):
		_draw_iso_player(ExploreIso.world_to_iso(player.position), player.facing)


func _tex(key: String) -> Texture2D:
	return tile_tex.get(key)


func _draw_iso_tile(cell: Vector2i, ch: String) -> void:
	var art := ExploreIso.art_for(ch)
	var h := ExploreIso.height_for(ch)
	# Dock boards near water use bridge art.
	if ch == "=" and area == "outdoor" and cell.x >= 34:
		art = "bridge"
	var origin := ExploreIso.cell_to_iso(cell, h)
	var tw := ExploreIso.TW
	var th := ExploreIso.TH
	var hs := ExploreIso.HS
	var side: Texture2D = _tex("side_%s" % art)
	if side == null and art == "mud":
		side = _tex("side_stone")
	if side == null and art == "forest":
		side = _tex("side_grass")
	for i in range(h, 0, -1):
		if side:
			draw_texture(side, origin + Vector2(-tw * 0.5, i * hs))
	var sidetop: Texture2D = _tex("sidetop_%s" % art)
	if sidetop == null and art == "mud":
		sidetop = _tex("sidetop_stone")
	if sidetop:
		draw_texture(sidetop, origin + Vector2(-tw * 0.5, 0))
	var variant := posmod(cell.x * 7 + cell.y * 11, 4)
	var top: Texture2D = _tex("%s_%d" % [art, variant])
	if top == null and art == "grassdirt":
		top = _tex("mud_%d" % variant)
	if top == null:
		top = _tex("grass_%d" % variant)
	if top:
		draw_texture(top, origin + Vector2(-tw * 0.5, -th * 0.5))
	if ch == "#":
		if deco_tree:
			draw_texture(deco_tree, origin + Vector2(-36, -110))
		else:
			draw_circle(origin + Vector2(0, -30), 22, Color("203d36"))
			draw_circle(origin + Vector2(-6, -48), 18, Color("355745"))
	elif ch == "H" and area == "outdoor":
		pass
	elif ch == "," and deco_crate and posmod(cell.x + cell.y * 3, 11) == 0:
		draw_texture(deco_crate, origin + Vector2(-20, -28))


func _draw_iso_building(origin_cell: Vector2i, size: Vector2i, title: String, door: Vector2i) -> void:
	var base := ExploreIso.cell_to_iso(origin_cell + Vector2i(size.x / 2, size.y / 2), 2)
	var tw := ExploreIso.TW
	var th := ExploreIso.TH
	# Floor stone inside, raised wall ring, stone roof diamonds.
	for dy in size.y:
		for dx in size.x:
			var cell := origin_cell + Vector2i(dx, dy)
			var edge := dx == 0 or dy == 0 or dx == size.x - 1 or dy == size.y - 1
			var h := 2 if edge else 1
			var o := ExploreIso.cell_to_iso(cell, h)
			var art := "wall" if edge else "stone"
			var side: Texture2D = _tex("side_%s" % ("wall" if edge else "stone"))
			if side:
				for i in range(h, 0, -1):
					draw_texture(side, o + Vector2(-tw * 0.5, i * ExploreIso.HS))
			var top: Texture2D = _tex("%s_%d" % [art, posmod(dx + dy, 4)])
			if top:
				draw_texture(top, o + Vector2(-tw * 0.5, -th * 0.5))
	# Dark roof ridge across the long axis.
	var roof_a := ExploreIso.cell_to_iso(origin_cell + Vector2i(1, 0), 3)
	var roof_b := ExploreIso.cell_to_iso(origin_cell + Vector2i(size.x - 2, 0), 3)
	draw_line(roof_a + Vector2(0, -th), roof_b + Vector2(0, -th), Color("2a3a3c"), 6)
	var door_iso := ExploreIso.world_to_iso(ExplorationRules.center(door))
	draw_colored_polygon(PackedVector2Array([
		door_iso + Vector2(0, -18), door_iso + Vector2(22, 0), door_iso + Vector2(0, 18), door_iso + Vector2(-22, 0)
	]), Color("1c2c2a"))
	draw_string(font, base + Vector2(-90, -150), title, HORIZONTAL_ALIGNMENT_CENTER, 180, 26, UIKit.GOLD)


func _draw_iso_sign(cell: Vector2i, text: String) -> void:
	var o := ExploreIso.cell_to_iso(cell)
	draw_line(o + Vector2(0, -8), o + Vector2(0, 18), Color("514a34"), 4)
	draw_rect(Rect2(o + Vector2(-70, -40), Vector2(140, 28)), Color("33453d"))
	draw_string(font, o + Vector2(-68, -18), text, HORIZONTAL_ALIGNMENT_CENTER, 136, 18, UIKit.GOLD)


func _draw_ferry_boat() -> void:
	var o := ExploreIso.cell_to_iso(Vector2i(44, 23))
	draw_colored_polygon(PackedVector2Array([
		o + Vector2(-50, 0), o + Vector2(-10, -18), o + Vector2(55, -6), o + Vector2(40, 16), o + Vector2(-30, 14)
	]), Color("725a3d"))
	draw_line(o + Vector2(-40, 0), ExploreIso.cell_to_iso(Vector2i(42, 23)), UIKit.GOLD, 3)


func _draw_outdoor_props() -> void:
	# Cargo crates at the ferry and shrine path markers.
	for cell in [Vector2i(35, 22), Vector2i(36, 21), Vector2i(38, 24), Vector2i(34, 10), Vector2i(17, 8)]:
		var o := ExploreIso.cell_to_iso(cell)
		if deco_crate:
			draw_texture(deco_crate, o + Vector2(-22, -30))
		else:
			draw_rect(Rect2(o + Vector2(-16, -12), Vector2(32, 20)), Color("8a7050"))


func _draw_iso_inn_furniture() -> void:
	var title_iso := ExploreIso.cell_to_iso(Vector2i(7, 1))
	draw_string(font, title_iso + Vector2(-100, -40), "听 雨 客 栈", HORIZONTAL_ALIGNMENT_CENTER, 200, 28, UIKit.GOLD)
	var desk := ExploreIso.world_to_iso(ExplorationRules.center(ExplorationRules.INN_POINTS["keeper"]))
	draw_rect(Rect2(desk + Vector2(-50, -8), Vector2(100, 26)), Color("473e32"))
	draw_rect(Rect2(desk + Vector2(-50, -16), Vector2(100, 18)), Color("a08558"))
	var library := ExploreIso.world_to_iso(ExplorationRules.center(ExplorationRules.INN_POINTS["codex"]))
	draw_rect(Rect2(library + Vector2(-30, -18), Vector2(60, 34)), Color("423c32"))
	for i in 6:
		draw_rect(Rect2(library + Vector2(-24 + i * 8, -14), Vector2(6, 24)), Color("9aab9a") if i % 2 else Color("bb9d6a"))
	var training := ExploreIso.world_to_iso(ExplorationRules.center(ExplorationRules.INN_POINTS["training"]))
	draw_circle(training, 26, Color("414a41"))
	draw_line(training + Vector2(0, -36), training + Vector2(0, 12), Color("b2935d"), 8)
	var exit_pos := ExploreIso.world_to_iso(ExplorationRules.center(ExplorationRules.INN_POINTS["exit"]))
	draw_colored_polygon(PackedVector2Array([
		exit_pos + Vector2(0, -20), exit_pos + Vector2(26, 0), exit_pos + Vector2(0, 20), exit_pos + Vector2(-26, 0)
	]), Color("aea080"))


func _draw_iso_marker(iso: Vector2, col: Color) -> void:
	var pts := PackedVector2Array([
		iso + Vector2(0, -16), iso + Vector2(28, 0), iso + Vector2(0, 16), iso + Vector2(-28, 0)
	])
	draw_polyline(pts + PackedVector2Array([pts[0]]), col, 2.5)


func _draw_iso_player(iso: Vector2, facing: String) -> void:
	var view := "N" if facing in ["N", "NE", "NW"] else ("W" if facing in ["W", "E"] else ("SW" if facing in ["SW", "SE"] else "S"))
	var tex: Texture2D = player.textures.get(view)
	if tex == null:
		return
	var scale := 0.42
	var flip := facing in ["NE", "E", "SE"]
	var size := tex.get_size() * scale
	var dest := Rect2(iso + Vector2(-size.x * 0.5, -size.y + 8), size)
	if flip:
		draw_set_transform(dest.position + Vector2(size.x, 0), 0, Vector2(-1, 1))
		draw_texture_rect(tex, Rect2(Vector2.ZERO, size), false)
		draw_set_transform(Vector2.ZERO)
	else:
		draw_texture_rect(tex, dest, false)
	# Soft shadow diamond under feet.
	draw_colored_polygon(PackedVector2Array([
		iso + Vector2(0, -8), iso + Vector2(18, 0), iso + Vector2(0, 8), iso + Vector2(-18, 0)
	]), Color(0.05, 0.08, 0.07, 0.35))
