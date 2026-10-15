extends Node2D
## An unclickable overview of the actual collision map.

var rows: Array[String] = []
var objects: Array[Dictionary] = []
var player: Node2D
var font := preload("res://fonts/DroidSansFallbackFull.ttf")


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	draw_style_box(UIKit.color_box(UIKit.INK, 6, UIKit.GOLD, 2), Rect2(0, 0, 270, 224))
	draw_string(font, Vector2(16, 28), "听雨客栈" if rows.size() == 10 else "青崖渡   北 ↑", HORIZONTAL_ALIGNMENT_LEFT, 240, 21, UIKit.GOLD)
	var scale_factor := minf(238.0 / rows[0].length(), 150.0 / rows.size())
	var origin := Vector2(16, 42)
	for y in rows.size():
		for x in rows[y].length():
			var col := Color("75856b")
			if rows[y][x] == "~":
				col = Color("456e87")
			elif ExplorationRules.is_blocked(rows, Vector2i(x, y)):
				col = Color("3d4b43")
			elif rows[y][x] in [".", "="]:
				col = Color("b0a17b")
			draw_rect(Rect2(origin + Vector2(x, y) * scale_factor, Vector2.ONE * scale_factor), col)
	for obj in objects:
		var point: Vector2 = origin + obj["position"] / ExplorationRules.TILE * scale_factor
		draw_circle(point, 3, UIKit.GOLD)
		var tag: String = {"inn_door": "栈", "ferry_event": "渡", "bamboo_event": "竹", "shrine_event": "祠"}.get(obj["id"], "")
		if tag != "":
			draw_string(font, point + Vector2(4, -5), tag, HORIZONTAL_ALIGNMENT_LEFT, 24, 16, UIKit.IVORY)
	if is_instance_valid(player):
		draw_circle(origin + player.position / ExplorationRules.TILE * scale_factor, 4, UIKit.ALLY)
	draw_string(font, Vector2(16, 210), "◆ 地点    ● 你的位置", HORIZONTAL_ALIGNMENT_LEFT, 240, 17, UIKit.MUTED)
