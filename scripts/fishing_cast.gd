extends Node2D
## Rod casting (no fish yet). Child of Player called "FishingCast" at (0, 0).
##   aim with the MOUSE: he turns to face it and casts toward it
##   hold left click -> the rod FLOATS up and pulls back (springy), power builds, trembles at full power
##   let go          -> the rod WHIPS forward with overshoot, the bobber flies out in an arc
##   lands in water  -> little splash + ripples, bobber bobs half-sunk
##   lands on ground -> small bounce, no ripples
##   click again     -> reel in with little reel jerks   (walking away also reels in)

enum { IDLE, CHARGING, FLYING, OUT, REELING }

@export_group("Cast")
@export var min_distance := 18.0
@export var max_distance := 80.0
@export var flight_time := 0.55
@export var power_speed := 1.2
@export_group("Rod feel")
@export var float_height := 7.0         # how high the rod floats up while charging
@export var spring := 140.0             # rod springiness (higher = snappier)
@export var spring_damp := 9.0          # lower = more wobble / overshoot
@export_group("Look")
@export var line_color := Color("c6d2e6")
@export var bar_offset := Vector2(0, -27)

var state := IDLE
var busy := false                       # player.gd reads this to stop walking
var rod_offset := Vector2.ZERO          # player.gd adds this to the held rod's position

var player: Node2D
var _power := 0.0
var _power_dir := 1.0
var _t := 0.0
var _time := 0.0
var _start := Vector2.ZERO
var _from_ground := Vector2.ZERO
var _target := Vector2.ZERO
var _bobber := Vector2.ZERO
var _in_water := false
var _land_time := 0.0
# rod spring
var _rot := 0.0
var _rot_v := 0.0
var _rot_goal := 0.0
var _off_v := Vector2.ZERO
var _off_goal := Vector2.ZERO
var _splash: CPUParticles2D
var _settled := true                    # idle and the rod has stopped moving
var _pieces_shown := false
var _bar_visible := false
var _world: Node2D                      # draws the bobber end (last piece of line + bobber)
var _pieces: Array[Node2D] = []         # the line is cut in pieces, each sorted on its own spot
const PIECES := 4


func _ready() -> void:
	player = get_parent()
	# the line is split into a few pieces; each piece sits on its own spot on the ground in Objects,
	# so a tree covers only the part of the line that is really behind it
	for k in PIECES:
		var n := Node2D.new()
		n.name = "FishingLine%d" % k
		n.draw.connect(_draw_piece.bind(k))
		player.get_parent().add_child.call_deferred(n)
		_pieces.append(n)
	_world = _pieces[PIECES - 1]
	var img := Image.create(1, 1, false, Image.FORMAT_RGBA8)
	img.set_pixel(0, 0, Color.WHITE)
	_splash = CPUParticles2D.new()
	_splash.texture = ImageTexture.create_from_image(img)
	_splash.amount = 10
	_splash.lifetime = 0.45
	_splash.one_shot = true
	_splash.explosiveness = 0.95
	_splash.local_coords = false
	_splash.direction = Vector2(0, -1)
	_splash.spread = 60.0
	_splash.gravity = Vector2(0, 160)
	_splash.initial_velocity_min = 22.0
	_splash.initial_velocity_max = 38.0
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 1.0])
	g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(0.8, 0.95, 0.95, 0)])
	_splash.color_ramp = g
	_splash.emitting = false
	add_child(_splash)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("cast"):
		if state == IDLE and player.rod_equipped:
			state = CHARGING
			busy = true
			_settled = false
			_power = 0.0
			_power_dir = 1.0
			_face_mouse()
			_rot_v -= 4.0 * _flip()                    # little lift kick
		elif state == OUT:
			_reel_in()
	elif event.is_action_released("cast") and state == CHARGING:
		_release_cast()


func _release_cast() -> void:
	state = FLYING
	_t = 0.0
	var dir := _aim()
	_start = player.line.anchor
	_from_ground = player.global_position
	_target = player.global_position + dir * lerpf(min_distance, max_distance, _power)
	_bobber = _start
	player.line.visible = false
	# WHIP: big kick forward, the spring makes it overshoot and settle
	_rot_v += (14.0 + 10.0 * _power) * _flip()
	_off_v += Vector2(40.0 * _flip(), 30.0)


func _reel_in() -> void:
	state = REELING
	_t = 0.0
	_start = _bobber


func _process(delta: float) -> void:
	# OPTIMIZATION: idle + rod already at rest -> skip everything this frame
	if state == IDLE and _settled:
		return
	_time += delta
	var tip: Vector2 = player.line.anchor
	var f := _flip()
	match state:
		IDLE:
			_rot_goal = 0.0
			_off_goal = Vector2.ZERO
		CHARGING:
			_face_mouse()
			_power += _power_dir * power_speed * delta
			if _power >= 1.0:
				_power = 1.0
				_power_dir = -1.0
			elif _power <= 0.0:
				_power = 0.0
				_power_dir = 1.0
			# rod floats up, drifts back and hovers; trembles near full power
			var hover := sin(_time * 5.0) * 1.0
			_off_goal = Vector2(-3.0 * f, -float_height - 2.0 * _power + hover)
			_rot_goal = (-0.35 - 0.75 * _power) * f
			if _power > 0.85:
				_rot_goal += sin(_time * 60.0) * 0.06 * f
		FLYING:
			_t += delta / flight_time
			var k := minf(_t, 1.0)
			var e := 1.0 - pow(1.0 - k, 2.0)                    # fast out, slows as it lands
			_bobber = _start.lerp(_target, e) + Vector2(0, -sin(k * PI) * (16.0 + 26.0 * _power))
			_off_goal = Vector2(3.0 * f, 0)
			_rot_goal = 0.35 * f
			if _t >= 1.0:
				_land()
		OUT:
			_off_goal = Vector2(2.0 * f, sin(_time * 2.0) * 0.5)
			_rot_goal = (0.25 + sin(_time * 2.0) * 0.03) * f
			if Input.get_vector("move_left", "move_right", "move_up", "move_down") != Vector2.ZERO:
				_reel_in()
		REELING:
			_t += delta / 0.45
			var k := minf(_t, 1.0)
			_bobber = _start.lerp(tip, k * k)
			_rot_goal = (0.1 + sin(_time * 40.0) * 0.08) * f       # reel clicks
			_off_goal = Vector2(0, -1)
			if _t >= 1.0:
				state = IDLE
				busy = false
				player.line.visible = true
				player.line.snap_to(tip)
	# springy rod (this is what makes it feel floaty and alive)
	_rot_v += (_rot_goal - _rot) * spring * delta
	_rot_v *= exp(-spring_damp * delta)
	_rot += _rot_v * delta
	_off_v += (_off_goal - rod_offset) * spring * delta
	_off_v *= exp(-spring_damp * delta)
	rod_offset += _off_v * delta
	player.rod_held.rotation = _rot

	# the power bar only needs redrawing while charging (and once more to clear it)
	if state == CHARGING or _bar_visible:
		queue_redraw()
		_bar_visible = state == CHARGING

	# line pieces: only while the line is out; cleared once when it comes back
	var line_out := not (state == IDLE or state == CHARGING)
	if line_out or _pieces_shown:
		var g_end := _ground_spot() if line_out else player.global_position
		for k in _pieces.size():
			var n: Node2D = _pieces[k]
			if is_instance_valid(n) and n.is_inside_tree():
				n.global_position = player.global_position.lerp(g_end, (k + 0.5) / PIECES)
				n.queue_redraw()
		_pieces_shown = line_out

	# remember when everything has come to rest, so idle frames can be skipped
	_settled = state == IDLE and absf(_rot) < 0.002 and absf(_rot_v) < 0.01 \
			and rod_offset.length() < 0.05 and _off_v.length() < 0.05 and not _pieces_shown and not _bar_visible
	if _settled:
		_rot = 0.0
		rod_offset = Vector2.ZERO
		player.rod_held.rotation = 0.0


func _land() -> void:
	_bobber = _target
	_in_water = _is_water(_target)
	_land_time = _time
	state = OUT
	if _in_water:
		_splash.global_position = _target
		_splash.restart()
		_splash.emitting = true


func _draw() -> void:
	if state == CHARGING:
		_draw_bar()


## Line + bobber are drawn on a separate node that lives in Objects (Y-sorted) and sits on the
## bobber's spot on the ground -> a tree in front of the bobber covers it, like real depth.
func _draw_piece(k: int) -> void:
	var w: Node2D = _pieces[k]
	if state == IDLE or state == CHARGING:
		return
	var tip: Vector2 = w.to_local(player.line.anchor)
	var b := w.to_local(_bobber)
	var since := _time - _land_time
	if state == OUT:
		if _in_water:
			b.y += roundf(sin(since * 3.5) * 0.7)
		else:
			b.y -= roundf(absf(sin(since * 14.0)) * 3.0 * exp(-since * 6.0))

	# this piece's part of the line
	var sag := 2.0
	if state == OUT:
		sag = 9.0
	elif state == REELING:
		sag = 1.0
	var steps := 16
	var i0 := int(float(k) / PIECES * steps)
	var i1 := int(float(k + 1) / PIECES * steps)
	var prev := tip.lerp(b, float(i0) / steps) + Vector2(0, sin(float(i0) / steps * PI) * sag)
	for i in range(i0 + 1, i1 + 1):
		var t := float(i) / steps
		var p := tip.lerp(b, t)
		p.y += sin(t * PI) * sag
		w.draw_line(prev, p, Color(line_color, 0.9), 1.0)
		prev = p

	if k != PIECES - 1:
		return
	# the last piece also draws the bobber and what's around it
	if state == FLYING:
		var g := w.to_local(_ground_spot())
		w.draw_rect(Rect2(g.round() + Vector2(-1, 0), Vector2(3, 1)), Color(0, 0, 0, 0.25))
	if state == OUT and _in_water:
		for r_i in 2:
			var a := fmod(since * 0.7 + r_i * 0.5, 1.0)
			var r := 2.0 + a * 6.0
			_pixel_ellipse(w, w.to_local(_target) + Vector2(0, 1), r, r * 0.4, Color(0.85, 0.96, 0.95, (1.0 - a) * 0.7))
	var o := b.round() + Vector2(-1, -2)
	w.draw_rect(Rect2(o, Vector2(2, 1)), Color(0.93, 0.3, 0.26))
	w.draw_rect(Rect2(o + Vector2(0, 1), Vector2(2, 1)), Color(0.98, 0.98, 0.94))
	if not (state == OUT and _in_water):
		w.draw_rect(Rect2(o + Vector2(0, 2), Vector2(2, 1)), Color(0.98, 0.98, 0.94))


## where the bobber is ON THE GROUND (used for sorting and its shadow)
func _ground_spot() -> Vector2:
	match state:
		FLYING:
			return _from_ground.lerp(_target, 1.0 - pow(1.0 - minf(_t, 1.0), 2.0))
		REELING:
			return _target.lerp(player.global_position, minf(_t, 1.0))
	return _target


func _draw_bar() -> void:
	var p := bar_offset + Vector2(-7, 0)
	var full := _power > 0.85
	draw_rect(Rect2(p, Vector2(14, 3)), Color(0.08, 0.08, 0.12, 0.75))
	var col := Color(0.55, 0.85, 0.4).lerp(Color(1.0, 0.78, 0.3), _power)
	if full and int(_time * 12.0) % 2 == 0:
		col = Color(1, 0.98, 0.85)                             # flashes at full power
	draw_rect(Rect2(p + Vector2(1, 1), Vector2(roundf(12.0 * _power), 1)), col)


func _pixel_ellipse(w: CanvasItem, c: Vector2, rx: float, ry: float, col: Color) -> void:
	var done := {}
	var steps := int(maxf(10.0, rx * 6.0))
	for i in steps:
		var a := TAU * i / steps
		var p := Vector2(roundf(c.x + cos(a) * rx), roundf(c.y + sin(a) * ry))
		if not done.has(p):
			done[p] = true
			w.draw_rect(Rect2(p, Vector2.ONE), col)


func _is_water(pos: Vector2) -> bool:
	var ground: TileMapLayer = player.get("ground")
	if ground == null:
		return false
	var data := ground.get_cell_tile_data(ground.local_to_map(ground.to_local(pos)))
	return data != null and data.get_custom_data("water") == true


## direction from the player to the mouse (where you're casting)
func _aim() -> Vector2:
	var d := get_global_mouse_position() - player.global_position
	if d.length() < 2.0:
		d = Vector2(-1, 0) if player.side == "left" else Vector2(1, 0)
	return d.normalized()


## turn the player to face where the mouse is
func _face_mouse() -> void:
	var dx := get_global_mouse_position().x - player.global_position.x
	if absf(dx) > 2.0:
		player.side = "left" if dx < 0.0 else "right"


func _flip() -> float:
	return -1.0 if player.side == "left" else 1.0


func _exit_tree() -> void:
	for n in _pieces:
		if is_instance_valid(n):
			n.queue_free()
