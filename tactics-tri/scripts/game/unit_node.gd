extends Node2D
## Visual for one BattleUnit: team ring, facing arrow, chibi sprite, HP bar, active marker,
## plus the procedural hit reactions (flash shader, shake, HP drain, death fade).

const SPRITE_RECT := Rect2(-50, -136, 100, 150)
const SEE_THROUGH_ALPHA := 0.32
const SPRITE_POS := Vector2(-48, -116)
const BODY := Vector2(0, -58)
const FLASH_SHADER := """
shader_type canvas_item;
uniform float flash : hint_range(0.0, 1.0) = 0.0;
uniform vec4 flash_color : source_color = vec4(1.0);
void fragment() {
	vec4 c = texture(TEXTURE, UV) * COLOR;
	COLOR = vec4(mix(c.rgb, flash_color.rgb, flash * c.a), c.a);
}
"""

static var _shader: Shader

var unit: BattleUnit
var view: IsoView
var sprite: Sprite2D
var mat: ShaderMaterial
var active := false
var see_through := false
var _see_tw: Tween
var t := 0.0
var display_hp := 1.0:  # green bar; held at the pre-hit value until the hit lands
	set(v):
		display_hp = v
		queue_redraw()
var trail_hp := 1.0:  # white "damage trail" that drains after the green bar drops
	set(v):
		trail_hp = v
		queue_redraw()


func setup(u: BattleUnit, v: IsoView) -> void:
	unit = u
	view = v
	if _shader == null:
		_shader = Shader.new()
		_shader.code = FLASH_SHADER
	mat = ShaderMaterial.new()
	mat.shader = _shader
	sprite = Sprite2D.new()
	var team := "player" if u.team == BattleUnit.PLAYER else "enemy"
	sprite.texture = load("res://assets/units/%s_%s.png" % [u.cls, team])
	sprite.centered = false
	sprite.position = SPRITE_POS
	sprite.material = mat
	add_child(sprite)
	refresh()


func cell_z(p: Vector2i) -> int:
	return view.unit_z(p)


func place_at(p: Vector2i, h: int) -> void:
	position = view.screen(p, h)
	z_index = cell_z(p)


func body_pos() -> Vector2:
	return position + BODY


func refresh() -> void:
	sprite.flip_h = view.faces_left(unit.facing)
	visible = unit.alive()
	display_hp = unit.hp
	trail_hp = unit.hp
	queue_redraw()


## Syncs only the facing (sprite flip + arrow) without touching the HP bar mid-animation.
func face() -> void:
	sprite.flip_h = view.faces_left(unit.facing)
	queue_redraw()


## Fades the sprite and its HUD so the tile it hides stays readable. Uses sprite.modulate and
## self_modulate, leaving `modulate` free for the death / undo fades.
func set_see_through(on: bool) -> void:
	if on == see_through:
		return
	see_through = on
	if _see_tw != null:
		_see_tw.kill()
	var a := SEE_THROUGH_ALPHA if on else 1.0
	_see_tw = create_tween().set_parallel(true)
	_see_tw.tween_property(sprite, "modulate:a", a, 0.12)
	_see_tw.tween_property(self, "self_modulate:a", a, 0.12)


func world_rect() -> Rect2:
	return Rect2(position + SPRITE_RECT.position, SPRITE_RECT.size)


func hold_hp(v: int) -> void:
	display_hp = v
	trail_hp = v


# ------------------------------------------------------------------ reactions

## Tints the sprite toward `col` (white = classic hit flash) and back.
func flash(col: Color, strength := 1.0, dur := 0.22) -> Tween:
	mat.set_shader_parameter("flash_color", col)
	mat.set_shader_parameter("flash", strength)
	var tw := create_tween()
	tw.tween_property(mat, "shader_parameter/flash", 0.0, dur).set_ease(Tween.EASE_IN)
	return tw


## Jitters the sprite horizontally (hit / collision shake) without moving the node itself.
func shake(amount := 8.0, dur := 0.22) -> Tween:
	var tw := create_tween()
	var steps := 5
	for i in steps:
		var k := 1.0 - float(i) / steps
		var off := Vector2(amount * k * (1.0 if i % 2 == 0 else -1.0), 0)
		tw.tween_property(sprite, "position", SPRITE_POS + off, dur / (steps + 1))
	tw.tween_property(sprite, "position", SPRITE_POS, dur / (steps + 1))
	return tw


## Quick sidestep used for misses.
func dodge(dir: Vector2) -> Tween:
	var tw := create_tween()
	var off := Vector2(-dir.y, dir.x).normalized() * 26.0
	tw.tween_property(sprite, "position", SPRITE_POS + off, 0.09).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(sprite, "position", SPRITE_POS, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	return tw


## Damage: green bar drops at once and the white trail drains. Healing: green bar fills up.
func drain_hp(to: int, dur := 0.35) -> Tween:
	var tw := create_tween()
	if to < display_hp:
		display_hp = to
		tw.tween_property(self, "trail_hp", float(to), dur).set_delay(0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	else:
		trail_hp = to
		tw.tween_property(self, "display_hp", float(to), dur).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	return tw


## Hit reaction: white flash, recoil away from the blow and a short shake.
func hit(dir: Vector2, heavy := false) -> Tween:
	flash(Color(1, 1, 1), 1.0, 0.24)
	var push := dir.normalized() * (22.0 if heavy else 14.0)
	var tw := create_tween()
	tw.tween_property(sprite, "position", SPRITE_POS + push, 0.05).set_ease(Tween.EASE_OUT)
	for i in 4:
		var k := 1.0 - i / 4.0
		tw.tween_property(sprite, "position", SPRITE_POS + push * k * 0.6 + Vector2((7.0 if i % 2 == 0 else -7.0) * k, 0), 0.04)
	tw.tween_property(sprite, "position", SPRITE_POS, 0.06)
	return tw


## Forward lunge toward `dir`; the tween's first step ends at the moment of impact.
func lunge(dir: Vector2, dist := 34.0) -> Tween:
	var tw := create_tween()
	tw.tween_property(sprite, "position", SPRITE_POS - dir.normalized() * 8.0, 0.06).set_ease(Tween.EASE_OUT)
	tw.tween_property(sprite, "position", SPRITE_POS + dir.normalized() * dist, 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(sprite, "position", SPRITE_POS, 0.16).set_delay(0.06).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	return tw


## White-out, sink and fade; hides the node at the end.
func die() -> Tween:
	mat.set_shader_parameter("flash_color", Color(1, 1, 1))
	mat.set_shader_parameter("flash", 0.9)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(self, "modulate:a", 0.0, 0.45).set_delay(0.08)
	tw.tween_property(sprite, "position", SPRITE_POS + Vector2(0, 18), 0.45).set_ease(Tween.EASE_IN)
	tw.tween_property(sprite, "scale", Vector2(1.08, 0.82), 0.45)
	tw.chain().tween_callback(func():
		visible = false
		modulate.a = 1.0
		see_through = false
		sprite.modulate.a = 1.0
		self_modulate.a = 1.0
		sprite.position = SPRITE_POS
		sprite.scale = Vector2.ONE
		mat.set_shader_parameter("flash", 0.0))
	return tw


# ------------------------------------------------------------------ drawing

func _process(delta: float) -> void:
	if active:
		t += delta
		queue_redraw()


func _draw() -> void:
	var col := Color(0.35, 0.65, 1.0) if unit.team == BattleUnit.PLAYER else Color(1.0, 0.35, 0.3)
	var ring := PackedVector2Array()
	for i in 25:
		var a := TAU * i / 24.0
		ring.append(Vector2(cos(a) * 38.0, sin(a) * 19.0))
	draw_colored_polygon(ring, Color(0, 0, 0, 0.35))
	if active:
		var pulse := 0.5 + 0.5 * sin(t * 4.0)
		var outer := PackedVector2Array()
		for p in ring:
			outer.append(p * (1.12 + 0.06 * pulse))
		draw_polyline(outer, Color(1, 0.9, 0.4, 0.5 + 0.4 * pulse), 3.0)
	draw_polyline(ring, col, 4.0 if active else 3.0)
	var v: Vector2 = view.screen_dir(unit.facing)
	var perp := Vector2(-v.y, v.x)
	var tip := Vector2(v.x * 62.0, v.y * 62.0)
	var base := Vector2(v.x * 40.0, v.y * 40.0)
	draw_colored_polygon(PackedVector2Array([tip, base + perp * 13.0, base - perp * 13.0]), col.lightened(0.2))
	draw_polyline(PackedVector2Array([tip, base + perp * 13.0, base - perp * 13.0, tip]), Color(0, 0, 0, 0.6), 2.0)
	var ratio := clampf(display_hp / float(unit.max_hp), 0.0, 1.0)
	var trail := clampf(trail_hp / float(unit.max_hp), 0.0, 1.0)
	draw_rect(Rect2(-40, -134, 80, 14), Color(0, 0, 0, 0.8))
	if trail > ratio:
		draw_rect(Rect2(-38, -132, 76.0 * trail, 10), Color(1.0, 0.95, 0.85))
	var hp_col := Color(0.35, 0.9, 0.4) if ratio > 0.5 else (Color(1.0, 0.8, 0.25) if ratio > 0.25 else Color(1.0, 0.3, 0.25))
	draw_rect(Rect2(-38, -132, 76.0 * ratio, 10), hp_col)
	for i in unit.max_tp:
		var c := Color(0.55, 0.85, 1.0) if i < unit.tp else Color(0.2, 0.22, 0.3)
		draw_rect(Rect2(-38 + i * 16, -145, 13, 8), c)
	if unit.is_leader:
		_star(Vector2(50, -130), 12.0, Color(1.0, 0.82, 0.3))
	if unit.is_lord:
		_star(Vector2(50, -130), 12.0, Color(0.6, 0.85, 1.0))
	if unit.guard:
		_shield_badge(Vector2(-52, -128))
	if active:
		var y := -178.0 + sin(t * 5.0) * 6.0
		draw_colored_polygon(PackedVector2Array([Vector2(-16, y), Vector2(16, y), Vector2(0, y + 20)]), Color(1, 0.9, 0.4))
		draw_polyline(PackedVector2Array([Vector2(-16, y), Vector2(16, y), Vector2(0, y + 20), Vector2(-16, y)]), Color(0.2, 0.12, 0, 0.8), 2.0)


func _star(c: Vector2, r: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 10:
		var a := -PI / 2 + i * PI / 5
		var rr := r if i % 2 == 0 else r * 0.45
		pts.append(c + Vector2(cos(a), sin(a)) * rr)
	draw_colored_polygon(pts, col)


func _shield_badge(c: Vector2) -> void:
	var pts := PackedVector2Array([c + Vector2(-9, -10), c + Vector2(9, -10), c + Vector2(9, 2), c + Vector2(0, 11), c + Vector2(-9, 2)])
	draw_colored_polygon(pts, Color(0.95, 0.8, 0.35))
	pts.append(pts[0])
	draw_polyline(pts, Color(0.2, 0.15, 0.05), 2.0)
