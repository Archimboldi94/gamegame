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
var autosave_time := 0.0
var last_saved_position := Vector2.ZERO
var minimap: Node2D
var party_panel: Control


func _ready() -> void:
	area = Game.chapter.scene_id
	rows = ExplorationRules.grid(area)
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
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
	last_saved_position = player.position
	camera = Camera2D.new()
	camera.zoom = Vector2.ONE * (1.65 if area == "inn" else 1.0)
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


func _build_npcs() -> void:
	for obj in objects:
		if not obj.has("cls"):
			continue
		var actor := Node2D.new()
		actor.position = obj["position"]
		actors.add_child(actor)
		var sprite := Sprite2D.new()
		sprite.texture = load("res://assets/units/dirs/%s_player_S.png" % obj["cls"])
		sprite.centered = false
		sprite.scale = Vector2.ONE * 0.48
		sprite.position = Vector2(-80, -196) * 0.48
		actor.add_child(sprite)
		var name_tag := UIKit.label(obj["name"], 18, UIKit.IVORY, 3)
		name_tag.position = Vector2(-48, -92)
		name_tag.size.x = 96
		name_tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		actor.add_child(name_tag)


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
	var world_size := Vector2(rows[0].length(), rows.size()) * TILE
	var desired := player.position
	# Rooms smaller than a viewport stay centered; larger maps track within bounds.
	for axis in [0, 1]:
		desired[axis] = clampf(desired[axis], view[axis] / 2, world_size[axis] - view[axis] / 2) if world_size[axis] > view[axis] else world_size[axis] / 2
	camera.position = desired


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
		"bamboo_event", "shrine_event":
			var event_id := "bamboo_battle_start" if object_id == "bamboo_event" else "shrine_battle_start"
			if not Game.chapter.can_event(event_id):
				_show_dialogue(target["name"] + " · 线索不足", "此处有旧日车辙，却还不能确认来历。\n先调查渡口，再回客栈听取两派解释并选择立场。")
			else:
				_show_dialogue(target["name"] + " · 后续开放", "线索已经明确。" + ("竹林遗匣是可选线索。" if object_id == "bamboo_event" else "可直接追查废祠渡簿，无需先去竹林。") + "\n此处战斗后续开放。")
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
		_show_dialogue(speaker, text, "确认：守约护箱" if escort else "确认：核验暗记", _commit_dialogue.bind("choose_escort" if escort else "choose_sect", "立场已确定。可前往废祠门口追查渡簿，或先去竹林寻找可选线索。\nB2 / B3 战斗后续开放。"))


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
	var help := UIKit.label("WASD / 方向键  行走    E / Enter  交互\nTab  任务日志    Esc  队伍与存档", 24, UIKit.IVORY)
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
	text += "竹林遗匣为可选线索；废祠不要求先完成竹林。\nB2 / B3 战斗后续开放。"
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


func _refresh_ui() -> void:
	objective_label.text = "当前 · " + Game.chapter.objective()
	status_label.text = "同行三人独立成长    心得 %d    队伍谱库 %d 门武学" % [Game.chapter.party.lesson, Game.chapter.party.library.size()]


func _draw() -> void:
	draw_rect(Rect2(-5000, -5000, 10000, 10000), Color("182326"))
	for y in rows.size():
		for x in rows[y].length():
			_draw_tile(Vector2i(x, y), rows[y][x])
	if area == "outdoor":
		_draw_building(Rect2(4 * TILE, 18 * TILE, 9 * TILE, 4 * TILE), "听 雨 客 栈", Vector2i(8, 21))
		_draw_building(Rect2(32 * TILE, 3 * TILE, 9 * TILE, 6 * TILE), "废 祠", Vector2i(37, 8))
		_sign(Vector2(15 * TILE, 21 * TILE), "渡口 →    ↑ 竹林")
		_sign(Vector2(33 * TILE, 14 * TILE), "↑ 废祠    ← 竹林")
		# A moored boat and rope along the river, outside the walking surface.
		draw_colored_polygon(PackedVector2Array([Vector2(45, 21.3) * TILE, Vector2(46, 22) * TILE, Vector2(46, 24) * TILE, Vector2(45, 24.7) * TILE, Vector2(44.5, 24) * TILE]), Color("725a3d"))
		draw_line(Vector2(44, 23) * TILE, Vector2(45, 23) * TILE, UIKit.GOLD, 3)
	else:
		_draw_inn_furniture()
	for obj in objects:
		var point: Vector2 = obj["position"]
		var selected: bool = obj["id"] == nearest
		var col := UIKit.GOLD if selected else Color(0.84, 0.76, 0.51, 0.6)
		draw_arc(point, 22, 0, TAU, 32, col, 2)
		if not obj.has("cls") and obj["id"] not in ["inn_door", "shrine_event"]:
			var label_position := point + Vector2(-70, -30)
			draw_string(font, label_position + Vector2(1, 2), obj["name"], HORIZONTAL_ALIGNMENT_CENTER, 140, 22, Color("182326"))
			draw_string(font, label_position, obj["name"], HORIZONTAL_ALIGNMENT_CENTER, 140, 22, UIKit.IVORY)


func _draw_tile(cell: Vector2i, type: String) -> void:
	var point := Vector2(cell) * TILE
	var rect := Rect2(point, Vector2.ONE * TILE)
	var noise := posmod(cell.x * 31 + cell.y * 17, 7) / 70.0
	match type:
		"~":
			draw_rect(rect, Color("355e6d").lightened(noise))
			draw_line(point + Vector2(8, 18), point + Vector2(32, 18), Color(0.61, 0.76, 0.76, 0.3), 2)
			draw_line(point + Vector2(22, 35), point + Vector2(43, 35), Color(0.61, 0.76, 0.76, 0.2), 2)
		"=":
			draw_rect(rect, Color("77654c"))
			for i in 4:
				draw_rect(Rect2(point + Vector2(2, i * 12 + 1), Vector2(44, 9)), Color("a08b62").lightened(noise))
		"H":
			draw_rect(rect, Color("3c3c35"))
		"#":
			draw_rect(rect, Color("344c3b"))
			if area == "inn":
				return
			draw_circle(point + Vector2(24, 30), 23, Color("203d36"))
			draw_circle(point + Vector2(20, 20), 18, Color("355745").lightened(noise))
			draw_line(point + Vector2(22, 27), point + Vector2(22, 46), Color("504c35"), 4)
		".":
			if area == "inn":
				draw_rect(rect, Color("75644d").lightened(noise))
				draw_line(point, point + Vector2(TILE, 0), Color("514a3e"), 1)
				draw_line(point + Vector2(24 if cell.y % 2 else 0, 0), point + Vector2(24 if cell.y % 2 else 0, TILE), Color("63543f"), 1)
			elif cell.y in [13, 14, 15] or (cell.x >= 33 and cell.y < 16):
				draw_rect(rect, Color("929281").lightened(noise))
				draw_rect(rect.grow(-2), Color("a3a18c").lightened(noise))
			else:
				draw_rect(rect, Color("a29570").lightened(noise))
				draw_circle(point + Vector2(12 + cell.y % 5 * 3, 28), 2, Color("847c5c"))
		_:
			draw_rect(rect, Color("62775a").lightened(noise))
			draw_line(point + Vector2(11, 33), point + Vector2(14, 26), Color("829365"), 2)
			draw_line(point + Vector2(33, 13), point + Vector2(36, 17), Color("485f4c"), 2)


func _draw_building(rect: Rect2, title: String, door_cell: Vector2i) -> void:
	draw_rect(rect, Color("c3ac7a"))
	var roof := Rect2(rect.position - Vector2(8, 8), Vector2(rect.size.x + 16, rect.size.y - 34))
	draw_rect(roof, Color("384c50"))
	for y in range(int(roof.position.y), int(roof.end.y), 14):
		draw_line(Vector2(roof.position.x, y), Vector2(roof.end.x, y), Color("586667"), 3)
	draw_line(roof.position, Vector2(roof.end.x, roof.position.y), Color("91a091"), 5)
	var door := ExplorationRules.center(door_cell)
	draw_rect(Rect2(door - Vector2(20, 24), Vector2(40, 48)), Color("283a37"))
	draw_rect(Rect2(door - Vector2(21, 25), Vector2(42, 50)), UIKit.GOLD, false, 2)
	var plaque := Rect2(Vector2(rect.get_center().x - 100, rect.end.y - 88), Vector2(200, 36))
	draw_rect(plaque, Color("293e40"))
	draw_string(font, plaque.position + Vector2(0, 27), title, HORIZONTAL_ALIGNMENT_CENTER, 200, 24, UIKit.GOLD)
	for offset in [-48, 48]:
		draw_rect(Rect2(door + Vector2(offset - 6, -20), Vector2(12, 22)), Color("c48b50"))


func _draw_inn_furniture() -> void:
	var world_size := Vector2(14, 10) * TILE
	draw_rect(Rect2(4, 4, world_size.x - 8, 40), Color("48504a"))
	draw_string(font, Vector2(0, 32), "听 雨 客 栈", HORIZONTAL_ALIGNMENT_CENTER, world_size.x, 25, UIKit.GOLD)
	# Furniture feet occupy exactly the corresponding interactable collision circles.
	var desk := ExplorationRules.center(ExplorationRules.INN_POINTS["keeper"])
	draw_rect(Rect2(desk - Vector2(44, 6), Vector2(88, 23)), Color("473e32"))
	draw_rect(Rect2(desk - Vector2(44, 11), Vector2(88, 16)), Color("a08558"))
	var library := ExplorationRules.center(ExplorationRules.INN_POINTS["codex"])
	draw_rect(Rect2(library - Vector2(28, 14), Vector2(56, 30)), Color("423c32"))
	for i in 6:
		draw_rect(Rect2(library + Vector2(-23 + i * 8, -11), Vector2(6, 23)), Color("9aab9a") if i % 2 else Color("bb9d6a"))
	var training := ExplorationRules.center(ExplorationRules.INN_POINTS["training"])
	draw_circle(training, 24, Color("414a41"))
	draw_line(training + Vector2(0, -34), training + Vector2(0, 10), Color("b2935d"), 8)
	draw_line(training + Vector2(-18, -20), training + Vector2(18, -20), Color("b2935d"), 6)
	# Rugs guide the walkable central aisle; no invisible furniture obstacles.
	draw_rect(Rect2(5 * TILE, 4 * TILE, 3 * TILE, 4 * TILE), Color(0.36, 0.24, 0.19, 0.42))
	draw_rect(Rect2(5 * TILE + 4, 4 * TILE + 4, 3 * TILE - 8, 4 * TILE - 8), Color(0.71, 0.56, 0.32, 0.4), false, 2)
	var exit_pos := ExplorationRules.center(ExplorationRules.INN_POINTS["exit"])
	draw_rect(Rect2(exit_pos - Vector2(24, 24), Vector2(48, 48)), Color("aea080"))


func _sign(point: Vector2, text: String) -> void:
	draw_line(point + Vector2(0, -8), point + Vector2(0, 20), Color("514a34"), 5)
	draw_rect(Rect2(point - Vector2(86, 39), Vector2(172, 33)), Color("33453d"))
	draw_string(font, point + Vector2(-84, -14), text, HORIZONTAL_ALIGNMENT_CENTER, 168, 18, UIKit.GOLD)
