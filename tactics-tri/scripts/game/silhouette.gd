extends Control
## Dialogue uses the same original manuscript busts as the battle HUD.

var color := Color.WHITE  # Compatibility with speaker metadata.
var active := true
var flip := false
var cls := ""
var who := ""
var _key := ""
var _portrait: Texture2D


func _draw() -> void:
	var key := who if who != "" else "linyan"
	if key != _key:
		_key = key
		_portrait = load("res://assets/portraits/%s.png" % key)
	if _portrait == null:
		return
	var tint := Color.WHITE if active else Color(0.65, 0.68, 0.73, 0.85)
	if flip:
		draw_set_transform(Vector2(size.x, 0), 0.0, Vector2(-1, 1))
	draw_texture_rect(_portrait, Rect2(Vector2.ZERO, size), false, tint)
	draw_set_transform(Vector2.ZERO)
