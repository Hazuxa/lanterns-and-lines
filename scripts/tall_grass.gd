extends Area2D
## Tall grass that sways and rustles when the player walks through.
## At NIGHT, rustling the grass has a chance to make fireflies pop out of it.
## Scene:
##   TallGrass (Area2D, this script)
##   |- SunShadow / CollisionShape2D
##   |- AnimatedSprite2D   "idle" (loop) + "rustle" (no loop)

@export_group("Rustle")
@export var rustle_again_every := 0.35     # while walking inside, rustle again this often

@export_group("Fireflies at night")
@export_range(0.0, 1.0) var firefly_chance := 0.25  # chance per rustle at night
@export var min_fireflies := 1
@export var max_fireflies := 2
@export var firefly_cooldown := 10.0       # seconds before THIS grass can release more

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

var _player: Node2D = null
var _rustle_timer := 0.0
var _firefly_timer := 0.0


func _ready() -> void:
	sprite.play("idle")
	sprite.frame = randi() % sprite.sprite_frames.get_frame_count("idle")
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	sprite.animation_finished.connect(_on_animation_finished)
	set_process(false)                      # only needs to run while the player is inside
	_warm_up()


func _on_body_entered(body: Node) -> void:
	if body is CharacterBody2D:
		_player = body
		set_process(true)
		_rustle()


func _on_body_exited(body: Node) -> void:
	if body == _player:
		_player = null
		set_process(false)
		_rustle()


func _process(delta: float) -> void:
	_rustle_timer -= delta
	# keep rustling while he walks around inside the grass
	if _player and (_player as CharacterBody2D).velocity.length() > 5.0 and _rustle_timer <= 0.0:
		_rustle()


func _rustle() -> void:
	_rustle_timer = rustle_again_every
	sprite.play("rustle")
	_maybe_fireflies()


func _on_animation_finished() -> void:
	if sprite.animation == "rustle":
		sprite.play("idle")


func _maybe_fireflies() -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if now < _firefly_timer or not _is_night():
		return
	if randf() > firefly_chance:
		return
	_firefly_timer = now + firefly_cooldown
	var n := randi_range(min_fireflies, max_fireflies)
	for i in n:
		var f := PopFirefly.new()
		f.center = global_position                 # it circles THIS grass clump
		f.position = position + Vector2(randf_range(-4, 4), randf_range(-1, 1))
		get_parent().add_child.call_deferred(f)    # same Y-sorted parent as the grass (Objects)


static var _warmed := false

## draws one invisible firefly for a moment at the start, so Godot prepares the glow shader
## right away instead of freezing the first time a firefly appears
func _warm_up() -> void:
	if _warmed:
		return
	_warmed = true
	var f := PopFirefly.new()
	f.modulate.a = 0.0
	f.center = global_position
	f.position = position
	get_parent().add_child.call_deferred(f)
	get_tree().create_timer(0.3).timeout.connect(f.queue_free)


func _is_night() -> bool:
	var dn := get_tree().get_first_node_in_group("day_night")
	return dn != null and dn.has_method("is_night") and dn.is_night()
