extends Area2D
## Tall grass that rustles naturally when the player walks through (the shader does the bending).
## A rustle ALWAYS plays to its last frame - new rustles wait for it instead of cutting it off.
## At NIGHT, rustling the grass has a chance to make fireflies pop out of it.
## Scene:
##   TallGrass (Area2D, this script)
##   |- SunShadow / CollisionShape2D
##   |- AnimatedSprite2D   "idle" (loop) + "rustle" (no loop)   <- has the grass shader material

@export_group("Rustle")
@export var step_distance := 6.0           # rustle again after he walks this many px inside
@export var speed_variation := 0.12        # each rustle plays a bit faster/slower (0.12 = ±12%)

@export_group("Fireflies at night")
@export_range(0.0, 1.0) var firefly_chance := 0.25  # chance per rustle at night
@export var min_fireflies := 1
@export var max_fireflies := 2
@export var firefly_cooldown := 10.0       # seconds before THIS grass can release more

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

var _player: CharacterBody2D = null
var _last_pos := Vector2.ZERO
var _firefly_timer := 0.0
var _queued := false                       # another rustle is waiting for this one to finish
var _queued_strength := 1.0


func _ready() -> void:
	sprite.play("idle")
	sprite.frame = randi() % sprite.sprite_frames.get_frame_count("idle")
	sprite.speed_scale = randf_range(0.9, 1.1)          # idle sway not in sync with neighbours
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	sprite.animation_finished.connect(_on_animation_finished)
	set_process(false)                      # only runs while the player is inside
	_warm_up()


func _on_body_entered(body: Node) -> void:
	if body is CharacterBody2D:
		_player = body
		_last_pos = _player.global_position
		set_process(true)
		_rustle(1.0)


func _on_body_exited(body: Node) -> void:
	if body == _player:
		_player = null
		set_process(false)
		_rustle(0.85)                       # softer one as he leaves (waits if one is playing)


func _process(_delta: float) -> void:
	# rustle by STEPS: standing still = no new rustle, walking = keeps rustling
	if _player and _player.global_position.distance_to(_last_pos) >= step_distance:
		_last_pos = _player.global_position
		_rustle(1.0)


func _rustle(strength: float) -> void:
	if sprite.animation == "rustle" and sprite.is_playing():
		_queued = true                      # never cut it off - play again right after it ends
		_queued_strength = strength
		return
	_start_rustle(strength)


func _start_rustle(strength: float) -> void:
	sprite.speed_scale = strength * randf_range(1.0 - speed_variation, 1.0 + speed_variation)
	sprite.play("rustle")
	_maybe_fireflies()


func _on_animation_finished() -> void:
	if sprite.animation != "rustle":
		return
	if _queued:
		_queued = false
		_start_rustle(_queued_strength)     # he kept walking: flow straight into the next rustle
	else:
		sprite.play("idle")
		sprite.frame = randi() % sprite.sprite_frames.get_frame_count("idle")
		sprite.speed_scale = randf_range(0.9, 1.1)


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
