# ==============================================================================
# TIMED FREE - Automatic Memory Management for Physics Objects
# ==============================================================================
#
# USER CONTEXT:
# This script provides automatic cleanup for physics objects that should
# disappear after a set time. Perfect for bullets, debris, or temporary
# physics objects that might otherwise accumulate and cause performance
# issues. Simply set the lifetime in the Inspector and the object will
# automatically remove itself when the time expires.
#
# AI CONTEXT:
# RigidBody2D component that implements automatic queue_free() after a
# specified lifetime duration. Uses _physics_process for precise timing
# with delta accumulation. Inspector-exposed lifetime variable for easy
# configuration. Essential for preventing memory leaks and performance
# degradation from accumulating physics objects. Can be attached to any
# RigidBody2D node that needs automatic cleanup.
# ==============================================================================

extends RigidBody2D

@export var lifetime: float = 3.0
var t: float = 0.0

func _physics_process(delta: float) -> void:
	t += delta
	if t >= lifetime:
		queue_free()
