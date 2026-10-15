extends CharacterBody2D

## 挂到探索场景的 Player (CharacterBody2D)。
## Input Map 添加 move_left / move_right / move_up / move_down。
## 此控制器只用于实时探索，不用于AP战棋。

@export var walk_speed: float = 130.0
@export var acceleration: float = 900.0
@export var deceleration: float = 1200.0

var input_locked: bool = false
var facing: Vector2 = Vector2.DOWN

func _physics_process(delta: float) -> void:
    var direction: Vector2 = Vector2.ZERO
    if not input_locked:
        direction = Input.get_vector(
            "move_left", "move_right", "move_up", "move_down"
        )

    if direction.length_squared() > 0.001:
        facing = direction

    var target_velocity: Vector2 = direction * walk_speed
    var change_rate: float = acceleration if direction != Vector2.ZERO else deceleration
    velocity = velocity.move_toward(target_velocity, change_rate * delta)
    move_and_slide()

func set_input_locked(value: bool) -> void:
    input_locked = value
    if value:
        velocity = Vector2.ZERO
