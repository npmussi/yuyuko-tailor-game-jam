# ==============================================================================
# NOISE WAVE - Advanced Sound Propagation Simulation System
# ==============================================================================
#
# USER CONTEXT:
# This script simulates realistic sound wave propagation from player actions.
# When the player makes noise (footsteps, actions), it creates expanding
# circular waves that travel outward, are blocked by walls, and attenuated
# by different materials. Guards detect these waves when they reach them,
# making the stealth system more realistic and predictable. Currently not
# actively used but available for enhanced audio-visual feedback.
#
# AI CONTEXT:
# Node2D-based physics simulation using PhysicsDirectSpaceState2D for
# raycast-based collision detection. Implements expanding circular wave
# with configurable radius, speed, and material attenuation. Uses segmented
# angle-based raycast system for realistic sound occlusion around obstacles.
# Material-based attenuation factors for different surface types. Visual
# debug rendering with _draw() override showing wave propagation in real-time.
# Can be instantiated dynamically for each noise event with custom parameters.
# ==============================================================================

extends Node2D
class_name NoiseWave

# Wave properties
var initial_noise_level: float
var current_radius: float = 0.0
var max_radius: float
var expansion_speed: float = 150.0  # Units per second (slower for better visibility)
var lifetime: float = 0.0

# Collision detection
var space_state: PhysicsDirectSpaceState2D
var noise_segments: Array[Dictionary] = []  # Store noise strength at different angles

# Material attenuation factors
const WALL_ATTENUATION = 0.3      # Walls reduce noise to 30%
const OBSTACLE_ATTENUATION = 0.7   # Crates/obstacles reduce to 70%
const AIR_ATTENUATION = 0.995      # Very slight reduction over distance

func _init(noise_level: float, hearing_range: float, player_pos: Vector2):
	initial_noise_level = noise_level
	max_radius = noise_level * (hearing_range / 30.0)  # Same calculation as before
	global_position = player_pos
	
	print("NoiseWave created: noise=", noise_level, " max_radius=", max_radius, " pos=", player_pos)
	
	# Initialize noise segments (like rays in a circle)
	var num_segments = 32  # Fewer segments for better performance and visibility
	for i in range(num_segments):
		var angle = (TAU * i) / num_segments
		noise_segments.append({
			"angle": angle,
			"direction": Vector2(cos(angle), sin(angle)),
			"current_strength": noise_level,
			"distance_traveled": 0.0,
			"blocked": false
		})

func _ready():
	space_state = get_world_2d().direct_space_state
	# Add to a group so guards can find active noise waves
	add_to_group("noise_waves")
	print("NoiseWave ready and added to noise_waves group")

func _physics_process(delta: float):
	lifetime += delta
	
	# Expand the wave
	var old_radius = current_radius
	current_radius += expansion_speed * delta
	
	# Update each noise segment
	for segment in noise_segments:
		if segment.blocked:
			continue
			
		# Calculate new position for this segment
		var segment_pos = global_position + segment.direction * current_radius
		var previous_pos = global_position + segment.direction * old_radius
		
		# Only raycast if we actually moved
		if old_radius > 0:
			# Raycast from previous position to current position
			var query = PhysicsRayQueryParameters2D.create(previous_pos, segment_pos)
			query.collision_mask = 2  # Layer 2 (walls) - same as player collision mask
			query.exclude = []
			
			var collision = space_state.intersect_ray(query)
			
			if collision:
				# Hit something! Apply attenuation based on material
				var attenuation = get_material_attenuation(collision.collider)
				segment.current_strength *= attenuation
				
				# If noise is too weak, block this segment
				if segment.current_strength < 0.5:  # Minimum audible threshold
					segment.blocked = true
			else:
				# No collision, just apply air attenuation over distance
				segment.current_strength *= AIR_ATTENUATION
		
		segment.distance_traveled = current_radius
	
	# Force redraw for visualization
	queue_redraw()
	
	# Remove wave when it reaches max radius or all segments are blocked
	if current_radius >= max_radius or all_segments_blocked():
		print("NoiseWave finished: radius=", current_radius, " max=", max_radius)
		queue_free()

func all_segments_blocked() -> bool:
	for segment in noise_segments:
		if !segment.blocked and segment.current_strength >= 0.5:
			return false
	return true

func get_material_attenuation(collider: Node) -> float:
	# Check what type of object we hit based on groups or node names
	if collider.is_in_group("walls"):
		return WALL_ATTENUATION
	elif collider.is_in_group("obstacles") or "crate" in collider.name.to_lower():
		return OBSTACLE_ATTENUATION
	else:
		# Default to wall attenuation for unknown solid objects
		return WALL_ATTENUATION

func get_noise_at_position(pos: Vector2) -> float:
	var distance = global_position.distance_to(pos)
	
	# If position is beyond current wave radius, no noise yet
	if distance > current_radius:
		return 0.0
	
	# Find the closest noise segments to this position
	var direction_to_pos = global_position.direction_to(pos)
	var angle_to_pos = direction_to_pos.angle()
	
	# Find the two closest segments and interpolate
	var closest_strength = 0.0
	var min_angle_diff = TAU
	
	for segment in noise_segments:
		var angle_diff = abs(angle_difference(segment.angle, angle_to_pos))
		if angle_diff < min_angle_diff:
			min_angle_diff = angle_diff
			closest_strength = segment.current_strength
	
	# Apply distance falloff within the current radius
	var distance_factor = 1.0 - (distance / max_radius)
	return closest_strength * distance_factor

func _draw():
	# Draw the expanding wave as a sonar ping
	if current_radius > 0:
		# Main wave circle - bright and visible
		var wave_color = Color.CYAN
		wave_color.a = 0.8 - (current_radius / max_radius) * 0.6  # Fade as it expands
		draw_arc(Vector2.ZERO, current_radius, 0, TAU, 64, wave_color, 3.0)
		
		# Inner glow effect
		if current_radius > 5:
			var glow_color = wave_color
			glow_color.a *= 0.3
			draw_arc(Vector2.ZERO, current_radius - 5, 0, TAU, 64, glow_color, 2.0)
		
		# Optional: Draw noise segments with strength-based colors for debugging
		var debug_segments = false  # Set to true to see individual segments
		if debug_segments:
			for segment in noise_segments:
				if segment.blocked:
					continue
					
				var segment_pos = segment.direction * current_radius
				var color_intensity = segment.current_strength / initial_noise_level
				var segment_color = Color(1.0, 1.0 - color_intensity, 1.0 - color_intensity, 0.5)
				
				draw_line(Vector2.ZERO, segment_pos, segment_color, 1.0)
