# ==============================================================================
# SIMPLE BULLET - High-Performance Projectile System
# ==============================================================================
#
# USER CONTEXT:
# This script handles bullet physics for guard weapons. Bullets travel in
# straight lines at configurable speed, automatically disappear after a
# set lifetime, and emit a signal when they hit the player. The speed is
# tuned to be faster than guard movement to prevent guards from outrunning
# their own bullets. Optional particle effects for trails and impacts.
#
# AI CONTEXT:
# RigidBody2D projectile with linear velocity-based movement and automatic
# cleanup. Uses Area2D collision detection with body_entered signals for
# precise hit detection. Emits hit_player signal for damage/game state
# management. Includes optional GPUParticles2D support for visual effects.
# Speed balanced against guard movement (225.0 vs guard speeds) to prevent
# collision edge cases. Physics layers configured for proper collision
# filtering between player, guards, and environment.
# ==============================================================================

extends RigidBody2D

signal hit_player

@export var speed := 225.0  # Increased by 50% from 150.0 to prevent guard from catching bullets
@export var lifetime := 3.0  # Bullet disappears after 3 seconds

var direction := Vector2.RIGHT
var time_alive := 0.0

@onready var trail_particles: GPUParticles2D = $GPUParticles2D if has_node("GPUParticles2D") else null
@onready var impact_particles: GPUParticles2D = $ImpactParticles if has_node("ImpactParticles") else null

func _ready() -> void:
	# Set up physics
	gravity_scale = 0.0  # No gravity for bullets
	linear_damp = 0.0    # No air resistance
	
	# Create a physics material with no bounce
	var physics_mat = PhysicsMaterial.new()
	physics_mat.bounce = 0.0
	physics_mat.friction = 0.0
	physics_material_override = physics_mat
	
	# Enable collision detection
	contact_monitor = true
	max_contacts_reported = 10
	
	# Set initial velocity
	linear_velocity = direction * speed
	
	# Rotate bullet to face movement direction
	rotation = direction.angle()
	
	# Create proper circular texture if sprite doesn't have one
	setup_bullet_texture()
	
	# Create an Area2D child for detecting the player's BulletDetectionArea
	create_player_detection_area()
	
	# Start trail particles
	if trail_particles:
		trail_particles.emitting = true
		# Configure trail to emit backwards
		if trail_particles.process_material:
			var trail_material = trail_particles.process_material as ParticleProcessMaterial
			if trail_material:
				trail_material.direction = Vector3(-direction.x, -direction.y, 0)

func setup_bullet_texture() -> void:
	"""Create a small circular texture for the bullet if none exists"""
	var sprite_node = get_node_or_null("Sprite2D")
	if sprite_node and !sprite_node.texture:
		var texture = ImageTexture.new()
		var image = Image.create(4, 4, false, Image.FORMAT_RGBA8)
		
		# Create a circular bullet
		for x in range(4):
			for y in range(4):
				var center = Vector2(1.5, 1.5)
				var distance = Vector2(x, y).distance_to(center)
				if distance <= 1.5:
					image.set_pixel(x, y, Color.YELLOW)
				else:
					image.set_pixel(x, y, Color.TRANSPARENT)
		
		texture.set_image(image)
		sprite_node.texture = texture

func create_player_detection_area() -> void:
	"""Create an Area2D to detect the player's BulletDetectionArea"""
	var detection_area = Area2D.new()
	detection_area.name = "PlayerDetectionArea"
	detection_area.collision_layer = 0  # Don't collide with anything
	detection_area.collision_mask = 16  # Detect player's BulletDetectionArea (layer 5 = 16)
	
	# Create a collision shape for the detection area (same size as bullet)
	var collision_shape = CollisionShape2D.new()
	var shape = CircleShape2D.new()
	shape.radius = 1.5  # Much smaller bullet detection (reduced from 2.5)
	collision_shape.shape = shape
	
	detection_area.add_child(collision_shape)
	add_child(detection_area)
	
	# Connect the area_entered signal
	detection_area.area_entered.connect(_on_player_area_detected)

func _physics_process(delta: float) -> void:
	time_alive += delta
	
	# Update trail particle position to emit from behind bullet
	if trail_particles:
		var trail_offset = -direction * 10  # Emit from behind
		trail_particles.position = trail_offset
	
	# Check for direct collisions with bodies (walls, etc.)
	var colliding_bodies = get_colliding_bodies()
	if colliding_bodies.size() > 0:
		for body in colliding_bodies:
			_handle_body_collision(body)
		return
	
	# Remove bullet after lifetime
	if time_alive >= lifetime:
		destroy_bullet()

func _on_player_area_detected(area: Area2D) -> void:
	"""Called when bullet's detection area overlaps with player's BulletDetectionArea"""
	if area.name == "BulletDetectionArea":
		# Normal bullet hit
		hit_player.emit()
		create_impact_effect()
		destroy_bullet()

func _handle_body_collision(_body: Node) -> void:
	"""Handle collision with any body (walls, obstacles, etc.)"""
	# Hit walls, obstacles, etc. - always destroy bullet
	create_impact_effect()
	destroy_bullet()

func create_impact_effect() -> void:
	# Stop trail and create impact burst
	if trail_particles:
		trail_particles.emitting = false
	
	if impact_particles:
		# Configure impact particles
		impact_particles.emitting = true
		if impact_particles.process_material:
			var particle_material = impact_particles.process_material as ParticleProcessMaterial
			if particle_material:
				particle_material.direction = Vector3(0, 0, 0)  # Explode in all directions
				particle_material.initial_velocity_min = 50.0
				particle_material.initial_velocity_max = 150.0
				particle_material.spread = 45.0
		
		# Wait for impact particles to finish, then destroy
		await get_tree().create_timer(0.5).timeout

func destroy_bullet() -> void:
	queue_free()
