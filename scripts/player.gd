extends CharacterBody2D

const SPEED := 60.0
const IDLE_DELAY := 5.0
const SPECIAL_IDLES := ["blink", "look_around", "yawn", "sweat"]
# frames where the body dips 1px, so the HELD rod dips with him
const BOB_FRAMES := {
	"idle": [1],
	"walk_down": [1, 3], "walk_right": [1, 3],
	"yawn": [2, 3],
}
# where the rod tip is inside the rod pictures (pixels from the sprite's centre)
const BACK_TIP := Vector2(5.5, -4.5)
const HELD_TIP := Vector2(3.5, -6.5)

# ---------- hover feel (tweak these!) ----------
const HOVER_SPEED := 5.0     # how fast it floats up and down
const HOVER_HEIGHT := 0.5    # how far it floats (pixels)
const FOLLOW_SPEED := 9.0    # how tightly it follows him (lower = more lag)
const TILT_AMOUNT := 0.18    # how much it leans when running (radians)
const TILT_SPEED := 8.0      # how fast the lean changes

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var rod_back: Sprite2D = $RodBack
@onready var rod_held: Sprite2D = $RodHeld
@onready var line: Node2D = $FishingLine

var side := "right"     # last left/right he faced - body, idles and rod all use this
var idle_timer := 0.0
var playing_special := false
var rod_equipped := false

var rod_back_base := Vector2.ZERO
var rod_held_base := Vector2.ZERO
var hover_time := 0.0
var last_flip := false
var rod_back_smooth := Vector2.ZERO


func _ready() -> void:
	rod_back_base = rod_back.position   # remember where you placed them in the editor
	rod_held_base = rod_held.position
	rod_back_smooth = rod_back_base
	sprite.animation_finished.connect(_on_animation_finished)
	_update_rod_visibility()
	_sync_rod(0.0)
	line.snap_to(line.anchor)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("equip"):
		var old_anchor: Vector2 = line.anchor
		rod_equipped = not rod_equipped
		if not rod_equipped:
			rod_back_smooth = rod_held.position   # toss it from his hand to his back
		_update_rod_visibility()
		_sync_rod(0.0)
		line.shift_by(line.anchor - old_anchor)


func _physics_process(delta: float) -> void:
	var dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	velocity = dir * SPEED
	move_and_slide()

	if dir != Vector2.ZERO:
		_walk(dir)
	else:
		_stand_still(delta)

	# ONE place decides left/right for the whole body: the right-facing
	# animations, mirrored when he's on the left side
	sprite.flip_h = side == "left"
	_sync_rod(delta)


func _walk(dir: Vector2) -> void:
	playing_special = false
	idle_timer = 0.0
	if dir.x > 0.1:
		side = "right"
	elif dir.x < -0.1:
		side = "left"
	# straight up / down: side stays the same, he keeps looking that way
	_play("walk_right")


func _stand_still(delta: float) -> void:
	if playing_special:
		return
	_play("idle")

	idle_timer += delta
	if idle_timer >= IDLE_DELAY:
		idle_timer = 0.0
		playing_special = true
		sprite.play(SPECIAL_IDLES.pick_random())


func _on_animation_finished() -> void:
	if playing_special:
		playing_special = false
		idle_timer = 0.0


func _play(anim: String) -> void:
	if sprite.animation != anim:
		sprite.play(anim)


# ---------- rod ----------
func _update_rod_visibility() -> void:
	rod_held.visible = rod_equipped
	rod_back.visible = not rod_equipped


func _sync_rod(delta: float) -> void:
	hover_time += delta
	var flip := side == "left"

	# when he turns, flip the rope around the rod so it doesn't get yanked
	if flip != last_flip:
		var pivot := global_position.x if rod_equipped else rod_back.global_position.x
		line.mirror_around(pivot)
		last_flip = flip
	rod_held.flip_h = flip
	rod_back.flip_h = flip

	# --- held rod: stays in his hand and dips with his steps ---
	var frames: Array = BOB_FRAMES.get(String(sprite.animation), [])
	var bob := 1.0 if sprite.frame in frames else 0.0
	var held_pos := rod_held_base
	if flip:
		held_pos.x = -held_pos.x
	rod_held.position = held_pos + Vector2(0, bob)

	# --- back rod: stays on his back, hovers gently, glides across when he turns ---
	var back_pos := rod_back_base
	if flip:
		back_pos.x = -back_pos.x
	var hover := Vector2(0, sin(hover_time * HOVER_SPEED) * HOVER_HEIGHT)
	rod_back_smooth = rod_back_smooth.lerp(back_pos + hover, 1.0 - exp(-FOLLOW_SPEED * delta))
	rod_back.position = rod_back_smooth

	var tilt_target := -velocity.x / SPEED * TILT_AMOUNT   # lean back when running
	rod_back.rotation = lerp_angle(rod_back.rotation, tilt_target, 1.0 - exp(-TILT_SPEED * delta))

	# --- hang the fishing line from the rod tip (follows hover + tilt) ---
	var rod: Sprite2D = rod_held if rod_equipped else rod_back
	var tip: Vector2 = HELD_TIP if rod_equipped else BACK_TIP
	if flip:
		tip.x = -tip.x
	line.anchor = rod.to_global(rod.offset + tip)
	line.line_scale = rod.scale.x


# call this later from your inventory / shop to switch rods
func set_rod(held_tex: Texture2D, back_tex: Texture2D) -> void:
	rod_held.texture = held_tex
	rod_back.texture = back_tex
