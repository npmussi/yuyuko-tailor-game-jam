extends RigidBody2D

## Fan projectile that instantly destroys guards on contact
## Fired by the player when they have the fan weapon

var direction := Vector2.RIGHT
var speed := 300.0
var lifetime := 5.0  # Projectile disappears after 5 seconds

signal hit_guard(guard: Node2D)

func _ready() -> void:
	# Set velocity based on direction
	linear_velocity = direction * speed
	
	# Auto-destroy after lifetime
	get_tree().create_timer(lifetime).timeout.connect(queue_free)
	
	# Connect collision signal
	body_entered.connect(_on_body_entered)
	
	# Disable gravity
	gravity_scale = 0.0
	
	# Add rotation for visual effect
	var sprite = get_node_or_null("Sprite2D")
	if sprite:
		var tween = create_tween()
		tween.set_loops()
		tween.tween_property(sprite, "rotation", TAU, 0.5)
	
	print("FanProjectile ready: direction=", direction, " speed=", speed)

func _on_body_entered(body: Node) -> void:
	print("FanProjectile hit: ", body.name)
	
	# Check if we hit a guard
	if body.is_in_group("guards"):
		print("FanProjectile destroying guard: ", body.name)
		# Instantly destroy the guard
		body.queue_free()
		hit_guard.emit(body)
		
		# Create a small destruction effect
		create_destruction_effect()
		
		# Destroy the projectile
		queue_free()
	elif body.collision_layer & 2:  # Hit a wall (layer 2)
		print("FanProjectile hit wall, destroying")
		queue_free()

func create_destruction_effect() -> void:
	"""Create a small visual effect when destroying a guard"""
	# Simple particle burst
	var particles = GPUParticles2D.new()
	particles.global_position = global_position
	particles.emitting = true
	particles.one_shot = true
	particles.amount = 30
	particles.lifetime = 0.5
	
	# Create particle material
	var particle_material = ParticleProcessMaterial.new()
	particle_material.direction = Vector3(0, 0, 0)
	particle_material.initial_velocity_min = 100.0
	particle_material.initial_velocity_max = 200.0
	particle_material.spread = 180.0
	particle_material.scale_min = 0.3
	particle_material.scale_max = 0.6
	particles.process_material = particle_material
	
	get_tree().current_scene.add_child(particles)
	
	# Auto-cleanup
	get_tree().create_timer(1.0).timeout.connect(particles.queue_free)
