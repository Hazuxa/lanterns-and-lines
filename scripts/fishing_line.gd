extends Node2D
## The fishing line that hangs from the rod tip (a little rope that swings).
## player.gd sets `anchor` (rod tip, global) and `line_scale` every frame.

@export var segments := 5               # how many pieces the rope has
@export var segment_length := 1.5       # length of each piece (pixels)
@export var gravity := 400.0
@export var damping := 0.95             # lower = swings less
@export var substeps := 3               # more = smoother, steadier rope
@export var max_step := 2.0             # how far the anchor may jump per substep (stops "pops")
@export var line_color := Color("b0bed6")
@export var show_bobber := true

var anchor := Vector2.ZERO              # rod tip (global) - set by player.gd
var line_scale := 1.0                   # follows the rod's scale

var _pts: Array[Vector2] = []           # rope points (global)
var _old: Array[Vector2] = []
var _anchor_now := Vector2.ZERO
var _resting := false                   # rope has stopped swinging -> skip work until something moves


func _ready() -> void:
	snap_to(anchor)


## put the whole rope straight down from `pos` (no swinging)
func snap_to(pos: Vector2) -> void:
	_resting = false
	_pts.clear()
	_old.clear()
	for i in segments + 1:
		var p := pos + Vector2(0, i * segment_length * line_scale)
		_pts.append(p)
		_old.append(p)
	_anchor_now = pos


## mirror the rope left/right around x (used when the player turns around)
func mirror_around(x: float) -> void:
	_resting = false
	for i in _pts.size():
		_pts[i].x = 2.0 * x - _pts[i].x
		_old[i].x = 2.0 * x - _old[i].x
	_anchor_now.x = 2.0 * x - _anchor_now.x


## move the whole rope by an offset (used when switching rods on/off)
func shift_by(offset: Vector2) -> void:
	_resting = false
	for i in _pts.size():
		_pts[i] += offset
		_old[i] += offset
	_anchor_now += offset


func _physics_process(delta: float) -> void:
	# OPTIMIZATION: hidden (line is cast out) -> nothing to do
	if not visible:
		return
	if _pts.size() != segments + 1:
		snap_to(anchor)
		_resting = false
	# OPTIMIZATION: rope at rest and the rod tip didn't move -> skip this frame
	if _resting and anchor.distance_squared_to(_anchor_now) < 0.0001:
		return
	_resting = false
	var dt := delta / substeps
	var seg := segment_length * line_scale
	for s in substeps:
		# move the anchor toward the rod tip a little at a time (smooth, no pops)
		_anchor_now += (anchor - _anchor_now).limit_length(max_step)
		# verlet: keep moving + gravity
		for i in range(1, _pts.size()):
			var p := _pts[i]
			var v := (p - _old[i]) * damping
			_old[i] = p
			_pts[i] = p + v + Vector2(0, gravity) * dt * dt
		_pts[0] = _anchor_now
		_old[0] = _anchor_now
		# keep each piece the right length
		for _k in 3:
			for i in range(_pts.size() - 1):
				var a := _pts[i]
				var b := _pts[i + 1]
				var d := b - a
				var l := d.length()
				if l < 0.0001:
					continue
				var diff := (l - seg) / l
				if i == 0:
					_pts[i + 1] = b - d * diff
				else:
					_pts[i] = a + d * diff * 0.5
					_pts[i + 1] = b - d * diff * 0.5
	# is the rope still moving?
	var moving := 0.0
	for i in _pts.size():
		moving = maxf(moving, _pts[i].distance_squared_to(_old[i]))
	if moving < 0.00005 and anchor.distance_squared_to(_anchor_now) < 0.0001:
		_resting = true
	queue_redraw()


func _draw() -> void:
	if _pts.size() < 2:
		return
	# points are kept in world space; draw them relative to this node
	# (the node stays a normal child of the player, so it sorts with him behind trees)
	for i in range(_pts.size() - 1):
		draw_line(to_local(_pts[i]), to_local(_pts[i + 1]), line_color, 1.0)
	if show_bobber:
		var e: Vector2 = to_local(_pts[_pts.size() - 1]).round()
		draw_rect(Rect2(e + Vector2(-1, 0), Vector2(2, 1)), Color(0.93, 0.3, 0.26))
		draw_rect(Rect2(e + Vector2(-1, 1), Vector2(2, 1)), Color(0.98, 0.98, 0.94))
