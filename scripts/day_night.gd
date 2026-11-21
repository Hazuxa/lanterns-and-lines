extends CanvasModulate
## Day / night cycle. Tints the whole world through the day and fades the sun rays.
## Put this on a CanvasModulate node in your world scene.

@export var day_length_seconds := 600.0          # one full day = 10 minutes
@export_range(0.0, 1.0) var time_of_day := 0.30  # 0 = midnight, 0.25 = sunrise, 0.5 = noon, 0.75 = sunset
@export var sun_rays: CanvasItem                  # drag your SunRays node here (optional)

# colour of the world at each time of day
var sky := Gradient.new()

func _ready() -> void:
	add_to_group("day_night")      # so sun shadows can find the time of day
	sky.offsets = PackedFloat32Array([0.0, 0.22, 0.30, 0.50, 0.70, 0.78, 0.86, 1.0])
	sky.colors = PackedColorArray([
		Color("2b4a5a"),   # midnight - dark teal (fireflies!)
		Color("2b4a5a"),   # before dawn
		Color("f2b88c"),   # sunrise - warm orange
		Color("fff6e6"),   # noon - bright, slightly warm
		Color("ffe2b8"),   # afternoon - golden
		Color("f09a7a"),   # sunset - pink orange
		Color("4a4f7a"),   # dusk - purple blue
		Color("2b4a5a"),   # back to midnight
	])

func _process(delta: float) -> void:
	time_of_day = fmod(time_of_day + delta / day_length_seconds, 1.0)
	color = sky.sample(time_of_day)
	if sun_rays:
		# rays are strongest at mid-day, gone at night
		var sun := clampf(sin((time_of_day - 0.25) * TAU * 0.5 * 2.0), 0.0, 1.0)
		sun_rays.visible = sun > 0.02
		sun_rays.self_modulate.a = sun

func is_night() -> bool:
	return time_of_day < 0.24 or time_of_day > 0.82
