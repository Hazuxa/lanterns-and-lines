xtends TextureRect
## Soft sun rays overlay that gently breathes and drifts.
## Put it under a CanvasLayer so it stays on screen while the camera moves.

@export var base_alpha := 0.9
@export var pulse := 0.12        # how much the rays fade in and out
@export var drift_speed := 4.0   # pixels per second the beams slide

var _t := 0.0

func _ready() -> void:
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD     # light gets ADDED on top
	material = mat
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _process(delta: float) -> void:
	_t += delta
	modulate.a = base_alpha + sin(_t * 0.6) * pulse
	position.x = sin(_t * 0.15) * drift_speed * 4.0
