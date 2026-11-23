extends Control
## Main menu for Lanterns & Lines.  Put this on the root Control of main_menu.tscn.
## - fades in from black when it opens, fades out to black when you press Play
## - fireflies float around in the background (uses pop_firefly.gd)
## - Settings / Credits open panels if you add them later (SettingsPanel / CreditsPanel)

@export_file("*.tscn") var game_scene := "res://scenes/world.tscn"
@export var fireflies_on_screen := 6        # 0 = no fireflies in the menu

@onready var play_btn: TextureButton = %PlayButton
@onready var settings_btn: TextureButton = %SettingsButton
@onready var credits_btn: TextureButton = %CreditsButton
@onready var exit_btn: TextureButton = %ExitButton
@onready var fade: ColorRect = %Fade
@onready var title: Control = get_node_or_null("%Title")
@onready var fireflies: Node2D = get_node_or_null("%Fireflies")
@onready var settings_panel: Control = get_node_or_null("%SettingsPanel")
@onready var credits_panel: Control = get_node_or_null("%CreditsPanel")

var _leaving := false


func _ready() -> void:
	play_btn.pressed.connect(_on_play)
	settings_btn.pressed.connect(_on_settings)
	credits_btn.pressed.connect(_on_credits)
	exit_btn.pressed.connect(_on_exit)
	var buttons := [play_btn, settings_btn, credits_btn, exit_btn]
	for i in buttons.size():
		var b: TextureButton = buttons[i]
		b.texture_focused = b.texture_hover          # keyboard focus shows the glowing picture
		b.mouse_entered.connect(b.grab_focus)
		b.mouse_exited.connect(b.release_focus)      # mouse leaves -> glow goes away
		b.modulate.a = 0.0                           # hidden until the intro shows them
	_intro_buttons(buttons)
	if title:
		title.modulate.a = 0.0
		create_tween().tween_property(title, "modulate:a", 1.0, 0.8).set_delay(0.2)
	if settings_panel: settings_panel.hide()
	if credits_panel: credits_panel.hide()

	# fade in from black
	fade.show()
	fade.color.a = 1.0
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	create_tween().tween_property(fade, "color:a", 0.0, 0.8)

	# fireflies drifting around the menu
	if fireflies and fireflies_on_screen > 0:
		for i in fireflies_on_screen:
			_spawn_firefly(randf() * 8.0)


## buttons softly fade in one after another
func _intro_buttons(buttons: Array) -> void:
	for i in buttons.size():
		create_tween().tween_property(buttons[i], "modulate:a", 1.0, 0.4).set_delay(0.5 + i * 0.08)


func _spawn_firefly(delay := 0.0) -> void:
	if not is_inside_tree() or _leaving:
		return
	if delay > 0.0:
		await get_tree().create_timer(delay).timeout
	if not is_inside_tree() or _leaving:
		return
	var vp := get_viewport_rect().size
	var f := PopFirefly.new()
	f.center = Vector2(randf_range(20, vp.x - 20), randf_range(vp.y * 0.45, vp.y - 10))
	f.position = f.center
	fireflies.add_child(f)
	f.tree_exited.connect(func(): _spawn_firefly(randf_range(0.5, 3.0)))   # a new one when it leaves


func _on_play() -> void:
	if _leaving:
		return
	_leaving = true
	fade.mouse_filter = Control.MOUSE_FILTER_STOP      # block clicks while fading
	var tw := create_tween()
	tw.tween_property(fade, "color:a", 1.0, 0.6)
	tw.tween_callback(func(): get_tree().change_scene_to_file(game_scene))


func _on_settings() -> void:
	if settings_panel:
		settings_panel.visible = not settings_panel.visible
		if credits_panel: credits_panel.hide()


func _on_credits() -> void:
	if credits_panel:
		credits_panel.visible = not credits_panel.visible
		if settings_panel: settings_panel.hide()


func _on_exit() -> void:
	get_tree().quit()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):          # Esc closes an open panel
		if settings_panel: settings_panel.hide()
		if credits_panel: credits_panel.hide()
	# keyboard / controller: the first arrow press highlights Play
	if get_viewport().gui_get_focus_owner() == null:
		if event.is_action_pressed("ui_down") or event.is_action_pressed("ui_up"):
			play_btn.grab_focus()
			get_viewport().set_input_as_handled()
