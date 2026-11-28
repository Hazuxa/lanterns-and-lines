extends ColorRect
## Drifting cloud shadows over the world. Child of the Camera2D, covers the screen.
## Also makes ground shadows fade where a cloud passes (via the ShadowLayer).

@export var fade_speed := 0.4               # how fast it changes at sunrise / sunset
@export var shadow_shader: Shader           # drag shadow_clouds.gdshader here
@export_range(0.0, 1.0) var cloud_fade := 0.75   # how much ground shadows fade under clouds

const SHARED := ["noise", "scale", "direction", "speed", "coverage", "softness"]

var _night := 0.0
var _sent := -1.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_as_relative = false
	z_index = 50
	var vs := get_viewport_rect().size
	size = vs + Vector2(64, 64)
	position = -size / 2.0
	_setup_shadow_layer.call_deferred()


func _setup_shadow_layer() -> void:
	var layer := get_tree().get_first_node_in_group("shadow_layer") as CanvasItem
	if layer == null or shadow_shader == null:
		return
	var m := ShaderMaterial.new()
	m.shader = shadow_shader
	var mine := material as ShaderMaterial
	for p in SHARED:                          # same clouds as the cloud shadows
		var v = mine.get_shader_parameter(p)
		if v != null:
			m.set_shader_parameter(p, v)
	m.set_shader_parameter("cloud_fade", cloud_fade)
	layer.material = m


func _process(delta: float) -> void:
	var target := 0.0
	var dn := get_tree().get_first_node_in_group("day_night")
	if dn:
		var sun_h := sin((dn.time_of_day - 0.25) * TAU)
		target = 1.0 - smoothstep(-0.05, 0.2, sun_h)
	_night = move_toward(_night, target, delta * fade_speed)
	if absf(_night - _sent) > 0.005:
		_sent = _night
		(material as ShaderMaterial).set_shader_parameter("night", _night)
