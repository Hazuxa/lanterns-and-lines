@tool
extends Sprite2D
## ONE shadow for the whole character (body + rods merged into a single picture).
## Works with the 3D shadow layer (the shadow goes all the way around him).
## HOW TO PLACE IT: drag this node in the editor to the character's feet (red cross).

@export var parts: Array[Node2D] = []        # AnimatedSprite2D, RodBack, RodHeld
@export var circle_width := 10.0             # round shadow under him around noon / midnight
@export var circle_height := 4.0

var host: Node2D = null
var layer: Node = null
var _tex: ImageTexture
var _anchor := Vector2.ZERO
var _blob: Sprite2D
var _img_cache := {}          # texture -> Image (reading pictures from the GPU is slow, so do it once)
var _last_sig := ""           # skip rebuilding the silhouette when nothing changed


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
	centered = true
	_blob = Sprite2D.new()
	_blob.texture = blob_texture()
	await get_tree().process_frame
	layer = get_tree().get_first_node_in_group("shadow_layer")
	if layer:
		reparent(layer, false)
		if _blob:
			layer.add_child(_blob)
	elif _blob:
		_blob.free()
		_blob = null


func _exit_tree() -> void:
	if is_queued_for_deletion() and is_instance_valid(_blob):
		_blob.queue_free()


func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		texture = null
		queue_redraw()
		return
	if not is_instance_valid(host):
		queue_free()
		return
	visible = host.is_visible_in_tree()
	if is_instance_valid(_blob):
		_blob.visible = visible
	if not visible:
		return
	_build_silhouette()

	var ground := host.global_position + _anchor
	var circle := 0.0
	if layer:
		var c: Color = layer.shadow_color
		circle = layer.circle_amount
		# the long shadow disappears when the round shadow is about HALF grown (and comes back there too)
		modulate = Color(c.r, c.g, c.b, 1.0 - smoothstep(0.1, 0.8, circle))
		global_transform = layer.ground_transform(ground)
	else:
		modulate = Color(0, 0, 0, 0.3)
		global_transform = Transform2D(Vector2(1, 0), Vector2(0, -0.4), ground)
	if _blob and _blob.is_inside_tree():
		_blob.global_position = ground
		_blob.modulate = Color(modulate.r, modulate.g, modulate.b, layer.circle_darkness * smoothstep(0.0, 1.0, circle))   # lighter, fades in as it grows
		_blob.scale = Vector2(circle_width / 64.0, circle_height / 64.0) * circle


func _draw() -> void:
	if Engine.is_editor_hint():
		draw_line(Vector2(-4, 0), Vector2(4, 0), Color.RED, 1.0)
		draw_line(Vector2(0, -4), Vector2(0, 4), Color.RED, 1.0)


func _part(n: Node2D) -> Dictionary:
	var tex: Texture2D = null
	var off := Vector2.ZERO
	var flip := false
	var hf := 1
	var vf := 1
	var fr := 0
	if n is AnimatedSprite2D:
		var a := n as AnimatedSprite2D
		if a.sprite_frames == null:
			return {}
		tex = a.sprite_frames.get_frame_texture(a.animation, a.frame)
		off = a.offset
		flip = a.flip_h
	elif n is Sprite2D:
		var s := n as Sprite2D
		tex = s.texture
		off = s.offset
		flip = s.flip_h
		hf = s.hframes
		vf = s.vframes
		fr = s.frame
	if tex == null:
		return {}
	var img: Image = _img_cache.get(tex)
	if img == null:
		img = tex.get_image()
		if img == null:
			return {}
		if img.is_compressed():
			img.decompress()
		img.convert(Image.FORMAT_RGBA8)
		_img_cache[tex] = img
	img = img.duplicate()
	if hf > 1 or vf > 1:
		@warning_ignore("integer_division")
		var fw := img.get_width() / hf
		@warning_ignore("integer_division")
		var fh := img.get_height() / vf
		@warning_ignore("integer_division")
		var row := fr / hf
		img = img.get_region(Rect2i((fr % hf) * fw, row * fh, fw, fh))
	img.convert(Image.FORMAT_RGBA8)
	if flip:
		img.flip_x()
	if n.scale != Vector2.ONE:
		img.resize(maxi(1, int(img.get_width() * n.scale.x)), maxi(1, int(img.get_height() * n.scale.y)),
				Image.INTERPOLATE_NEAREST)
	var size := Vector2(img.get_width(), img.get_height())
	return {"img": img, "tl": n.position + off * n.scale - size / 2.0}


func _build_silhouette() -> void:
	# quick check: same frames, same places, same flips as last time? then keep the old picture
	var sig := ""
	for n in parts:
		if n == null or not n.visible:
			continue
		var t: Texture2D = null
		if n is AnimatedSprite2D and (n as AnimatedSprite2D).sprite_frames:
			t = (n as AnimatedSprite2D).sprite_frames.get_frame_texture((n as AnimatedSprite2D).animation, (n as AnimatedSprite2D).frame)
		elif n is Sprite2D:
			t = (n as Sprite2D).texture
		sig += "%d|%s|%s|%s;" % [t.get_instance_id() if t else 0, str(n.position.round()), str(n.get("flip_h")), str(n.scale)]
	if sig == _last_sig and texture != null:
		return
	_last_sig = sig
	var items: Array = []
	var rect := Rect2()
	for n in parts:
		if n == null or not n.visible:
			continue
		var d := _part(n)
		if d.is_empty():
			continue
		var r := Rect2(d.tl, Vector2(d.img.get_width(), d.img.get_height()))
		rect = r if items.is_empty() else rect.merge(r)
		items.append(d)
	if items.is_empty():
		texture = null
		return
	var x0 := floori(rect.position.x) - 3          # 3px empty border so the soft edges aren't cut
	var y0 := floori(rect.position.y) - 3
	var w := ceili(rect.end.x) + 3 - x0
	var h := ceili(rect.end.y) + 3 - y0
	var canvas := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for d in items:
		var im: Image = d.img
		canvas.blend_rect(im, Rect2i(0, 0, im.get_width(), im.get_height()),
				Vector2i(roundi(d.tl.x) - x0, roundi(d.tl.y) - y0))
	if _tex == null or Vector2i(_tex.get_size()) != Vector2i(w, h):
		_tex = ImageTexture.create_from_image(canvas)
	else:
		_tex.update(canvas)
	texture = _tex
	hframes = 1
	vframes = 1
	frame = 0
	flip_h = false
	offset = Vector2(x0 + w / 2.0, y0 + h / 2.0) - _anchor
