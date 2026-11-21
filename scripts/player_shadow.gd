extends Sprite2D
## ONE shadow for the whole character (body + rods merged into a single picture).
## Add as a Sprite2D child of the Player, fill "Parts" with AnimatedSprite2D, RodBack, RodHeld.
## At start it moves itself into the world's ShadowLayer, so it MERGES with grass / tree shadows.

@export var parts: Array[Node2D] = []        # FIRST part must be the body (AnimatedSprite2D)
@export var auto_feet := true                 # find the feet automatically (bottom of the body sprite)
@export var feet_y := 0.0                     # only used if auto_feet is off
@export var nudge := Vector2.ZERO             # fine-tune the shadow position by a pixel or two

var host: Node2D = null
var layer: Node = null
var _tex: ImageTexture
var _pivot_y := 0.0


func _ready() -> void:
	host = get_parent() as Node2D
	centered = true
	await get_tree().process_frame
	layer = get_tree().get_first_node_in_group("shadow_layer")
	if layer:
		reparent(layer, false)


func _process(_delta: float) -> void:
	if not is_instance_valid(host):
		queue_free()
		return
	visible = host.is_visible_in_tree()
	if not visible:
		return
	_build_silhouette()

	var lean := 0.0
	var length := 0.4
	var col := Color(0, 0, 0)
	if layer:
		lean = layer.lean
		length = layer.length
		col = layer.shadow_color
		global_position = host.global_position + Vector2(0.0, _pivot_y) + nudge
		modulate = Color(col.r, col.g, col.b, 1.0)
	else:
		position = Vector2(0.0, _pivot_y) + nudge
		modulate = Color(0, 0, 0, 0.3)
	scale = Vector2(1.0, -length)
	skew = lean


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
	var img := tex.get_image()
	if img == null:
		return {}
	if img.is_compressed():
		img.decompress()
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
	var items: Array = []
	var rect := Rect2()
	_pivot_y = feet_y
	for i in parts.size():
		var n := parts[i]
		if n == null or not n.visible:
			continue
		var d := _part(n)
		if d.is_empty():
			continue
		if i == 0 and auto_feet:
			_pivot_y = d.tl.y + d.img.get_height()       # bottom of the body = the feet
		var r := Rect2(d.tl, Vector2(d.img.get_width(), d.img.get_height()))
		rect = r if items.is_empty() else rect.merge(r)
		items.append(d)
	if items.is_empty():
		texture = null
		return
	var x0 := floori(rect.position.x)
	var y0 := floori(rect.position.y)
	var w := ceili(rect.end.x) - x0
	var h := ceili(rect.end.y) - y0
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
	offset = Vector2(x0 + w / 2.0, y0 + h / 2.0 - _pivot_y)
