extends Area2D
## Tall grass that sways all the time and rustles when the player walks through.
## Scene setup:
##   TallGrass (Area2D, this script)
##   |- AnimatedSprite2D   animations: "idle" (8 frames, loop, 8 FPS)
##   |                                 "rustle" (4 frames, NO loop, 12 FPS)
##   |- CollisionShape2D   small rectangle at the base of the grass

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

func _ready() -> void:
	sprite.play("idle")
	sprite.frame = randi() % 8          # so a field of grass doesn't sway in sync
	body_entered.connect(_on_body_entered)
	sprite.animation_finished.connect(_on_animation_finished)

func _on_body_entered(body: Node) -> void:
	if body is CharacterBody2D:         # the player walked into the grass
		sprite.play("rustle")

func _on_animation_finished() -> void:
	if sprite.animation == "rustle":
		sprite.play("idle")
