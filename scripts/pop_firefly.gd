class_name PopFirefly
extends Node2D
## A tiny firefly that pops out of the grass, circles AROUND the clump (in front of it and
## behind it), floating up high, blinking, then drifts away and fades.
## OPTIMIZED: it's just one small Sprite2D with a pre-made glow picture - no drawing code,
## no lights. The node sits on the ground (for Y-sort); the glow is raised by `_alt`.

const COLORS := [Color(0.85, 1.0, 0.45), Color(1.0, 0.9, 0.45), Color(0.65, 1.0, 0.7)]
static var _mat: CanvasItemMaterial
static var _tex: ImageTexture

var center := Vector2.ZERO          # the grass clump it circles (set by tall_grass.gd)

var _spr: Sprite2D
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


static func _glow_texture() -> ImageTexture:
	# 15x15: soft round glow with a bright 1px middle. Made once, shared by every firefly.
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


static func shared_material() -> CanvasItemMaterial:
	if _mat == null:
		_mat = CanvasItemMaterial.new()
		_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		_mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	return _mat


func _ready() -> void:
	_col = COLORS[randi() % COLORS.size()]
	_spr = Sprite2D.new()
	_spr.texture = _glow_texture()
	_spr.material = shared_material()
	_spr.modulate = Color(_col, 0.0)
	add_child(_spr)
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
			_alt_goal = randf_range(18.0, 32.0)          # floats up and down, but stays high
		if _age > _life:
			_leaving = true
			_leave_dir = Vector2(randf_range(-1, 1), randf_range(-0.6, 0.2)).normalized()
	else:
		position += _leave_dir * 10.0 * delta
		_alt_goal += 10.0 * delta

	var pop := 1.0 - exp(-6.0 * _age)
	_alt = lerpf(_alt, _alt_goal, 1.0 - exp(-2.0 * delta)) * pop + 4.0 * (1.0 - pop)
	_spr.position = Vector2(0, -roundf(_alt))

	var b := 0.6 + 0.4 * sin(_age * _blink + _phase)
	if fmod(_age + _phase, 3.7) < 0.3:
		b *= 0.25
	var fade := clampf(_age / 0.3, 0.0, 1.0)
	if _leaving:
		fade *= clampf(1.0 - (_age - _life) / 2.5, 0.0, 1.0)
		if fade <= 0.0:
			queue_free()
	_spr.modulate = Color(_col, b * fade)
