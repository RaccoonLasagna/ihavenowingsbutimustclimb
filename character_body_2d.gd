extends RigidBody2D

const ACCELERATION = 500000
const RIGHT_FORCE = Vector2(ACCELERATION, 0)
const LEFT_FORCE = Vector2(-ACCELERATION, 0)
const MAX_SPEED = 150.
var post_hook_speed = MAX_SPEED
const SPEED_RECOVERY = 2.
const JUMP_FORCE = -600
@export var floor_collision: Area2D
var grounded = false

@export var grappling_hook: Node2D
@export var firing_point: Node2D
const orbit_range = 10

@onready var hook_head = preload("res://hook_head.tscn")	
var active_hook = null
var rope_length = 0.0
var hook_joint: PinJoint2D = null
@export var rope_line: Line2D
var hook_attached = false

func _physics_process(delta: float) -> void:
	process_movement_input(delta)
	process_hook_swing()
	draw_rope()

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
		if hook_attached:
			move_force += LEFT_FORCE * 0.02
		elif grounded:
			move_force += LEFT_FORCE
		else: # unhooked, in air
			move_force += LEFT_FORCE * 0.3
	if Input.is_action_pressed("right"):
		if hook_attached:
			move_force += RIGHT_FORCE * 0.02
		elif grounded:
			move_force += RIGHT_FORCE
		else: # unhooked, in air
			move_force += RIGHT_FORCE * 0.3
	
	apply_central_force(move_force * delta)
	if not hook_attached:
		#linear_velocity.x = clamp(linear_velocity.x, -MAX_SPEED, MAX_SPEED)
		post_hook_speed = lerp(post_hook_speed, float(MAX_SPEED), SPEED_RECOVERY * delta)
		var effective_cap = max(post_hook_speed, MAX_SPEED)
		linear_velocity.x = clamp(linear_velocity.x, -effective_cap, effective_cap)

func process_hook_swing():
	if active_hook == null or not hook_attached:
		return
	var to_anchor = active_hook.global_position - global_position
	var dist = to_anchor.length()
	if dist > rope_length:
		var dir = to_anchor.normalized()
		var away_speed = linear_velocity.dot(-dir)
		if away_speed > 0:
			linear_velocity += dir * away_speed
		global_position = active_hook.global_position - dir * rope_length
		
	var to_player = global_position - active_hook.global_position
	var target_angle = to_player.angle() - PI / 2
	rotation = lerp_angle(rotation, target_angle, 0.15)

func draw_rope():
	rope_line.clear_points()
	if active_hook == null:
		return
	rope_line.add_point(Vector2(0, -30))
	rope_line.add_point(to_local(active_hook.global_position))

func fire_hook(direction, mouse_pos):
	var hook = hook_head.instantiate()
	active_hook = hook
	hook.global_position = firing_point.global_position
	hook.hook_direction = direction
	hook.look_at(mouse_pos)
	hook.hook_attached.connect(attach_hook)
	hook.tree_exited.connect(hook_delete)
	get_parent().add_child(hook)

func attach_hook():
	rope_length = global_position.distance_to(active_hook.global_position)
	hook_attached = true
	linear_damp = 0

func unhook():
	active_hook.queue_free()
	linear_damp = 1

var count = 0

# this is also automatically triggered upon unhook
func hook_delete():
	active_hook = null
	linear_damp = 1
	hook_attached = false
	post_hook_speed = abs(linear_velocity.x)
	rope_line.clear_points()
	print("ledelete number " + str(count))
	count += 1
	rotation = 0

func _on_floor_collision_body_entered(body: Node2D) -> void:
	grounded = true
	
func _on_floor_collision_body_exited(body: Node2D) -> void:
	grounded = false
