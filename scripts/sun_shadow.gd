extends Sprite2D
## Shadow for trees, grass, props (anything with ONE sprite).
## Add as a Sprite2D child of the object and drag its Sprite2D / AnimatedSprite2D into Source.
## At start it moves itself into the world's ShadowLayer so it merges with other shadows.

@export var source: Node2D

var host: Node2D = null        # the object this shadow belongs to
var layer: Node = null


func _ready() -> void:
	host = get_parent() as Node2D
	centered = true
	await get_tree().process_frame            # let the world finish loading
	layer = get_tree().get_first_node_in_group("shadow_layer")
	if layer:
		reparent(layer, false)


func _process(_delta: float) -> void:
	if not is_instance_valid(host):
		queue_free()                           # the object was removed -> remove its shadow
		return
	if source == null:
		return
	visible = host.is_visible_in_tree() and source.visible
	if not visible:
		return

	var src_offset := Vector2.ZERO
	if source is AnimatedSprite2D:
		var a := source as AnimatedSprite2D
		if a.sprite_frames:
			texture = a.sprite_frames.get_frame_texture(a.animation, a.frame)
		src_offset = a.offset
		flip_h = a.flip_h
		hframes = 1
		vframes = 1
		frame = 0
	elif source is Sprite2D:
		var s := source as Sprite2D
		texture = s.texture
		hframes = s.hframes
		vframes = s.vframes
		frame = s.frame
		src_offset = s.offset
		flip_h = s.flip_h
	if texture == null:
		return

	var tex_h := texture.get_height() / float(vframes) * source.scale.y
	var feet := source.position + Vector2(src_offset.x, src_offset.y + tex_h / 2.0)
	offset = Vector2(src_offset.x, -tex_h / 2.0 / source.scale.y)

	var lean := 0.0
	var length := 0.4
	var col := Color(0, 0, 0)
	if layer:
		lean = layer.lean
		length = layer.length
		col = layer.shadow_color
		global_position = host.global_position + feet
		modulate = Color(col.r, col.g, col.b, 1.0)        # the layer applies the transparency
	else:
		position = feet
		modulate = Color(0, 0, 0, 0.3)
	scale = Vector2(source.scale.x, -length)
	skew = lean
