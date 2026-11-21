extends CanvasGroup
## ONE shadow layer for the whole world.
## Put this on a CanvasGroup in world.tscn, BETWEEN "Ground" and "Objects".
## Every shadow moves itself in here, so shadows that touch or overlap MERGE into one
## shape with one even darkness. It also works out the sun / moon for all shadows,
## so they all point the same way.

@export_group("Sun (day)")
@export var sun_strength := 0.32
@export var sun_color := Color(0, 0, 0)
@export var sun_lean := 0.9

@export_group("Moon (night)")
@export var moon_strength := 0.22
@export var moon_color := Color(0.05, 0.08, 0.22)
@export var moon_lean := 0.7

@export_group("Extra")
@export var min_strength := 0.12      # shadows never fully disappear
@export var flip_lean := false        # tick if shadows lean the wrong way

# read by every shadow:
var lean := 0.0
var length := 0.5
var shadow_color := Color(0, 0, 0)

var _lean := 0.0
var _alpha := 0.3
var day_night: Node = null


func _ready() -> void:
	add_to_group("shadow_layer")


func _process(delta: float) -> void:
	if day_night == null:
		day_night = get_tree().get_first_node_in_group("day_night")
	var tod := 0.5
	if day_night:
		tod = day_night.time_of_day

	var sun_up := clampf(sin((tod - 0.25) * TAU), 0.0, 1.0)
	var sun_pos := clampf((tod - 0.25) / 0.5, 0.0, 1.0)
	var sun_l := lerpf(-1.0, 1.0, sun_pos) * sun_lean
	var sun_len := 0.3 + 0.45 * absf(lerpf(-1.0, 1.0, sun_pos))
	var moon_up := clampf(sin((tod - 0.75) * TAU), 0.0, 1.0)
	var moon_pos := clampf(fposmod(tod - 0.75, 1.0) / 0.5, 0.0, 1.0)
	var moon_l := lerpf(-1.0, 1.0, moon_pos) * moon_lean
	var moon_len := 0.4 + 0.4 * absf(lerpf(-1.0, 1.0, moon_pos))

	var dw := smoothstep(0.0, 0.3, sun_up)
	var nw := smoothstep(0.0, 0.3, moon_up)
	var total := dw + nw
	var t_lean := _lean
	var t_len := length
	if total > 0.001:
		t_lean = (sun_l * dw + moon_l * nw) / total
		t_len = (sun_len * dw + moon_len * nw) / total
	var t_alpha := maxf(min_strength, sun_strength * dw + moon_strength * nw)
	var t_col := sun_color.lerp(moon_color, nw / maxf(total, 0.001))

	var k := 1.0 - exp(-2.5 * delta)      # smooth: nothing pops at sunrise / sunset
	_lean = lerpf(_lean, t_lean, k)
	length = lerpf(length, t_len, k)
	_alpha = lerpf(_alpha, t_alpha, k)
	shadow_color = shadow_color.lerp(t_col, k)
	lean = -_lean if flip_lean else _lean

	# ONE transparency for ALL shadows -> overlaps are never darker
	self_modulate = Color(1, 1, 1, _alpha)
