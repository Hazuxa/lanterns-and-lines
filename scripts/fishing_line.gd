extends Node2D
## A small physics rope that hangs from the rod tip and swings when you move.
## The player script sets `anchor` and `line_scale` every frame.

@export var segments := 7            # more = longer line
@export var segment_length := 2.0    # pixels per segment (before scaling)
@export var gravity := 400.0         # how hard it pulls down
@export var damping := 0.95          # lower = calmer, higher = swingier
@export var substeps := 3            # more = smoother (a little more CPU)
@export var max_step := 2.0          # max pixels a point can move per substep
@export var line_color := Color("b0bed6")
@export var show_bobber := true
@export var line_scale := 0.7        # match your rod's scale

var anchor := Vector2.ZERO
var _last_anchor := Vector2.ZERO
var _pts: Array[Vector2] = []
var _prev: Array[Vector2] = []


func _seg_len() -> float:
	return segment_length * line_scale


func snap_to(pos: Vector2) -> void:
	anchor = pos
	_last_anchor = pos
	_pts.clear()
	_prev.clear()
	for i in segments:
		var p := pos + Vector2(0, i * _seg_len())
		_pts.append(p)
		_prev.append(p)


## Flip the whole rope around a vertical line (used when the player turns).
func mirror_around(x: float) -> void:
	for i in _pts.size():
		var p := _pts[i]
		p.x = 2.0 * x - p.x
		_pts[i] = p
		var q := _prev[i]
		q.x = 2.0 * x - q.x
		_prev[i] = q
	_last_anchor.x = 2.0 * x - _last_anchor.x


## Move the whole rope without changing its shape (used when equipping).
func shift_by(offset: Vector2) -> void:
	for i in _pts.size():
		_pts[i] = _pts[i] + offset
		_prev[i] = _prev[i] + offset
	_last_anchor += offset


func _physics_process(delta: float) -> void:
	if _pts.size() != segments:
		snap_to(anchor)
	var dt := delta / substeps
	for s in substeps:
		# slide the top of the rope smoothly toward the rod tip
		var a := _last_anchor.lerp(anchor, float(s + 1) / substeps)
		_step(dt, a)
	_last_anchor = anchor
	queue_redraw()


func _step(dt: float, a: Vector2) -> void:
	# 1) move every free point by its velocity + gravity (verlet)
	for i in range(1, segments):
		var vel := ((_pts[i] - _prev[i]) * damping).limit_length(max_step)
		_prev[i] = _pts[i]
		_pts[i] = _pts[i] + vel + Vector2(0, gravity * line_scale) * dt * dt
	_pts[0] = a
	_prev[0] = a

	# 2) keep every segment the right length
	var seg := _seg_len()
	for _iter in 8:
		_pts[0] = a
		for i in range(segments - 1):
			var d := _pts[i + 1] - _pts[i]
			var dist := d.length()
			if dist == 0.0:
				continue
			var diff := (dist - seg) / dist
			if i == 0:
				_pts[i + 1] = _pts[i + 1] - d * diff
			else:
				_pts[i] = _pts[i] + d * diff * 0.5
				_pts[i + 1] = _pts[i + 1] - d * diff * 0.5


func _draw() -> void:
	if _pts.size() < 2:
		return
	for i in range(segments - 1):
		draw_line(to_local(_pts[i]), to_local(_pts[i + 1]), line_color, 1.0)
	if show_bobber:
		var e := to_local(_pts[segments - 1])
		var w := maxf(1.0, roundf(2.0 * line_scale))
		var h := maxf(1.0, roundf(1.0 * line_scale))
		draw_rect(Rect2(e + Vector2(-w / 2.0, 0), Vector2(w, h)), Color("e63c3c"))
		draw_rect(Rect2(e + Vector2(-w / 2.0, h), Vector2(w, h)), Color("fafafa"))
