extends Node2D
## Draws the fishing line + float into the shadow, with the same flip / slant as the
## player's shadow. Add as a Node2D child of the Player; it moves itself into the ShadowLayer.

@export var fishing_line: Node2D      # drag the FishingLine node here
@export var body_shadow: Sprite2D     # drag the player's shadow (PlayerShadow) here

var host: Node2D = null


func _ready() -> void:
	host = get_parent() as Node2D
	await get_tree().process_frame
	var layer := get_tree().get_first_node_in_group("shadow_layer")
	if layer:
		reparent(layer, false)


func _process(_delta: float) -> void:
	if not is_instance_valid(host):
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	if fishing_line == null or body_shadow == null or not is_instance_valid(body_shadow):
		return
	if not body_shadow.visible or not fishing_line.is_visible_in_tree():
		return
	var pts: Array = fishing_line.get("_pts")
	if pts == null or pts.size() < 2:
		return
	var col := Color(body_shadow.modulate.r, body_shadow.modulate.g, body_shadow.modulate.b, 1.0)
	# points are global; body_shadow lives in the same parent as us (the ShadowLayer)
	var prev := _to_shadow(get_parent().to_local(pts[0]) if get_parent() else pts[0])
	for i in range(1, pts.size()):
		var p: Vector2 = get_parent().to_local(pts[i]) if get_parent() else pts[i]
		var cur := _to_shadow(p)
		draw_line(prev, cur, col, 1.0)
		prev = cur
	draw_rect(Rect2(prev - Vector2(1, 0), Vector2(2, 2)), col)


func _to_shadow(p: Vector2) -> Vector2:
	# same mapping the body shadow uses: flip at the feet, flatten, slant
	return body_shadow.transform * (p - body_shadow.position)
