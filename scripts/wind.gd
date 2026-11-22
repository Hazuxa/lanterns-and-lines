extends Node
## Wind that changes with the time of day. Every tree using tree_sway.gdshader follows it.
##   night     -> very light breeze
##   morning   -> small, gentle wind
##   noon / afternoon -> stronger wind with RANDOM GUSTS
##   sunset    -> calms down again
## Put this node anywhere in world.tscn (e.g. next to DayNight).

@export_group("Wind strength (1 = normal sway)")
@export var night := 0.3
@export var morning := 0.55
@export var afternoon := 0.9
@export var sunset := 0.45

@export_group("Gusts (noon / afternoon only)")
@export var gust_power := 1.2        # how much a gust adds on top
@export var gust_every_min := 3.0    # seconds between gusts (random between min and max)
@export var gust_every_max := 8.0
@export var gust_length := 1.8       # how long a gust lasts

var strength := 0.5                  # current wind (read-only, for other scripts)
var _wind_time := 0.0
var _gust := 0.0
var _gust_left := 0.0
var _next_gust := 4.0
var _day_night: Node


func _process(delta: float) -> void:
	if _day_night == null:
		_day_night = get_tree().get_first_node_in_group("day_night")
	var tod := 0.4
	if _day_night:
		tod = _day_night.time_of_day

	# base wind for this time of day (smoothly blended)
	var base := _base_for(tod)

	# random gusts in the afternoon
	var gusty := tod > 0.45 and tod < 0.74
	if gusty:
		_next_gust -= delta
		if _next_gust <= 0.0:
			_gust_left = gust_length * randf_range(0.7, 1.3)
			_next_gust = randf_range(gust_every_min, gust_every_max)
	var gust_target := 0.0
	if _gust_left > 0.0:
		_gust_left -= delta
		gust_target = gust_power * randf_range(0.8, 1.0)
	_gust = lerpf(_gust, gust_target, 1.0 - exp(-(3.0 if gust_target > _gust else 1.2) * delta))

	# a little natural wobble so it never feels constant
	var flicker := sin(Time.get_ticks_msec() * 0.0007) * 0.08 + sin(Time.get_ticks_msec() * 0.0019) * 0.05
	var target := maxf(0.05, base + _gust + flicker * base)
	strength = lerpf(strength, target, 1.0 - exp(-1.5 * delta))

	# stronger wind also sways FASTER; time is added up so the sway never jumps
	_wind_time += delta * (0.8 + strength * 0.9)
	RenderingServer.global_shader_parameter_set("wind_strength", strength)
	RenderingServer.global_shader_parameter_set("wind_time", _wind_time)


func _base_for(tod: float) -> float:
	# key times of day -> wind, blended in between
	var keys := [
		[0.00, night], [0.22, night], [0.30, morning], [0.45, morning],
		[0.52, afternoon], [0.70, afternoon], [0.78, sunset], [0.86, night], [1.00, night],
	]
	for i in keys.size() - 1:
		var a: Array = keys[i]
		var b: Array = keys[i + 1]
		if tod >= a[0] and tod <= b[0]:
			var t: float = (tod - float(a[0])) / maxf(0.0001, float(b[0]) - float(a[0]))
			t = t * t * (3.0 - 2.0 * t)
			return lerpf(float(a[1]), float(b[1]), t)
	return night
