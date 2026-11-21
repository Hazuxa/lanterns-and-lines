@tool
extends Sprite2D
## Day/night shadow for trees, grass and props.
## The red cross = where the shadow starts (drag it). Around noon / midnight the long shadow
## smoothly turns into a ROUND shadow under the object (sized to the object automatically).

@export var source: Node2D                 # the Sprite2D / AnimatedSprite2D this is the shadow of
@export var auto_bottom := false           # true = glue to the lowest visible pixel instead of the red cross
@export_group("Round shadow")
@export var circle_scale := 0.8            # round shadow width = object width x this
@export var circle_squash := 0.35          # height of the oval compared to its width
@export var circle_width := 0.0            # set > 0 to choose the width yourself (pixels)

var host: Node2D = null
var layer: Node = null
var _anchor := Vector2.ZERO
var _blob: Sprite2D
var _blob_x := 0.0                         # centre of the round shadow (x, in host space)
var _blob_scale := Vector2.ONE
var _pad_tex: Texture2D                    # source picture with a transparent border (for soft edges)
const PAD := 3


# ---------- soft "vignette" look ----------
const SOFT_SHADER := """
shader_type canvas_item;
uniform float tip_fade = 0.7;    // how much the far end of the shadow fades (0 = none, 1 = fully)
uniform float softness = 1.6;    // how blurry the edges are (pixels)
varying vec4 tint;
void vertex() { tint = COLOR; }
void fragment() {
	float a = 0.0;
	for (int x = -2; x <= 2; x++) {
		for (int y = -2; y <= 2; y++) {
			a += texture(TEXTURE, UV + vec2(float(x), float(y)) * TEXTURE_PIXEL_SIZE * softness * 0.5).a;
		}
	}
	a /= 25.0;
	a *= mix(1.0 - tip_fade, 1.0, UV.y);     // UV.y: 0 = top of the picture (far tip), 1 = base
	COLOR = vec4(tint.rgb, a * tint.a);
}
"""
static var _soft_mat: ShaderMaterial
static var _blob_tex: GradientTexture2D


static func soft_material() -> ShaderMaterial:
	if _soft_mat == null:
		var sh := Shader.new()
		sh.code = SOFT_SHADER
		_soft_mat = ShaderMaterial.new()
		_soft_mat.shader = sh
	return _soft_mat


static func blob_texture() -> GradientTexture2D:
	if _blob_tex == null:
		var g := Gradient.new()
		g.offsets = PackedFloat32Array([0.0, 0.45, 1.0])
		g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.8), Color(1, 1, 1, 0)])
		_blob_tex = GradientTexture2D.new()
		_blob_tex.gradient = g
		_blob_tex.fill = GradientTexture2D.FILL_RADIAL
		_blob_tex.fill_from = Vector2(0.5, 0.5)
		_blob_tex.fill_to = Vector2(1.0, 0.5)
		_blob_tex.width = 64
		_blob_tex.height = 64
	return _blob_tex


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	host = get_parent() as Node2D
	_anchor = position
	var r := _used_rect()                  # visible part of the picture, in host space
	if auto_bottom and r.size != Vector2.ZERO:
		_anchor.y = r.end.y
	var w := circle_width
	if w <= 0.0:
		w = r.size.x * circle_scale if r.size != Vector2.ZERO else 12.0
	_blob_x = (r.position.x + r.size.x / 2.0) if r.size != Vector2.ZERO else _anchor.x
	if source is Sprite2D and (source as Sprite2D).hframes == 1 and (source as Sprite2D).vframes == 1 \
			and not (source as Sprite2D).region_enabled and (source as Sprite2D).texture:
		var img := (source as Sprite2D).texture.get_image()
		if img:
			if img.is_compressed():
				img.decompress()
			img.convert(Image.FORMAT_RGBA8)
			var big := Image.create(img.get_width() + PAD * 2, img.get_height() + PAD * 2, false, Image.FORMAT_RGBA8)
			big.blit_rect(img, Rect2i(Vector2i.ZERO, img.get_size()), Vector2i(PAD, PAD))
			_pad_tex = ImageTexture.create_from_image(big)
	_blob = Sprite2D.new()                   # round shadow with soft (vignette) edges
	_blob.texture = blob_texture()
	_blob_scale = Vector2(w / 64.0, w * circle_squash / 64.0)
	await get_tree().process_frame
	layer = get_tree().get_first_node_in_group("shadow_layer")
	if layer:
		reparent(layer, false)
		layer.add_child(_blob)
	else:
		_blob.free()
		_blob = null


## The visible (non-transparent) part of the source picture, in the host's space.
func _used_rect() -> Rect2:
	if source == null:
		return Rect2()
	var tex: Texture2D = null
	var off := Vector2.ZERO
	var pic_centered := true
	var hf := 1
	var vf := 1
	var fr := 0
	if source is AnimatedSprite2D:
		var a := source as AnimatedSprite2D
		if a.sprite_frames == null:
			return Rect2()
		tex = a.sprite_frames.get_frame_texture(a.animation, a.frame)
		off = a.offset
		pic_centered = a.centered
	elif source is Sprite2D:
		var sp := source as Sprite2D
		tex = sp.texture
		off = sp.offset
		pic_centered = sp.centered
		hf = sp.hframes
		vf = sp.vframes
		fr = sp.frame
	if tex == null:
		return Rect2()
	var img := tex.get_image()
	if img == null:
		return Rect2()
	if img.is_compressed():
		img.decompress()
	if hf > 1 or vf > 1:
		@warning_ignore("integer_division")
		var fw := img.get_width() / hf
		@warning_ignore("integer_division")
		var fh := img.get_height() / vf
		@warning_ignore("integer_division")
		img = img.get_region(Rect2i((fr % hf) * fw, (fr / hf) * fh, fw, fh))
	var used := img.get_used_rect()
	if used.size == Vector2i.ZERO:
		return Rect2()
	var tl := off - (Vector2(img.get_width(), img.get_height()) / 2.0 if pic_centered else Vector2.ZERO)
	var sc := source.scale
	return Rect2(source.position + (tl + Vector2(used.position)) * sc, Vector2(used.size) * sc)


func _exit_tree() -> void:
	if is_queued_for_deletion() and is_instance_valid(_blob):
		_blob.queue_free()


func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		texture = null
		queue_redraw()
		return
	if not is_instance_valid(host) or not is_instance_valid(source):
		queue_free()
		return
	visible = host.is_visible_in_tree() and source.visible
	if is_instance_valid(_blob):
		_blob.visible = visible
	if not visible:
		return

	var src_offset := Vector2.ZERO
	if source is AnimatedSprite2D:
		var a := source as AnimatedSprite2D
		if a.sprite_frames == null:
			return
		texture = a.sprite_frames.get_frame_texture(a.animation, a.frame)
		hframes = 1
		vframes = 1
		frame = 0
		region_enabled = false
		centered = a.centered
		flip_h = a.flip_h
		src_offset = a.offset
	elif source is Sprite2D:
		var s := source as Sprite2D
		texture = _pad_tex if _pad_tex else s.texture
		hframes = s.hframes
		vframes = s.vframes
		frame = s.frame
		region_enabled = s.region_enabled
		region_rect = s.region_rect
		centered = s.centered
		flip_h = s.flip_h
		src_offset = s.offset
		if _pad_tex and not s.centered:
			src_offset -= Vector2(PAD, PAD)

	var sc := source.scale
	offset = src_offset + (source.position - _anchor) / sc
	var ground := host.global_position + _anchor

	var circle := 0.0
	if layer:
		var c: Color = layer.shadow_color
		circle = layer.circle_amount
		# the long shadow disappears when the round shadow is about HALF grown (and comes back there too)
		modulate = Color(c.r, c.g, c.b, 1.0 - smoothstep(0.1, 0.8, circle))
		global_transform = layer.ground_transform(ground, sc.x, sc.y)
	else:
		modulate = Color(0, 0, 0, 0.3)
		global_transform = Transform2D(Vector2(sc.x, 0), Vector2(0, -0.4 * sc.y), ground)
	if _blob and _blob.is_inside_tree():
		_blob.global_position = Vector2(host.global_position.x + _blob_x, ground.y)
		_blob.modulate = Color(modulate.r, modulate.g, modulate.b, layer.circle_darkness * smoothstep(0.0, 1.0, circle))   # lighter, fades in as it grows
		_blob.scale = _blob_scale * circle      # round shadow GROWS while the long one shrinks into it


func _draw() -> void:
	if Engine.is_editor_hint():
		draw_line(Vector2(-4, 0), Vector2(4, 0), Color.RED, 1.0)
		draw_line(Vector2(0, -4), Vector2(0, 4), Color.RED, 1.0)
