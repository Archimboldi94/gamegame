extends Node2D
## Procedural battle effects drawn above the map: slash arcs, thrust streaks, projectiles,
## tile flashes, particle bursts, glows, shields. No image assets are used; the only texture is a
## radial gradient generated at runtime. Every effect finishes in well under 0.6 s.

var glow_tex: GradientTexture2D
var add_mat: CanvasItemMaterial


class Shape extends Node2D:
	const DIAMOND := [Vector2(0, -32), Vector2(64, 0), Vector2(0, 32), Vector2(-64, 0)]
	var kind := ""
	var col := Color.WHITE
	var dir := Vector2.RIGHT
	var radius := 40.0
	var length := 100.0
	var t := 0.0:
		set(v):
			t = v
			queue_redraw()

	func _draw() -> void:
		var fade := 1.0 - clampf((t - 0.55) / 0.45, 0.0, 1.0)
		match kind:
			"slash":
				var a0 := dir.angle() - 1.25
				var sweep := 2.5 * clampf(t * 1.8, 0.0, 1.0)
				var pts := PackedVector2Array()
				for i in 15:
					var a := a0 + sweep * i / 14.0
					pts.append(Vector2(cos(a), sin(a) * 0.62) * radius)
				draw_polyline(pts, Color(col, fade), 12.0 * (1.0 - t * 0.5), true)
				draw_polyline(pts, Color(1, 1, 1, fade), 4.0, true)
			"cross":
				var r := radius * (0.5 + t * 0.6)
				for d in [Vector2(1, 0.55), Vector2(1, -0.55)]:
					draw_line(-d * r, d * r, Color(col, fade), 10.0, true)
					draw_line(-d * r, d * r, Color(1, 1, 1, fade), 3.0, true)
			"ring":
				var rr := radius * (0.25 + t * 0.95)
				var ring := PackedVector2Array()
				for i in 33:
					var a := TAU * i / 32.0
					ring.append(Vector2(cos(a) * rr, sin(a) * rr * 0.5))
				draw_polyline(ring, Color(col, (1.0 - t) * 0.95), 6.0 * (1.0 - t) + 1.0, true)
			"diamond":
				var s := 0.65 + 0.35 * minf(1.0, t * 2.5)
				var pts := PackedVector2Array()
				for v in DIAMOND:
					pts.append(v * s)
				draw_colored_polygon(pts, Color(col, 0.75 * (1.0 - t)))
				pts.append(pts[0])
				draw_polyline(pts, Color(1, 1, 1, 0.9 * (1.0 - t)), 4.0)
			"streak":
				var head := clampf(t * 2.2, 0.0, 1.0) * length
				var tail := clampf((t - 0.35) * 1.6, 0.0, 1.0) * length
				draw_line(dir * tail, dir * head, Color(col, fade), 16.0, true)
				draw_line(dir * tail, dir * head, Color(1, 1, 1, fade), 5.0, true)
			"arrow":
				var back := -dir * 34.0
				draw_line(back, Vector2.ZERO, Color(0.45, 0.3, 0.15), 4.0, true)
				var perp := Vector2(-dir.y, dir.x)
				draw_colored_polygon(PackedVector2Array([dir * 10.0, perp * 6.0, -perp * 6.0]), Color(0.85, 0.85, 0.9))
				draw_line(back, back + (-dir + perp) * 8.0, col, 3.0)
				draw_line(back, back + (-dir - perp) * 8.0, col, 3.0)
			"orb":
				draw_circle(Vector2.ZERO, radius, Color(col, 0.35))
				draw_circle(Vector2.ZERO, radius * 0.62, Color(col, 0.8))
				draw_circle(Vector2.ZERO, radius * 0.3, Color(1, 1, 1, 0.95))
			"shield":
				var a := sin(t * PI)
				var pts := PackedVector2Array()
				for i in 7:
					var ang := -PI / 2 + TAU * i / 6.0
					pts.append(Vector2(cos(ang) * radius, sin(ang) * radius * 1.25))
				draw_colored_polygon(pts, Color(col, 0.22 * a))
				draw_polyline(pts, Color(col, 0.95 * a), 5.0, true)
			"wind":
				for i in 4:
					var y := -90.0 + i * 26.0
					var x0 := -70.0 + t * 140.0 - i * 12.0
					draw_line(Vector2(x0, y), Vector2(x0 + 50.0, y), Color(col, fade * 0.9), 4.0, true)
			"star":
				var r0 := radius * (0.15 + t * 0.35)
				var r1 := radius * (0.45 + t * 0.75)
				for i in 8:
					var a := TAU * i / 8.0 + 0.2
					var v := Vector2(cos(a), sin(a) * 0.7)
					draw_line(v * r0, v * r1, Color(col, fade), 7.0 * (1.0 - t * 0.6), true)
					draw_line(v * r0, v * r1, Color(1, 1, 1, fade), 2.5, true)
			"chop":
				var k := clampf(t * 2.4, 0.0, 1.0)
				var pts := PackedVector2Array()
				for i in 12:
					var a := -1.9 + 1.5 * k * i / 11.0
					pts.append(Vector2(cos(a) * radius * 0.55 + dir.x * 10.0, sin(a) * radius + radius * 0.35))
				draw_polyline(pts, Color(col, fade), 16.0 * (1.0 - t * 0.5), true)
				draw_polyline(pts, Color(1, 1, 1, fade), 5.0, true)
			"pillar":
				var w := radius * (1.0 - t * 0.6)
				var hgt := length * minf(1.0, t * 3.0)
				draw_rect(Rect2(-w * 0.5, -hgt, w, hgt), Color(col, 0.35 * fade))
				draw_rect(Rect2(-w * 0.18, -hgt, w * 0.36, hgt), Color(1, 1, 1, 0.5 * fade))


func _init() -> void:
	z_index = 3000
	z_as_relative = false
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	glow_tex = GradientTexture2D.new()
	glow_tex.gradient = g
	glow_tex.width = 64
	glow_tex.height = 64
	glow_tex.fill = GradientTexture2D.FILL_RADIAL
	glow_tex.fill_from = Vector2(0.5, 0.5)
	glow_tex.fill_to = Vector2(1.0, 0.5)
	add_mat = CanvasItemMaterial.new()
	add_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD


func _shape(kind: String, at: Vector2, col: Color, dur: float, setup := {}) -> Tween:
	var s := Shape.new()
	s.kind = kind
	s.col = col
	s.position = at
	for k in setup:
		s.set(k, setup[k])
	add_child(s)
	var tw := s.create_tween()
	tw.tween_property(s, "t", 1.0, dur).from(0.0)
	tw.tween_callback(s.queue_free)
	return tw


## Soft additive glow that swells and fades.
func glow(at: Vector2, col: Color, size := 1.0, dur := 0.3) -> Tween:
	var sp := Sprite2D.new()
	sp.texture = glow_tex
	sp.material = add_mat
	sp.modulate = col
	sp.position = at
	sp.scale = Vector2.ONE * size * 0.6
	add_child(sp)
	var tw := sp.create_tween()
	tw.set_parallel(true)
	tw.tween_property(sp, "scale", Vector2.ONE * size * 2.2, dur).set_ease(Tween.EASE_OUT)
	tw.tween_property(sp, "modulate:a", 0.0, dur).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(sp.queue_free)
	return tw


## One-shot particle burst. `up` > 0 makes particles rise (healing, flames), < 0 fall (ice shards).
func burst(at: Vector2, col: Color, amount := 16, speed := 180.0, life := 0.4, up := 0.0, size := 7.0) -> void:
	var p := CPUParticles2D.new()
	p.position = at
	p.texture = glow_tex
	p.material = add_mat
	p.amount = amount
	p.lifetime = life
	p.one_shot = true
	p.explosiveness = 0.92
	p.spread = 180.0
	p.direction = Vector2(0, -1)
	p.initial_velocity_min = speed * 0.45
	p.initial_velocity_max = speed
	p.gravity = Vector2(0, -up * 2.0 if up != 0.0 else 260.0)
	p.damping_min = 40.0
	p.damping_max = 120.0
	p.scale_amount_min = size / 64.0 * 1.2
	p.scale_amount_max = size / 64.0 * 2.6
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 16.0
	var ramp := Gradient.new()
	ramp.set_color(0, Color(col.lightened(0.35), 1.0))
	ramp.set_color(1, Color(col, 0.0))
	p.color_ramp = ramp
	add_child(p)
	p.emitting = true
	get_tree().create_timer(life + 0.1).timeout.connect(p.queue_free)


func slash(at: Vector2, dir: Vector2, col: Color, heavy := false) -> Tween:
	burst(at, col, 10 if heavy else 6, 220.0, 0.28, 0.0, 6.0)
	if heavy:
		_shape("cross", at, col, 0.32, {"radius": 46.0})
	return _shape("slash", at, col, 0.3, {"dir": dir, "radius": 62.0 if heavy else 50.0})


func streak(from: Vector2, dir: Vector2, length: float, col: Color) -> Tween:
	return _shape("streak", from, col, 0.3, {"dir": dir, "length": length})


## Short stabbing streak that ends on the target (dagger / quick jab).
func jab(at: Vector2, dir: Vector2, col: Color) -> Tween:
	burst(at, col, 5, 200.0, 0.22, 0.0, 5.0)
	return _shape("streak", at - dir * 70.0, col, 0.2, {"dir": dir, "length": 90.0})


## Blunt impact: radiating star lines plus a dust ring (staff, shield bash, knockback).
func impact(at: Vector2, col: Color, heavy := false) -> Tween:
	burst(at, col, 12 if heavy else 7, 240.0 if heavy else 160.0, 0.3, 0.0, 6.0)
	if heavy:
		ring(at + Vector2(0, 50), Color(0.85, 0.75, 0.55), 110.0, 0.35)
	return _shape("star", at, col, 0.3, {"radius": 70.0 if heavy else 52.0})


## Overhead chop that slams down onto the target, kicking up ground debris.
func chop(at: Vector2, dir: Vector2, col: Color) -> Tween:
	burst(at + Vector2(0, 50), Color(0.75, 0.62, 0.45), 12, 200.0, 0.35, 0.0, 7.0)
	ring(at + Vector2(0, 55), col, 100.0, 0.32)
	return _shape("chop", at, col, 0.32, {"dir": dir, "radius": 70.0})


func ring(at: Vector2, col: Color, radius := 80.0, dur := 0.4) -> Tween:
	return _shape("ring", at, col, dur, {"radius": radius})


func tile_flash(at: Vector2, col: Color, dur := 0.38) -> Tween:
	return _shape("diamond", at, col, dur)


func shield(at: Vector2, col: Color) -> Tween:
	glow(at, col, 1.6, 0.4)
	return _shape("shield", at, col, 0.45, {"radius": 46.0})


func wind(at: Vector2, col: Color) -> Tween:
	burst(at + Vector2(0, 40), col, 12, 140.0, 0.35, 0.0, 6.0)
	return _shape("wind", at, col, 0.35)


func pillar(at: Vector2, col: Color) -> Tween:
	burst(at + Vector2(0, -30), col, 14, 90.0, 0.5, 120.0, 8.0)
	return _shape("pillar", at, col, 0.45, {"radius": 56.0, "length": 150.0})


## Flies a projectile from `from` to `to`; resolves at impact. style: "arrow" (arcs), "orb", "fireball".
func projectile(from: Vector2, to: Vector2, style: String, col: Color) -> void:
	var s := Shape.new()
	s.col = col
	var arc := 0.0
	if style == "arrow":
		s.kind = "arrow"
		arc = clampf(from.distance_to(to) * 0.28, 40.0, 140.0)
	else:
		s.kind = "orb"
		s.radius = 20.0 if style == "fireball" else 14.0
	s.position = from
	add_child(s)
	var trail: CPUParticles2D = null
	if style != "arrow":
		trail = CPUParticles2D.new()
		trail.texture = glow_tex
		trail.material = add_mat
		trail.amount = 24
		trail.lifetime = 0.25
		trail.local_coords = false
		trail.spread = 180.0
		trail.initial_velocity_min = 10.0
		trail.initial_velocity_max = 40.0
		trail.gravity = Vector2(0, -60 if style == "fireball" else 0)
		trail.scale_amount_min = 0.12
		trail.scale_amount_max = 0.3
		var ramp := Gradient.new()
		ramp.set_color(0, Color(col.lightened(0.3), 0.9))
		ramp.set_color(1, Color(col, 0.0))
		trail.color_ramp = ramp
		s.add_child(trail)
	var dur := clampf(from.distance_to(to) / 1500.0, 0.16, 0.34)
	var fly := func(k: float) -> void:
		var p := from.lerp(to, k) + Vector2(0, -arc * 4.0 * k * (1.0 - k))
		var d := p - s.position
		if d.length() > 0.5:
			s.dir = d.normalized()
		s.position = p
		s.queue_redraw()
	var tw := s.create_tween()
	tw.tween_method(fly, 0.0, 1.0, dur)
	await tw.finished
	s.queue_free()
	glow(to, col, 1.0 if style != "fireball" else 1.8, 0.25)


## Floating number / short text: pops in, rises and fades (~0.7 s, never awaited by the battle).
## `tag` is an optional small caption above it (e.g. "背后").
func number(at: Vector2, text: String, col: Color, big := false, tag := "") -> void:
	var box := Node2D.new()
	box.position = at
	add_child(box)
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 64 if big else 48)
	l.add_theme_color_override("font_color", col)
	l.add_theme_constant_override("outline_size", 14)
	l.add_theme_color_override("font_outline_color", Color(0.06, 0.03, 0.08))
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.size = Vector2(300, 80)
	l.position = Vector2(-150, -40)
	l.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	box.add_child(l)
	if tag != "":
		var tl := Label.new()
		tl.text = tag
		tl.add_theme_font_size_override("font_size", 30)
		tl.add_theme_color_override("font_color", col.lightened(0.3))
		tl.add_theme_constant_override("outline_size", 10)
		tl.add_theme_color_override("font_outline_color", Color(0.06, 0.03, 0.08))
		tl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		tl.size = Vector2(300, 44)
		tl.position = Vector2(-150, -86 if big else -78)
		tl.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		box.add_child(tl)
	box.scale = Vector2.ONE * 1.7
	var tw := box.create_tween()
	tw.tween_property(box, "scale", Vector2.ONE, 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(box, "position:y", at.y - 22.0, 0.14)
	tw.tween_property(box, "position:y", at.y - 70.0, 0.55).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(box, "modulate:a", 0.0, 0.3).set_delay(0.25)
	tw.tween_callback(box.queue_free)
