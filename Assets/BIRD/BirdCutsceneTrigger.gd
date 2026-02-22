

# CUTSCENE

extends Node2D

@export var birds_path: NodePath
@export var birds_fly_texture: Texture2D
@export var music_path: NodePath

@onready var birds := get_parent() . get_node("Birds") as Sprite2D
@onready var music := get_parent() . get_node("Music") as AudioStreamPlayer
@onready var player := get_parent() . get_node("Player") as Node2D # assumes your player node is named "Player"

var cutscene_playing := false
var _label: Label

func play_bird_cutscene() -> void:
	if cutscene_playing: return
	cutscene_playing = true



	# lock player controls (only if your player has this function)
	if player.has_method("set_cutscene_mode"):
		player.call("set_cutscene_mode", true)

	# 1) birds talk
	await popup_text("Let's go to the top of the mountain for a great view", 2.2)

	# 2) swap birds image and fly away
	if birds_fly_texture:
		birds.texture = birds_fly_texture
	await fly_offscreen(birds)

	# 3) player bubble
	await popup_over_player("Wait for me!", 1.2)

	# unlock + music
	if player.has_method("set_cutscene_mode"):
		player.call("set_cutscene_mode", false)

	music.play()
	cutscene_playing = false


# ----- helpers -----

func _ensure_label() -> void:
	if _label: return
	_label = Label.new()
	_label.z_index = 9999
	add_child(_label)

func popup_text(text: String, seconds: float) -> void:
	_ensure_label()
	_label.text = text
	_label.global_position = Vector2(1576.0, -146.25)
	_label.visible = true
	await get_tree().create_timer(seconds).timeout
	_label.visible = false

func popup_over_player(text: String, seconds: float) -> void:
	_ensure_label()
	_label.text = text
	_label.visible = true

	var t := 0.0
	while t < seconds:
		_label.global_position = player.global_position + Vector2(-_label.size.x * 0.5, -80)
		await get_tree().process_frame
		t += get_process_delta_time()

	_label.visible = false

func fly_offscreen(node: Node2D) -> void:
	var rect := get_viewport().get_visible_rect()
	var target := Vector2(rect.position.x + rect.size.x + 250, node.global_position.y - 250)

	var tw := create_tween()
	tw.tween_property(node, "global_position", target, 1.0)
	await tw.finished

	node.visible = false


func _on_area_entered(area: Area2D) -> void:
	play_bird_cutscene()
