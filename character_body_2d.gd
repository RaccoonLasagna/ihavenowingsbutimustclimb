extends RigidBody2D

@export var min_x = 0
@export var max_x = 9999

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
@export var arm_l: Node2D
@export var arm_r: Node2D
@export var body: Node2D
const orbit_range = 10

@onready var hook_head = preload("res://hook_head.tscn")	
var active_hook = null
var max_rope_length = 350.
var rope_length = 0.0
var hook_joint: PinJoint2D = null
@export var rope_line: Line2D
var hook_attached = false
@export var clippingcheck: ShapeCast2D

@export var wallcheckleft: RayCast2D
@export var wallcheckright: RayCast2D
@export var mantlecheckleft: RayCast2D
@export var mantlecheckright: RayCast2D
@export var mantletimer: Timer

@export var hooksfx: AudioStreamPlayer
@export var jumpsfx: AudioStreamPlayer
@export var walksfx: AudioStreamPlayer

var mantling = false

func _ready() -> void:
	mantletimer.timeout.connect(_on_mantle_timer_timeout)

func _physics_process(delta: float) -> void:
	if global_position.x < min_x:
		global_position.x = min_x
	if global_position.x > max_x:
		global_position.x = max_x
	
	process_movement_input(delta)
	if active_hook == null:
		rotation = lerp_angle(rotation, 0, 0.15)
	else:
		process_hook_swing()
	draw_rope()
	update_animations()

	var mouse_pos = get_global_mouse_position()	
	var hook_direction
	if active_hook == null:
		hook_direction = (mouse_pos - global_position).normalized()
		grappling_hook.look_at(mouse_pos)
	else:
		hook_direction = (active_hook.global_position - global_position).normalized()
		grappling_hook.look_at(active_hook.global_position)
		# limiting rope length
		if global_position.distance_to(active_hook.global_position) > max_rope_length:
			active_hook.queue_free()
			active_hook = null
	grappling_hook.position = (hook_direction * orbit_range) + Vector2(0, 5)
	
	update_arm_position(arm_l, grappling_hook.global_position)
	update_arm_position(arm_r, grappling_hook.global_position)
	
	if mouse_pos.x < global_position.x:
		if not wallcheckleft.is_colliding():
			$Body/UpperBody.flip_h = true
			$Body/Cloak.flip_h = true
		arm_l.position.x = -4.5
		arm_r.position.x = 1.5
		grappling_hook.scale.y = -1
	else:
		if not wallcheckright.is_colliding():
			$Body/UpperBody.flip_h = false
			$Body/Cloak.flip_h = false
		arm_r.position.x = -1.5
		arm_l.position.x = 4.5
		grappling_hook.scale.y = 1

	if Input.is_action_just_pressed("fire_hook"):
		if active_hook == null:
			fire_hook(-hook_direction, mouse_pos)
			$grappling_hook/HookHead.visible = false
		else:
			unhook()

func process_movement_input(delta):
	if mantling:
		linear_velocity.y = -200
		linear_velocity.x = 0
		return
	
	if Input.is_action_just_pressed("jump") and hook_attached:
		unhook()
	elif Input.is_action_just_pressed("jump") and grounded:
		linear_velocity.y = JUMP_FORCE
		jumpsfx.play()
	elif Input.is_action_just_pressed("jump") and wallcheckleft.is_colliding():
		var wall_dir = sign(wallcheckleft.target_position.x)
		linear_velocity.x = -wall_dir * 300
		linear_velocity.y = -500
		post_hook_speed = 300.
		jumpsfx.play()
	elif Input.is_action_just_pressed("jump") and wallcheckright.is_colliding():
		var wall_dir = sign(wallcheckright.target_position.x)
		linear_velocity.x = -wall_dir * 300
		linear_velocity.y = -500
		post_hook_speed = 300.
		jumpsfx.play()
		
	if wallcheckleft.is_colliding() and not mantlecheckleft.is_colliding() and Input.is_action_pressed("left"):
		mantling = true
		mantletimer.start()
		return
	if wallcheckright.is_colliding() and not mantlecheckright.is_colliding() and Input.is_action_pressed("right"):
		mantling = true
		mantletimer.start()
		return

	if Input.is_action_pressed("up") and !clippingcheck.is_colliding():
		if rope_length > 30:
			rope_length = clamp(rope_length - 100 * delta, 30, max_rope_length-1)
	if Input.is_action_pressed("down"):
		if rope_length < max_rope_length:
			rope_length = clamp(rope_length + 100 * delta, 30, max_rope_length-1)

	var move_force = Vector2.ZERO
	if Input.is_action_pressed("left"):
		if hook_attached:
			move_force += LEFT_FORCE * 0.02
		elif grounded:
			move_force += LEFT_FORCE
			if !walksfx.playing:
				walksfx.play()
		else: # unhooked, in air
			move_force += LEFT_FORCE * 0.1
	if Input.is_action_pressed("right"):
		if hook_attached:
			move_force += RIGHT_FORCE * 0.02
		elif grounded:
			move_force += RIGHT_FORCE
			if !walksfx.playing:
				walksfx.play()
		else: # unhooked, in air
			move_force += RIGHT_FORCE * 0.1
	
	apply_central_force(move_force * delta)
	if not hook_attached:
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
	rope_line.add_point(to_local($grappling_hook/firing_point.global_position))
	rope_line.add_point(to_local(active_hook.global_position))

func fire_hook(direction, mouse_pos):
	hooksfx.play()
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
	$grappling_hook/HookHead.visible = true
	count += 1

func _on_floor_collision_body_entered(body: Node2D) -> void:
	grounded = true
	
func _on_floor_collision_body_exited(body: Node2D) -> void:
	grounded = false

func _on_mantle_timer_timeout():
	mantling = false

func update_arm_position(arm: Sprite2D, target_pos: Vector2):
	
	arm.look_at(target_pos)
	arm.rotation_degrees -= 60
	
	var distance = arm.global_position.distance_to(target_pos)
	arm.scale.y = distance / 8

func update_animations():
	if Input.is_action_pressed("right"):
		#$WallCheck.target_position.x = 20 
		$Body/UpperBody.flip_h = true
		$Body/Cloak.flip_h = true
	else:
		#$WallCheck.target_position.x = -20
		$Body/UpperBody.flip_h = false
		$Body/Cloak.flip_h = false

	if not grounded:
		if wallcheckleft.is_colliding() and Input.is_action_pressed("left"):
			$Body/UpperBody.play("wall_sticking")
			$Body/Cloak.play("nothing")
		elif wallcheckright.is_colliding() and Input.is_action_pressed("right"):
			$Body/UpperBody.play("wall_sticking")
			$Body/Cloak.play("nothing")
		else:
			update_jump_animation()
			$Body/Cloak.play("nothing")
		return

	if abs(linear_velocity.x) > 10:
		$Body/UpperBody.play("walk")
		$Body/Cloak.play("default")
		
	else:
		$Body/UpperBody.play("idle")
		$Body/Cloak.stop()
		
func update_jump_animation():
	
	var anim = $Body/UpperBody
	anim.play("jump")
	
	anim.pause() 

	if linear_velocity.y < -400:
		anim.frame = 0
	elif linear_velocity.y < -300:
		anim.frame = 1
	elif linear_velocity.y < -100:
		anim.frame = 2
	elif linear_velocity.y > 100:
		anim.frame = 4
	elif linear_velocity.y > 200:
		anim.frame = 5
	elif linear_velocity.y > 300:
		anim.frame = 0
	else:
		anim.frame = 3
