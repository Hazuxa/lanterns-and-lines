extends StaticBody2D

@export var fade_alpha := 0.45      # how see-through the leaves get
@export var fade_speed := 8.0

@onready var sprite: Sprite2D = $Sprite
@onready var canopy: Area2D = $Canopy

var player: Node2D = null           # the player while he's inside the leaves area


func _ready() -> void:
	canopy.body_entered.connect(_on_enter)
	canopy.body_exited.connect(_on_exit)


func _on_enter(body: Node2D) -> void:
	if body.name == "Player":
		player = body


func _on_exit(body: Node2D) -> void:
	if body == player:
		player = null


func _process(delta: float) -> void:
	var target := 1.0
	# checked every frame: fade only while he's inside AND behind the trunk
	if player and player.global_position.y < global_position.y:
		target = fade_alpha
	sprite.modulate.a = lerpf(sprite.modulate.a, target, 1.0 - exp(-fade_speed * delta))
