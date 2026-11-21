extends Node2D
## Lively water effect for the player:
##  - a WAVY foam line across him that keeps rolling
##  - foam puffs at both sides that bob
##  - a V-shaped wake trailing behind him when he walks
##  - sparkles, rising bubbles, and a SPLASH when he steps into the water
## Put this as a child of Player at (0, 0), BELOW AnimatedSprite2D in the scene tree.
## player.gd sets: active (in water), moving (walking), move_dir (walk direction).

@export var line_width := 14.0
@export var foam := Color(0.86, 0.96, 0.95)          # bright foam
@export var foam_shade := Color(0.52, 0.78, 0.80)    # darker water just under the foam
@export var shine := Color(1, 1, 1)

var active := false
var moving := false
var move_dir := Vector2.ZERO

var _t := 0.0
var _was_active := false
var _wake_dir := Vector2.ZERO
var _bubbles: CPUParticles2D
var _splash: CPUParticles2D
var _rng := RandomNumberGenerator.new()


func _px() -> ImageTexture:
	var img := Image.create(1, 1, false, Image.FORMAT_RGBA8)
	img.set_pixel(0, 0, Color.WHITE)
	return ImageTexture.create_from_image(img)


func _ready() -> void:
	var tex := _px()
	# rising bubbles
	_bubbles = CPUParticles2D.new()
	_bubbles.texture = tex
	_bubbles.amount = 8
	_bubbles.lifetime = 0.9
	_bubbles.local_coords = false
	_bubbles.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_bubbles.emission_rect_extents = Vector2(line_width / 2.0, 1)
	_bubbles.direction = Vector2(0, -1)
	_bubbles.spread = 20.0
	_bubbles.gravity = Vector2(0, -6)
	_bubbles.initial_velocity_min = 3.0
	_bubbles.initial_velocity_max = 8.0
	_bubbles.scale_amount_min = 1.0
	_bubbles.scale_amount_max = 2.0
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.6, 1.0])
	ramp.colors = PackedColorArray([Color(0.9, 1, 1, 0.95), Color(0.75, 0.93, 0.95, 0.7), Color(0.75, 0.93, 0.95, 0.0)])
	_bubbles.color_ramp = ramp
	_bubbles.emitting = false
	add_child(_bubbles)

	# one-shot splash when he steps into the water
	_splash = CPUParticles2D.new()
	_splash.texture = tex
	_splash.amount = 14
	_splash.lifetime = 0.55
	_splash.one_shot = true
	_splash.explosiveness = 0.9
	_splash.local_coords = false
	_splash.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_splash.emission_rect_extents = Vector2(line_width / 2.0, 1)
	_splash.direction = Vector2(0, -1)
	_splash.spread = 55.0
	_splash.gravity = Vector2(0, 140)
	_splash.initial_velocity_min = 25.0
	_splash.initial_velocity_max = 45.0
	_splash.scale_amount_min = 1.0
	_splash.scale_amount_max = 2.0
	var sr := Gradient.new()
	sr.offsets = PackedFloat32Array([0.0, 0.7, 1.0])
	sr.colors = PackedColorArray([Color(1, 1, 1, 1), Color(0.8, 0.95, 0.95, 0.8), Color(0.8, 0.95, 0.95, 0)])
	_splash.color_ramp = sr
	_splash.emitting = false
	add_child(_splash)


func _process(delta: float) -> void:
	_t += delta * (9.0 if moving else 4.0)
	if active and not _was_active:
		_splash.restart()                 # splash!
		_splash.emitting = true
	_was_active = active
	_bubbles.emitting = active
	_wake_dir = _wake_dir.lerp(move_dir if moving else Vector2.ZERO, 1.0 - exp(-6.0 * delta))
	queue_redraw()


func _dot(p: Vector2, c: Color) -> void:
	draw_rect(Rect2(Vector2(roundf(p.x), roundf(p.y)), Vector2.ONE), c)


func _draw() -> void:
	if not active:
		return
	var half := int(line_width / 2.0)

	# --- V-shaped wake behind him while walking ---
	var wk := _wake_dir.length()
	if wk > 0.1:
		var back := -_wake_dir.normalized()
		var side := Vector2(-back.y, back.x)
		for arm in [-1.0, 1.0]:
			for i in range(1, 9):
				var f := float(i) / 8.0
				# arms spread out behind him and wiggle a little
				var p: Vector2 = back * (2.0 + i * 1.6) + side * arm * (half * 0.6 + i * 1.1)
				p.y = p.y * 0.5 - 1.0 + sin(_t * 0.8 + i) * 0.4
				var a := (1.0 - f) * 0.75 * wk
				if (i + int(_t)) % 3 != 0:                 # broken, moving segments
					_dot(p, Color(foam, a))

	# --- wavy foam line (rolls along) ---
	for x in range(-half, half + 1):
		var w := sin(x * 0.9 + _t) * 0.6 + sin(x * 0.4 - _t * 0.7) * 0.4
		var y := -1.0 + roundf(w)
		_dot(Vector2(x, y + 1), Color(foam_shade, 0.85))   # darker water just below the foam
		var c := foam
		var s := int(_t * 1.3) % (half * 2 + 1) - half     # sliding glints
		if x == s or x == s - 6 or x == s + 6:
			c = shine
		_dot(Vector2(x, y), c)

	# --- bobbing foam puffs at both sides ---
	for sgn in [-1, 1]:
		var bob := roundf(sin(_t * 0.9 + sgn) * 0.6)
		var cx: int = sgn * (half + 1)
		_dot(Vector2(cx, -1 + bob), foam)
		_dot(Vector2(cx + sgn, 0 + bob), Color(foam, 0.9))
		_dot(Vector2(cx, 0 + bob), Color(foam_shade, 0.9))
		if int(_t * 0.5 + (1 if sgn > 0 else 0)) % 2 == 0:
			_dot(Vector2(cx + sgn * 2, 0 + bob), Color(foam, 0.6))   # little spray pixel

	# --- random twinkle on the water around him ---
	_rng.seed = int(_t * 2.0)
	if _rng.randf() < 0.6:
		var tx := _rng.randi_range(-half - 4, half + 4)
		var ty := _rng.randi_range(0, 2)
		_dot(Vector2(tx, ty), Color(shine, 0.8))
