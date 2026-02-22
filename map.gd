extends Node2D

@export var camera: Camera2D
@export var player: RigidBody2D

const CAM_SPEED =  4.0
func _process(delta: float) -> void:
	camera.position = camera.position.lerp(player.position, delta * CAM_SPEED)
	camera.position.x = clamp(camera.position.x, 600, 8510)
	camera.position.y = clamp(camera.position.y, -9999, 0)
