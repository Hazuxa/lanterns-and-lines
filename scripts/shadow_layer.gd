extends CanvasGroup
## ONE shadow layer for the whole world (put it BETWEEN "Ground" and "Objects").
## Shadows that overlap MERGE into one shape with one even darkness.
##
## The light crosses the sky along ONE diagonal line (side angle):
##   morning : long shadow pointing UP-LEFT (behind the object)
##   noon    : short shadow right under the object
##   evening : long shadow pointing DOWN-RIGHT (in front)
## It just slides along that line - no turning, no circling.
## Sunset: it switches straight to the moon shadow (no fading) and the moon slides it back.

@export_group("Sun path")
@export var morning_direction := Vector2(-1.0, -0.7)   # where the shadow points in the morning (evening = opposite)
@export var long_length := 0.9        # shadow length in the early morning / late evening
@export var noon_length := 0.0        # extra push downwards (0 = none)
@export_range(0.05, 0.9) var circle_zone := 0.5    # near noon / midnight the shadow turns into a round shadow
@export_range(0.0, 1.0) var morph_fade := 0.6      # 0 = pure morph, 1 = pure fade, in between = both
@export_range(0.0, 1.0) var circle_darkness := 0.65  # round shadow: lower = lighter
@export_range(0.0, 1.0) var noon_shrink := 0.6     # how much THINNER the long shadow gets as it slides into the circle

@export_group("Sun (day)")
@export var sun_strength := 0.32
@export var sun_color := Color(0, 0, 0)

@export_group("Moon (night)")
@export var moon_strength := 0.22
@export var moon_color := Color(0.05, 0.08, 0.22)

@export_group("Sunrise / sunset")
@export_range(0.01, 0.5) var switch_time := 0.08  # how quickly sun shadow turns into moon shadow

# ---- read by every shadow ----
var shadow_vec := Vector2(0, 0.3)     # where the TOP of an object lands, per pixel of height
var shadow_color := Color(0, 0, 0)
var length := 0.3                     # (for old scripts)
var lean := 0.0                       # (for old scripts)
var circle_amount := 0.0              # 0 = normal shadow, 1 = round shadow under the object

var _alpha := 0.0
var day_night: Node = null


func _ready() -> void:
	add_to_group("shadow_layer")
	_update(1.0)


func _process(delta: float) -> void:
	_update(1.0 - exp(-6.0 * delta))


func _update(k: float) -> void:
	if day_night == null:
		day_night = get_tree().get_first_node_in_group("day_night")
	var tod := 0.5
	if day_night:
		tod = day_night.time_of_day

	var sun_h := sin((tod - 0.25) * TAU)           # +1 noon, 0 sunrise/sunset, -1 midnight
	# day: slides morning side -> evening side
	# night: the moon picks it up right where the sun left it and slides it back,
	# so at sunset / sunrise the shadow never jumps - only the colour changes to moonlight
	var along: float
	if sun_h >= 0.0:
		along = 1.0 - 2.0 * clampf((tod - 0.25) / 0.5, 0.0, 1.0)
	else:
		along = -1.0 + 2.0 * clampf(fposmod(tod - 0.75, 1.0) / 0.5, 0.0, 1.0)
	shadow_vec = morning_direction.normalized() * along * long_length + Vector2(0, noon_length)
	length = shadow_vec.length()
	# when the light is high (shadow passing under the object) show a round shadow instead
	circle_amount = 1.0 - smoothstep(0.0, circle_zone, absf(along))
	lean = atan2(-shadow_vec.x, maxf(absf(shadow_vec.y), 0.001))

	# 1 = sun, 0 = moon, with a short smooth handover at sunset / sunrise (no fading out)
	var sun_w := smoothstep(-switch_time, switch_time, sun_h)
	var t_alpha := lerpf(moon_strength, sun_strength, sun_w)
	var t_col := moon_color.lerp(sun_color, sun_w)
	_alpha = lerpf(_alpha, t_alpha, k)
	shadow_color = shadow_color.lerp(t_col, k)
	self_modulate = Color(1, 1, 1, _alpha)


## Every shadow calls this: lays the picture on the ground at `ground_point`.
## The base stays flat on the ground; the top of the picture goes to shadow_vec * height.
func ground_transform(ground_point: Vector2, scale_x := 1.0, scale_y := 1.0) -> Transform2D:
	var x_axis := Vector2(1.0, 0.0) * (1.0 - noon_shrink * circle_amount) * scale_x
	# near noon / midnight the long shadow pulls back INTO the round shadow (morph, no fading)
	var y_axis := -shadow_vec * (1.0 - circle_amount) * scale_y
	return Transform2D(x_axis, y_axis, ground_point)
