extends Node2D
## Lively main-menu sky - OPTIMIZED version.
## Everything is a small Sprite2D with a picture made ONCE at the start.
## Every frame we only move sprites and change their brightness (very cheap) -
## no drawing code runs each frame.
##  - twinkling stars, drifting clouds, a shooting star now and then
##  - SKY LANTERNS slowly rising and swaying
## Put this Node2D right after Background in main_menu.tscn.

@export_group("Stars")
@export var star_count := 30
@export var sky_height := 0.55
@export_group("Lanterns")
@export var max_lanterns := 6
@export var lantern_every_min := 2.5
@export var lantern_every_max := 5.0
@export_group("Clouds")
@export var cloud_count := 3
@export var cloud_speed := 4.0
@export_group("Shooting stars")
@export var shooting_every_min := 7.0
@export var shooting_every_max := 15.0

var _t := 0.0
var _size := Vector2(480, 270)
var _stars: Array = []        # [sprite, phase, speed]
var _clouds: Array = []       # [sprite, speed]
var _lanterns: Array = []     # [sprite, speed, sway, age, scale]
var _shoot: Sprite2D
var _shoot_vel := Vector2.ZERO
var _shoot_age := 99.0
var _next_shoot := 5.0
var _next_lantern := 1.0

var _tex_star: ImageTexture
var _tex_star_big: ImageTexture
var _tex_cloud: ImageTexture
var _tex_lantern: ImageTexture
var _tex_shoot: ImageTexture


func _ready() -> void:
	_size = get_viewport_rect().size
	_make_textures()
	var r := RandomNumberGenerator.new()
	r.seed = 42
	for i in star_count:
		var s := _sprite(_tex_star_big if r.randf() < 0.15 else _tex_star)
		s.position = Vector2(r.randf_range(0, _size.x), r.randf_range(0, _size.y * sky_height)).round()
		_stars.append([s, r.randf() * TAU, r.randf_range(1.0, 3.0)])
	for i in cloud_count:
		var c := _sprite(_tex_cloud)
		c.position = Vector2(r.randf_range(0, _size.x), r.randf_range(20, _size.y * 0.42)).round()
		var sc := r.randf_range(0.7, 1.3)
		c.scale = Vector2(sc, sc)
		c.modulate.a = r.randf_range(0.5, 1.0)
		_clouds.append([c, cloud_speed * r.randf_range(0.6, 1.2)])
	_shoot = _sprite(_tex_shoot)
	_shoot.visible = false
	for i in 3:
		_add_lantern(r.randf_range(_size.y * 0.35, _size.y * 0.9))


func _sprite(tex: Texture2D) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = tex
	add_child(s)
	return s


func _add_lantern(y := -1.0) -> void:
	var sc := randf_range(0.55, 1.0)
	var s := _sprite(_tex_lantern)
	s.scale = Vector2(sc, sc)
	s.position = Vector2(randf_range(20, _size.x - 20), y if y > 0 else _size.y + 12)
	s.modulate.a = 0.0
	_lanterns.append([s, lerpf(5.0, 11.0, sc), randf() * TAU, 0.0, sc])


func _process(delta: float) -> void:
	_t += delta
	# stars: only brightness changes
	for st in _stars:
		(st[0] as Sprite2D).modulate.a = 0.35 + 0.65 * (0.5 + 0.5 * sin(_t * st[2] + st[1]))
	# clouds drift and wrap
	for c in _clouds:
		var s: Sprite2D = c[0]
		s.position.x += c[1] * delta
		if s.position.x - 50.0 > _size.x:
			s.position.x = -50.0
	# lanterns rise, sway, flicker, fade near the top
	_next_lantern -= delta
	if _next_lantern <= 0.0 and _lanterns.size() < max_lanterns:
		_add_lantern()
		_next_lantern = randf_range(lantern_every_min, lantern_every_max)
	for l in _lanterns:
		var s: Sprite2D = l[0]
		l[3] += delta
		s.position.y -= l[1] * delta
		s.position.x += sin(_t * 0.6 + l[2]) * 3.0 * delta
		var fade_top := clampf(s.position.y / (_size.y * 0.25), 0.0, 1.0)
		var flick := 0.85 + 0.15 * sin(_t * 9.0 + l[2] * 5.0)
		s.modulate.a = fade_top * clampf(l[3] / 1.5, 0.0, 1.0) * lerpf(0.55, 1.0, l[4]) * flick
	for i in range(_lanterns.size() - 1, -1, -1):
		if (_lanterns[i][0] as Sprite2D).position.y < -20.0:
			(_lanterns[i][0] as Sprite2D).queue_free()
			_lanterns.remove_at(i)
	# one shooting star sprite, reused
	_next_shoot -= delta
	if _next_shoot <= 0.0:
		_next_shoot = randf_range(shooting_every_min, shooting_every_max)
		_shoot_age = 0.0
		_shoot.position = Vector2(randf_range(_size.x * 0.3, _size.x), randf_range(5, _size.y * 0.25))
		_shoot_vel = Vector2(-randf_range(140, 200), randf_range(40, 70))
		_shoot.rotation = _shoot_vel.angle()
		_shoot.visible = true
	if _shoot.visible:
		_shoot_age += delta
		_shoot.position += _shoot_vel * delta
		_shoot.modulate.a = 1.0 - _shoot_age / 0.7
		if _shoot_age >= 0.7:
			_shoot.visible = false


# ---------- pictures, made once ----------
func _make_textures() -> void:
	# star: 1px
	var img := Image.create(1, 1, false, Image.FORMAT_RGBA8)
	img.set_pixel(0, 0, Color(0.85, 0.9, 1.0))
	_tex_star = ImageTexture.create_from_image(img)
	# big star: little cross
	img = Image.create(3, 3, false, Image.FORMAT_RGBA8)
	img.set_pixel(1, 1, Color(1, 1, 1))
	for p in [Vector2i(0, 1), Vector2i(2, 1), Vector2i(1, 0), Vector2i(1, 2)]:
		img.set_pixel(p.x, p.y, Color(0.7, 0.8, 1.0, 0.6))
	_tex_star_big = ImageTexture.create_from_image(img)
	# cloud: three soft ovals
	img = Image.create(100, 26, false, Image.FORMAT_RGBA8)
	var col := Color(0.62, 0.68, 0.86, 0.09)
	for o in [[Vector2(50, 17), 50.0, 9.0], [Vector2(36, 12), 24.0, 8.0], [Vector2(64, 10), 20.0, 7.0]]:
		var c: Vector2 = o[0]
		var rx: float = o[1]
		var ry: float = o[2]
		for y in range(int(c.y - ry), int(c.y + ry) + 1):
			for x in range(int(c.x - rx), int(c.x + rx) + 1):
				if x >= 0 and x < 100 and y >= 0 and y < 26 and pow((x - c.x) / rx, 2) + pow((y - c.y) / ry, 2) <= 1.0:
					img.set_pixel(x, y, col)
	_tex_cloud = ImageTexture.create_from_image(img)
	# lantern: soft warm glow + 4x6 paper body
	img = Image.create(21, 21, false, Image.FORMAT_RGBA8)
	for y in 21:
		for x in 21:
			var d := Vector2(x - 10, y - 10).length() / 10.0
			if d < 1.0:
				img.set_pixel(x, y, Color(1.0, 0.62, 0.25, 0.22 * (1.0 - d) * (1.0 - d)))
	for y in range(7, 13):
		for x in range(8, 12):
			var c2 := Color(1.0, 0.62, 0.25)
			if x > 8 and x < 11 and y > 7 and y < 12:
				c2 = Color(1.0, 0.86, 0.5)
			if y == 7:
				c2 = Color(0.6, 0.25, 0.15)
			if y == 12:
				c2 = Color(0.75, 0.35, 0.18)
			img.set_pixel(x, y, c2)
	_tex_lantern = ImageTexture.create_from_image(img)
	# shooting star: bright head, fading tail (points to the right; rotated to its direction)
	img = Image.create(16, 1, false, Image.FORMAT_RGBA8)
	for x in 16:
		img.set_pixel(x, 0, Color(1, 0.97, 0.85, float(x + 1) / 16.0))
	_tex_shoot = ImageTexture.create_from_image(img)
