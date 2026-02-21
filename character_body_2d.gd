extends CharacterBody2D
#njoalf
const SPEED = 300.0
const ACCELERATION = 1500.0
const FRICTION = 2000.0
const JUMP_VELOCITY = -400.0

@export var grappling_hook: Node2D
@export var firing_point: Node2D
const orbit_range = 10

@onready var hook_head = preload("res://hook_head.tscn")
var active_hook = null
var rope_length = 0.0

func _physics_process(delta: float) -> void:
	# gravity
	if not is_on_floor():
		velocity += get_gravity() * delta

	# movement inputs
	# not hooked
	if active_hook == null or active_hook.attached == false:
		if Input.is_action_pressed("left"):
			velocity.x -= ACCELERATION * delta
		elif Input.is_action_pressed("right"):
			velocity.x += ACCELERATION * delta
		else:
			velocity.x = move_toward(velocity.x, 0, FRICTION * delta)
			
		if Input.is_action_just_pressed("jump"):
			if is_on_floor():
				velocity.y = JUMP_VELOCITY
	else:
		var hook_pos = active_hook.global_position
		var rope_vector = global_position - hook_pos
		var rope_dir = rope_vector.normalized()
		var dist = rope_vector.length()
		if dist > rope_length:
			var radial_velocity = velocity.dot(rope_dir)
			if radial_velocity > 0:
				velocity -= rope_dir * radial_velocity

	velocity.x = clamp(velocity.x, -SPEED, SPEED)

	move_and_slide()
	
	# Grappling hook direction
	var mouse_pos = get_global_mouse_position()
	var hook_direction
	if active_hook == null:
		hook_direction = (mouse_pos - global_position).normalized()
		grappling_hook.look_at(mouse_pos)
	else:
		hook_direction = (active_hook.global_position - global_position).normalized()
		grappling_hook.look_at(active_hook.global_position)
	grappling_hook.position = hook_direction * orbit_range
	
	# Grappling hook shooting
	if Input.is_action_just_pressed("fire_hook"): 
		if active_hook == null:
			fire_hook(-hook_direction, mouse_pos)
		else:
			unhook()

func fire_hook(direction, mouse_pos):
	print("pewpew")
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

func unhook():
	active_hook.queue_free()

func hook_delete():
	active_hook = null
