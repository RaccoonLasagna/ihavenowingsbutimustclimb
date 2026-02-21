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

# ✅ NEW: rope retract tuning
@export var retract_speed: float = 220.0   # pixels per second
@export var min_rope_length: float = 40.0  # minimum rope length

# =========================
# KIRBY JUMP (Q) - EASY REMOVE BLOCK
# Input Map:
#   Action name: kirby_jump
#   Key: Q
# =========================
@export var kirby_mode_enabled: bool = true
@export var kirby_jump_velocity: float = -420.0   # jump strength
@export var kirby_max_jumps: int = 999999         # basically infinite
@export var kirby_cooldown: float = 0.12          # seconds between jumps

var kirby_jumps_left: int = 0
var kirby_timer: float = 0.0
# =========================

func _physics_process(delta: float) -> void:
	# =========================
	# KIRBY JUMP (Q) - EASY REMOVE BLOCK
	# =========================
	if kirby_mode_enabled:
		kirby_timer = max(0.0, kirby_timer - delta)
		if grounded:
			kirby_jumps_left = kirby_max_jumps
	# =========================

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
	grappling_hook.position = (hook_direction * orbit_range) + Vector2(0, 5)

	update_arm_position($Sprite2D/ArmL, grappling_hook.global_position)
	update_arm_position($Sprite2D/ArmR, grappling_hook.global_position)

	if mouse_pos.x < global_position.x:
		$Sprite2D.scale.x = -2
		grappling_hook.scale.y = -1
	else:
		$Sprite2D.scale.x = 2
		grappling_hook.scale.y = 1

	if Input.is_action_just_pressed("fire_hook"):
		if active_hook == null:
			fire_hook(-hook_direction, mouse_pos)
		else:
			unhook()

func process_movement_input(delta):
	# =========================
	# KIRBY JUMP (Q) - EASY REMOVE BLOCK
	# =========================
	if kirby_mode_enabled and Input.is_action_just_pressed("kirby_jump"):
		if kirby_timer <= 0.0 and kirby_jumps_left > 0:
			linear_velocity.y = kirby_jump_velocity
			kirby_jumps_left -= 1
			kirby_timer = kirby_cooldown
	# =========================

	# ✅ If hook is attached and SPACE/JUMP is held, retract rope
	if hook_attached and active_hook != null and Input.is_action_pressed("jump"):
		rope_length = max(min_rope_length, rope_length - retract_speed * delta)

		# Optional: damp outward velocity a bit so retract feels tighter
		var dir_to_anchor = (active_hook.global_position - global_position).normalized()
		var outward = linear_velocity.dot(-dir_to_anchor)
		if outward > 0:
			linear_velocity += dir_to_anchor * outward

	# Normal jump only when NOT hooked (so space doesn't also jump)
	elif Input.is_action_just_pressed("jump") and grounded:
		linear_velocity.y = JUMP_FORCE

	var move_force = Vector2.ZERO
	if Input.is_action_pressed("left"):
		if hook_attached:
			move_force += LEFT_FORCE * 0.02
		elif grounded:
			move_force += LEFT_FORCE
		else:
			move_force += LEFT_FORCE * 0.3
	if Input.is_action_pressed("right"):
		if hook_attached:
			move_force += RIGHT_FORCE * 0.02
		elif grounded:
			move_force += RIGHT_FORCE
		else:
			move_force += RIGHT_FORCE * 0.3

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

func update_arm_position(arm: Sprite2D, target_pos: Vector2):
	arm.look_at(target_pos)
	arm.rotation += 30
	var distance = arm.global_position.distance_to(target_pos)
	arm.scale.y = distance / 8
