class_name PopFirefly
extends Node2D
## A tiny firefly that pops out of the grass, circles AROUND the clump, floats up high,
## blinks, then drifts away and fades. It lights up the area a little (fake light, no Light2D)
## and also tells the grass shader where it is, so nearby grass gets lit too.
## The node sits on the ground (for Y-sort); the glow is raised by `_alt`.

const COLORS := [Color(0.85, 1.0, 0.45), Color(1.0, 0.9, 0.45), Color(0.65, 1.0, 0.7)]
const HALO_SIZE := 0.6              # size of the light (0.45 smaller - 1.0 bigger)
const HALO_STRENGTH := 0.15         # brightness of the light around it
const POOL_STRENGTH := 0.08         # brightness of the light on the ground
const MAX_LIGHTS := 4               # how many fireflies can light the grass at once

static var _mat: CanvasItemMaterial
static var _tex: ImageTexture
static var _light_tex: GradientTexture2D
static var _active: Array = []      # fireflies alive right now (for the grass light)

var center := Vector2.ZERO          # the grass clump it circles (set by tall_grass.gd)

var _spr: Sprite2D
var _halo: Sprite2D
var _pool: Sprite2D
var _angle := 0.0
var _spin := 1.0
var _rx := 10.0
var _ry := 4.0
var _alt := 4.0
var _alt_goal := 22.0
var _age := 0.0
var _life := 12.0
var _phase := 0.0
var _blink := 3.0
var _col := Color(0.85, 1.0, 0.45)
var _leaving := false
var _leave_dir := Vector2.ZERO
var _level := 0.0                   # how bright it is right now (sent to the grass)


static func _glow_texture() -> ImageTexture:
	if _tex == null:
		var img := Image.create(15, 15, false, Image.FORMAT_RGBA8)
		for y in 15:
			for x in 15:
				var d := Vector2(x - 7, y - 7).length() / 7.5
				var a := clampf(1.0 - d, 0.0, 1.0)
				a = a * a * 0.45
				img.set_pixel(x, y, Color(1, 1, 1, a))
		img.set_pixel(7, 7, Color(1, 1, 1, 1))
		_tex = ImageTexture.create_from_image(img)
	return _tex


static func _light_texture() -> GradientTexture2D:
	if _light_tex == null:
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.set_color(1, Color(1, 1, 1, 0))
		g.add_point(0.35, Color(1, 1, 1, 0.45))
		_light_tex = GradientTexture2D.new()
		_light_tex.gradient = g
		_light_tex.fill = GradientTexture2D.FILL_RADIAL
		_light_tex.fill_from = Vector2(0.5, 0.5)
		_light_tex.fill_to = Vector2(1.0, 0.5)
		_light_tex.width = 48
		_light_tex.height = 48
	return _light_tex


static func shared_material() -> CanvasItemMaterial:
	if _mat == null:
		_mat = CanvasItemMaterial.new()
		_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		_mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	return _mat


func _make_sprite(tex: Texture2D) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = tex
	s.material = shared_material()
	s.modulate = Color(_col, 0.0)
	add_child(s)
	return s


func _enter_tree() -> void:
	_active.append(self)


func _exit_tree() -> void:
	_active.erase(self)
	if _active.is_empty():
		_send_lights()                       # turn the grass light off when the last one leaves


func _ready() -> void:
	_col = COLORS[randi() % COLORS.size()]
	_pool = _make_sprite(_light_texture())
	_pool.scale = Vector2(0.9, 0.4) * HALO_SIZE
	_pool.z_index = -1
	_halo = _make_sprite(_light_texture())
	_halo.scale = Vector2.ONE * HALO_SIZE
	_spr = _make_sprite(_glow_texture())
	_life = randf_range(9.0, 15.0)
	_phase = randf() * TAU
	_blink = randf_range(2.0, 3.5)
	_angle = randf() * TAU
	_spin = (1.0 if randf() < 0.5 else -1.0) * randf_range(0.7, 1.2)
	_rx = randf_range(7.0, 13.0)
	_ry = randf_range(3.0, 5.0)
	_alt_goal = randf_range(18.0, 30.0)


func _process(delta: float) -> void:
	_age += delta
	if not _leaving:
		_angle += _spin * delta
		if randf() < 0.004:
			_spin = -_spin
		var wob := sin(_age * 1.7 + _phase) * 2.0
		var target := center + Vector2(cos(_angle) * (_rx + wob), sin(_angle) * (_ry + wob * 0.4))
		position = position.lerp(target - get_parent().global_position if get_parent() is Node2D else target,
				1.0 - exp(-4.0 * delta))
		if randf() < 0.008:
			_alt_goal = randf_range(18.0, 32.0)
		if _age > _life:
			_leaving = true
			_leave_dir = Vector2(randf_range(-1, 1), randf_range(-0.6, 0.2)).normalized()
	else:
		position += _leave_dir * 10.0 * delta
		_alt_goal += 10.0 * delta

	var pop := 1.0 - exp(-6.0 * _age)
	_alt = lerpf(_alt, _alt_goal, 1.0 - exp(-2.0 * delta)) * pop + 4.0 * (1.0 - pop)
	_spr.position = Vector2(0, -roundf(_alt))
	_halo.position = _spr.position

	var b := 0.6 + 0.4 * sin(_age * _blink + _phase)
	if fmod(_age + _phase, 3.7) < 0.3:
		b *= 0.25
	var fade := clampf(_age / 0.3, 0.0, 1.0)
	if _leaving:
		fade *= clampf(1.0 - (_age - _life) / 2.5, 0.0, 1.0)
		if fade <= 0.0:
			queue_free()
	var a := b * fade
	var near := clampf(1.0 - _alt / 40.0, 0.35, 1.0)
	_spr.modulate = Color(_col, a)
	_halo.modulate = Color(_col, a * HALO_STRENGTH)
	_pool.modulate = Color(_col, a * POOL_STRENGTH * near)
	_level = a * modulate.a                  # the invisible warm-up firefly gives no light

	if not _active.is_empty() and _active[0] == self:
		_send_lights()                       # one firefly sends everyone's light, once per frame


static func _send_lights() -> void:
	for i in MAX_LIGHTS:
		var v := Vector3.ZERO
		if i < _active.size() and is_instance_valid(_active[i]):
			var f: PopFirefly = _active[i]
			var p := f.global_position + f._spr.position if f._spr else f.global_position
			v = Vector3(p.x, p.y, f._level)
		RenderingServer.global_shader_parameter_set("ff_light%d" % i, v)
