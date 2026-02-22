extends Area2D
# END CUTSCENE TRIGGER (FINAL)

@export var camera_name: String = "Camera2D"
@export var cam_move_seconds: float = 2.5
@export var fade_seconds: float = 2.0

var fired := false

var _end_font: Font
var ui_layer: CanvasLayer
var ui_root: Control
var _label: Label
var _end_label: Label

@onready var level := get_parent()
@onready var player := level.get_node("Player")
@onready var cam := level.get_node(camera_name) as Camera2D
@onready var music := level.get_node_or_null("Music") as AudioStreamPlayer
@onready var end_music := level.get_node_or_null("EndMusic") as AudioStreamPlayer

func _ready() -> void:
	_end_font = load("res://Title Screen/rainyhearts.ttf")
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node) -> void:
	if fired: return
	if body != player: return
	fired = true

	# Don't change physics state inside the signal
	set_deferred("monitoring", false)
	call_deferred("_start_end_cutscene")

func _start_end_cutscene() -> void:
	# --- stop current music, play EndMusic ---
	if music: music.stop()
	if end_music:
		end_music.stop()
		end_music.play()

	# --- HARD STOP PLAYER FOREVER ---
	_hard_stop_player()
	_set_player_idle_if_possible()

	# --- Take camera control permanently ---
	_hard_lock_camera()

	# 1) text above player
	await popup_over_player("It is a great view", 2.0)

	# keep player frozen + idle
	_hard_stop_player()
	_set_player_idle_if_possible()

	# 2) move camera up and keep it there
	await move_camera_for_ending(cam_move_seconds)

	# lock again after tween (prevents snapping back)
	_hard_lock_camera()

	# 3) fade in THE END in center
	await show_the_end_fade_in(fade_seconds)

	# End of game: do nothing else; everything stays frozen forever.


# ---------------- PLAYER FREEZE ----------------

func _hard_stop_player() -> void:
	# Turn OFF everything that could move the player.
	player.set_process(false)
	player.set_physics_process(false)
	player.set_process_input(false)
	player.set_process_unhandled_input(false)

	# Kill motion for common body types
	if player is CharacterBody2D:
		(player as CharacterBody2D).velocity = Vector2.ZERO
	elif player is RigidBody2D:
		var r := player as RigidBody2D
		r.linear_velocity = Vector2.ZERO
		r.angular_velocity = 0.0
		r.set_deferred("freeze", true)

	# If your player script supports cutscene mode, set it too (optional)
	if player.has_method("set_cutscene_mode"):
		player.call("set_cutscene_mode", true)

func _set_player_idle_if_possible() -> void:
	# If you have your own method:
	get_tree().call_group("player", "stop_anim")


# ---------------- CAMERA LOCK ----------------

func _hard_lock_camera() -> void:
	# Ensure THIS camera is the one in control
	cam.make_current()
	cam.position_smoothing_enabled = false

	# If camera is parented to player, detach it (prevents inheriting transforms)
	if cam.get_parent() == player:
		var saved_pos := cam.global_position
		player.remove_child(cam)
		level.add_child(cam)
		cam.global_position = saved_pos

	# Disable any script processing on the camera itself (follow scripts)
	cam.set_process(false)
	cam.set_physics_process(false)

	# Disable ALL other cameras globally (autoloads, UI, etc.)
	_disable_other_cameras_global(cam)

func _disable_other_cameras_global(keep: Camera2D) -> void:
	_walk_and_disable_cameras(get_tree().root, keep)

func _walk_and_disable_cameras(n: Node, keep: Camera2D) -> void:
	if n is Camera2D and n != keep:
		var c := n as Camera2D
		c.enabled = false
		c.set_process(false)
		c.set_physics_process(false)

	for child in n.get_children():
		_walk_and_disable_cameras(child, keep)


# ---------------- UI (CanvasLayer so anchors/center works) ----------------

func _ensure_ui() -> void:
	if ui_layer: return

	ui_layer = CanvasLayer.new()
	ui_layer.layer = 50
	get_tree().current_scene.add_child(ui_layer)

	ui_root = Control.new()
	ui_root.anchor_left = 0.0
	ui_root.anchor_top = 0.0
	ui_root.anchor_right = 1.0
	ui_root.anchor_bottom = 1.0
	ui_layer.add_child(ui_root)

func _ensure_label() -> void:
	_ensure_ui()
	if _label: return
	_label = Label.new()
	_label.z_index = 100
	ui_root.add_child(_label)

func _ensure_end_label() -> void:
	_ensure_ui()
	if _end_label: return

	_end_label = Label.new()
	_end_label.z_index = 101
	_end_label.visible = false

	# Full-screen centered
	_end_label.anchor_left = 0.0
	_end_label.anchor_top = 0.0
	_end_label.anchor_right = 1.0
	_end_label.anchor_bottom = 1.0
	_end_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_end_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	if _end_font:
		_end_label.add_theme_font_override("font", _end_font)
	_end_label.add_theme_font_size_override("font_size", 120)

	ui_root.add_child(_end_label)

func _world_to_screen(world_pos: Vector2) -> Vector2:
	# Manual world -> screen conversion for Camera2D
	# screen = (world - camera_world) + viewport_center
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	var viewport_center: Vector2 = viewport_size * 0.5
	return (world_pos - cam.global_position) + viewport_center

func popup_over_player(text: String, seconds: float) -> void:
	_ensure_label()
	_label.text = text
	_label.visible = true

	var t: float = 0.0
	while t < seconds:
		var screen_pos: Vector2 = _world_to_screen(player.global_position)
		_label.position = screen_pos + Vector2(-_label.size.x * 0.5, -120)
		await get_tree().process_frame
		t += get_process_delta_time()

	_label.visible = false

func show_the_end_fade_in(seconds: float) -> void:
	_ensure_end_label()
	_end_label.text = "THE END"
	_end_label.visible = true
	_end_label.modulate.a = 0.0

	var tw := create_tween()
	tw.tween_property(_end_label, "modulate:a", 1.0, seconds)\
		.set_trans(Tween.TRANS_SINE)\
		.set_ease(Tween.EASE_IN_OUT)
	await tw.finished


# ---------------- CAMERA MOVE ----------------

func move_camera_for_ending(seconds: float) -> void:
	# Put player near bottom of screen by moving camera upward.
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	var desired_player_screen_y: float = viewport_size.y * 0.92
	var viewport_center_y: float = viewport_size.y * 0.5

	var player_y: float = player.global_position.y
	var cam_y: float = cam.global_position.y

	var current_player_screen_y: float = (player_y - cam_y) + viewport_center_y
	var delta_screen_y: float = desired_player_screen_y - current_player_screen_y
	var target_cam_y: float = cam_y - delta_screen_y

	var tw := create_tween()
	tw.tween_property(cam, "global_position:y", target_cam_y, seconds)\
		.set_trans(Tween.TRANS_SINE)\
		.set_ease(Tween.EASE_IN_OUT)
	await tw.finished
