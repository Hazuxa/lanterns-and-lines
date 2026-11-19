extends CharacterBody2D

const SPEED := 60.0
const IDLE_DELAY := 5.0  # seconds standing still before a fun idle plays
const SPECIAL_IDLES := ["blink", "look_around", "yawn", "sweat"]

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

var facing := "down"        # "down", "left" or "right"
var idle_timer := 0.0
var playing_special := false


func _ready() -> void:
	sprite.animation_finished.connect(_on_animation_finished)


func _physics_process(delta: float) -> void:
	var dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	velocity = dir * SPEED
	move_and_slide()

	if dir != Vector2.ZERO:
		_walk(dir)
	else:
		_stand_still(delta)


func _walk(dir: Vector2) -> void:
	playing_special = false
	idle_timer = 0.0
	if dir.x > 0:
		facing = "right"
	elif dir.x < 0:
		facing = "left"
	else:
		facing = "down"   # moving straight up/down uses the front walk
	_play("walk_" + facing)


func _stand_still(delta: float) -> void:
	if playing_special:
		return
	_play("idle" if facing == "down" else "idle_" + facing)

	idle_timer += delta
	if idle_timer >= IDLE_DELAY:
		idle_timer = 0.0
		playing_special = true
		facing = "down"
		sprite.play(SPECIAL_IDLES.pick_random())


func _on_animation_finished() -> void:
	if playing_special:
		playing_special = false
		idle_timer = 0.0


func _play(anim: String) -> void:
	if sprite.animation != anim:
		sprite.play(anim)
