extends RigidBody2D

const ACCELERATION = 500000
const RIGHT_FORCE = Vector2(ACCELERATION, 0)
const LEFT_FORCE = Vector2(-ACCELERATION, 0)
const RIGHT_AIR_FORCE = Vector2(ACCELERATION/2, 0)
const LEFT_AIR_FORCE = Vector2(-ACCELERATION/2, 0)
const MAX_SPEED = 300
const JUMP_FORCE = -600
@export var floor_collision: Area2D
var grounded = false

@export var grappling_hook: Node2D
@export var firing_point: Node2D
const orbit_range = 10

@onready var hook_head = preload("res://hook_head.tscn")
var active_hook = null
var rope_length = 0.0
var hook_anchor: StaticBody2D = null
var hook_joint: PinJoint2D = null

func _physics_process(delta: float) -> void:
	process_movement_input(delta)
	process_hook_swing()

	var mouse_pos = get_global_mouse_position()
	var hook_direction
	if active_hook == null:
		hook_direction = (mouse_pos - global_position).normalized()
		grappling_hook.look_at(mouse_pos)
	else:
		hook_direction = (active_hook.global_position - global_position).normalized()
		grappling_hook.look_at(active_hook.global_position)
	grappling_hook.position = hook_direction * orbit_range

	if Input.is_action_just_pressed("fire_hook"):
		if active_hook == null:
			fire_hook(-hook_direction, mouse_pos)
		else:
			unhook()

func process_movement_input(delta):
	if Input.is_action_just_pressed("jump") and grounded:
		linear_velocity.y = JUMP_FORCE
	
	var move_force = Vector2.ZERO
	if Input.is_action_pressed("left"):
		if grounded:
			move_force += LEFT_FORCE
		else:
			move_force += LEFT_AIR_FORCE
	if Input.is_action_pressed("right"):
		if grounded:
			move_force += RIGHT_FORCE
		else:
			move_force += RIGHT_AIR_FORCE
	
	apply_central_force(move_force * delta)
	if active_hook == null:
		linear_velocity.x = clamp(linear_velocity.x, -MAX_SPEED, MAX_SPEED)

func process_hook_swing():
	if hook_anchor == null:
		return
	# Enforce rope length constraint manually — PinJoint locks position entirely,
	# so instead we constrain: if player is further than rope_length, pull them back
	var to_anchor = hook_anchor.global_position - global_position
	var dist = to_anchor.length()
	if dist > rope_length:
		# Remove velocity component pulling away from anchor
		var dir = to_anchor.normalized()
		var away_speed = linear_velocity.dot(-dir)
		if away_speed > 0:
			linear_velocity += dir * away_speed
		# Push player back to rope length
		global_position = hook_anchor.global_position - dir * rope_length

func fire_hook(direction, mouse_pos):
	var hook = hook_head.instantiate()
	active_hook = hook
	hook.global_position = firing_point.global_position
	hook.hook_direction = direction
	hook.look_at(mouse_pos)
	hook.hook_attached.connect(hook_attached)
	hook.tree_exited.connect(hook_delete)
	get_parent().add_child(hook)

func hook_attached():
	rope_length = global_position.distance_to(active_hook.global_position)
	hook_anchor = StaticBody2D.new()
	hook_anchor.global_position = active_hook.global_position
	get_parent().add_child(hook_anchor)
	hook_joint = PinJoint2D.new()
	hook_joint.global_position = active_hook.global_position
	hook_joint.node_a = hook_joint.get_path_to(self)
	hook_joint.node_b = hook_joint.get_path_to(hook_anchor)
	hook_joint.softness = 16.0 
	get_parent().add_child(hook_joint)
	linear_damp = 0

func unhook():
	active_hook.queue_free()
	if hook_joint:
		hook_joint.queue_free()
		hook_joint = null
	if hook_anchor:
		hook_anchor.queue_free()
		hook_anchor = null
		linear_damp = 1

func hook_delete():
	active_hook = null
	if hook_joint:
		hook_joint.queue_free()
		hook_joint = null
	if hook_anchor:
		hook_anchor.queue_free()
		hook_anchor = null
	linear_damp = 1

func _on_floor_collision_body_entered(body: Node2D) -> void:
	grounded = true
	
func _on_floor_collision_body_exited(body: Node2D) -> void:
	grounded = false
