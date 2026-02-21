extends Area2D

@export var speed = 1000
var hook_direction

@export var timer: Timer
var attached = false
signal hook_attached

func _process(delta: float) -> void:
	if not attached:
		position -= hook_direction * speed * delta
	

func _on_timer_timeout() -> void:
	self.queue_free()

func _on_body_entered(body: Node2D) -> void:
	attached = true
	emit_signal("hook_attached")
	timer.stop()
