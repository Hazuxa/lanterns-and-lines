extends AnimatedSprite2D

@export var shadow_offset := Vector2(1, 2)      # how far the shadow sits from the pad
@export var shadow_color := Color(0, 0.1, 0.2, 0.35)   # dark blue, see-through (looks right on water)

var _shadow: AnimatedSprite2D


func _ready() -> void:
	frame = randi() % sprite_frames.get_frame_count(animation)
	speed_scale = randf_range(0.8, 1.2)
	play()

	# a darker copy of the pad, drawn BEHIND it
	_shadow = AnimatedSprite2D.new()
	_shadow.sprite_frames = sprite_frames
	_shadow.animation = animation
	_shadow.position = shadow_offset
	_shadow.modulate = shadow_color
	_shadow.show_behind_parent = true
	add_child(_shadow)


func _process(_delta: float) -> void:
	# keep the shadow on the same frame so it bobs with the pad
	_shadow.frame = frame
	_shadow.flip_h = flip_h
