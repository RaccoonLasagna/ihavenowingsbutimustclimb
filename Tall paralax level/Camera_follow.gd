extends Camera2D

@export var look_ahead_distance: float = 120.0
@export var time_to_reach: float = 1.0   # 1 second

@onready var player := get_parent() as RigidBody2D

func _process(delta: float) -> void:
	if player == null:
		return
	
	var velocity_x = player.linear_velocity.x
	var target_x := 0.0
	
	# Determine target offset
	if abs(velocity_x) > 10:
		target_x = sign(velocity_x) * look_ahead_distance
	
	# Calculate how fast we need to move to reach it in 1 sec
	var speed = look_ahead_distance / time_to_reach
	
	offset.x = move_toward(offset.x, target_x, speed * delta)
