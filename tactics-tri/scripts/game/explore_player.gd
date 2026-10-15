extends CharacterBody2D
## Feet are the world position; art extends upward from the collision circle.

var facing := "S"
var blocked := false
var sprite: Sprite2D
var textures := {}
var walk_time := 0.0


func _ready() -> void:
	collision_layer = 2
	collision_mask = 1
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = ExplorationRules.BODY_RADIUS
	shape.shape = circle
	add_child(shape)
	for view in ["S", "SW", "W", "N"]:
		textures[view] = load("res://assets/units/dirs/swordsman_player_%s.png" % view)
	sprite = Sprite2D.new()
	sprite.centered = false
	sprite.scale = Vector2.ONE * 0.52
	sprite.position = Vector2(-80, -196) * 0.52
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(sprite)
	_update_facing()


func _physics_process(delta: float) -> void:
	var direction := Vector2.ZERO if blocked else Input.get_vector("explore_left", "explore_right", "explore_up", "explore_down")
	velocity = ExplorationRules.movement_velocity(direction)
	if direction != Vector2.ZERO:
		var directions := ["E", "SE", "S", "SW", "W", "NW", "N", "NE"]
		facing = directions[posmod(roundi(direction.angle() / (PI / 4.0)), 8)]
		_update_facing()
	move_and_slide()
	walk_time += delta * 14 if velocity.length() > 1 else 0.0
	sprite.position.y = -196 * 0.52 - (absf(sin(walk_time)) * 2 if velocity.length() > 1 else 0.0)
	queue_redraw()


func _update_facing() -> void:
	var view := "N" if facing in ["N", "NE", "NW"] else ("W" if facing in ["W", "E"] else ("SW" if facing in ["SW", "SE"] else "S"))
	sprite.texture = textures[view]
	sprite.flip_h = facing in ["NE", "E", "SE"]


func _draw() -> void:
	draw_ellipse_shadow()


func draw_ellipse_shadow() -> void:
	draw_set_transform(Vector2(0, -1), 0, Vector2(1, 0.4))
	draw_circle(Vector2.ZERO, 19, Color(0.05, 0.09, 0.08, 0.4))
	draw_arc(Vector2.ZERO, 23, 0, TAU, 28, UIKit.ALLY, 2)
	draw_set_transform(Vector2.ZERO)
