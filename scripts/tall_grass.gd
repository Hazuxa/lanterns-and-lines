extends Area2D
## Tall grass: sways all the time, rustles when the player walks into it,
## keeps rustling while he moves inside it, and rustles once more when he leaves.

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

var player_inside: CharacterBody2D = null
var cooldown := 0.0


func _ready() -> void:
	sprite.play("idle")
	sprite.frame = randi() % sprite.sprite_frames.get_frame_count("idle")  # not all in sync
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	sprite.animation_finished.connect(_on_animation_finished)


func _process(delta: float) -> void:
	cooldown -= delta
	# keep rustling while the player is walking inside the grass
	if player_inside and player_inside.velocity.length() > 5.0 and cooldown <= 0.0:
		_rustle()


func _on_body_entered(body: Node) -> void:
	if body is CharacterBody2D:
		player_inside = body
		_rustle()
		var shadow := body.get_node_or_null("Shadows/SunShadow")
		if shadow and shadow.has_method("enter_cover"):
			shadow.enter_cover()


func _on_body_exited(body: Node) -> void:
	if body == player_inside:
		player_inside = null
		_rustle()
		var shadow := body.get_node_or_null("Shadows/SunShadow")
		if shadow and shadow.has_method("exit_cover"):
			shadow.exit_cover()

func _rustle() -> void:
	if sprite.animation != "rustle":
		sprite.play("rustle")
		cooldown = 0.35


func _on_animation_finished() -> void:
	if sprite.animation == "rustle":
		sprite.play("idle")
