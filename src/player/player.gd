# ==============================================================================
# PLAYER CONTROLLER - Main Player Character Script
# ==============================================================================
# 
# USER CONTEXT:
# This script controls the main player character in the stealth game. It handles
# movement (walking/sneaking), stamina management, noise generation for guards
# to detect, camera controls, and death/restart mechanics. Key features include:
# - WASD movement with configurable walking/sneaking speeds
# - C key toggles between walking and sneaking modes
# - Stamina system that drains while sneaking and regenerates when walking
# - Noise emission system that alerts nearby guards based on movement type
# - Camera pan controls and zoom settings
# - Terrain noise multipliers for different surface types
# - Win condition detection and game restart handling
#
# AI CONTEXT:
# CharacterBody2D-based player controller with MovementState enum (WALKING/SNEAKING).
# Implements noise-based stealth mechanics via noise_event signal emission with
# configurable radius (@export walking_noise_radius, sneaking_noise_radius).
# Stamina system uses constants for drain/regen rates. Camera2D child handles
# view with lerped offset reset and boundary constraints. Collision detection
# for guard catch areas and bullet detection. Terrain system modifies noise
# via get_final_noise_radius() method with multipliers. Death system triggers
# scene reload. Movement uses velocity-based physics with sprite flipping.
# Inspector-exposed variables for speed, noise radius, camera settings.
# ==============================================================================

extends CharacterBody2D

# Movement speeds exposed in Inspector
@export var player_speed := 47.5  # Normal walking speed
@export var sneak_speed := 30.0  # Speed while sneaking
@export var camera_pan_speed := 100  # Camera movement speed
@export var camera_zoom_level := 4  # Camera zoom level

# Noise System - Inspector Variables
@export var walking_noise_radius := 60.0  # Noise radius when walking normally
@export var sneaking_noise_radius := 2.0  # Noise radius when sneaking

# Stamina system constants
const MAX_STAMINA := 30.0  # Base stamina amount
const STAMINA_DRAIN_RATE := 4.0  # Stamina drained per second while sneaking (reduced from 5.0)

# Camera boundaries (adjust these values to match your level size)
# Level is positioned at (-256, -144), but we want positive camera limits
# Player world position is (-248, -112) but camera should stay positive
const CAMERA_LIMIT_LEFT := 0       # Don't go left of world origin
const CAMERA_LIMIT_TOP := 0        # Don't go above world origin  
const CAMERA_LIMIT_RIGHT := 1800    # Right boundary of visible area
const CAMERA_LIMIT_BOTTOM := 1600   # Bottom boundary of visible area

enum MovementState { SNEAKING, WALKING }  # Renamed from CROUCHING to SNEAKING

@onready var camera = $Camera2D
# @onready var sprite: Sprite2D = $Sprite2D
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var bullet_detection_area = $BulletDetectionArea

var current_state := MovementState.WALKING
var current_noise_level := 10  # Reduced from 15 for better stealth
var is_caught := false  # Flag to prevent movement when caught
var death_timer := 0.0  # Timer for death animation
var is_dying := false  # Flag to track death state
var last_direction := 2 # Direction, numpad

# Stamina system variables
var current_stamina := 0.0  # Start with empty stamina (must find peaches to sneak)
var is_sneaking_allowed := true  # Can player sneak (based on stamina and guards)

# Optimization: Cache guard alert check
var guard_check_timer := 0.0
var guard_check_interval := 0.2  # Check guards 5 times per second
var cached_can_sneak_check := true  # Renamed from cached_can_crouch

# Debug throttling variables
var debug_timer := 0.0
var debug_interval := 0.5  # Print debug info twice per second max
var last_noise_level := 0

# Noise event throttling
var noise_event_timer := 0.0
var noise_event_interval := 0.1  # Emit noise events 10 times per second while moving

# Terrain noise system
var terrain_noise_multiplier := 1.0  # Multiplier for current terrain (1.0 = normal, 2.0 = double noise)

# Event-based noise system (MGS style)
signal noise_event(origin: Vector2, radius: float, noise_type: String)

func _ready() -> void:
	# Add player to group for UI reference
	add_to_group("player")
	
	# Set initial zoom
	camera.zoom = Vector2(camera_zoom_level, camera_zoom_level)
	# Ensure camera is active and follows the player
	camera.make_current()
	camera.enabled = true
	# Optional: Add smoothing for nicer movement
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 5.0
	
	# Set camera limits to keep it within the level boundaries
	camera.limit_left = CAMERA_LIMIT_LEFT
	camera.limit_top = CAMERA_LIMIT_TOP
	camera.limit_right = CAMERA_LIMIT_RIGHT
	camera.limit_bottom = CAMERA_LIMIT_BOTTOM
	camera.limit_smoothed = true  # Smooth camera when hitting limits
	
	# Disable automatic detection - using manual limits only
	# setup_camera_limits_from_tilemap()
	
	# Set up bullet detection area
	if bullet_detection_area:
		bullet_detection_area.collision_layer = 16  # Layer 5 (player_bullets)
		bullet_detection_area.collision_mask = 8    # Layer 4 (bullets)
		bullet_detection_area.body_entered.connect(_on_bullet_hit)
	
	assert(sprite != null)
	const INTRO_TIMELINE = preload("res://src/dialogic/timeline.dtl")
	Dialogic.start(INTRO_TIMELINE)
	
func setup_camera_limits_from_tilemap() -> void:
	"""Automatically set camera limits based on the TileMap in the scene"""
	# Find the TileMap node in the scene - try multiple approaches
	var tilemap = get_tree().get_first_node_in_group("tilemap")
	if !tilemap:
		# Try to find by walking up the scene tree
		var parent = get_parent()
		while parent:
			tilemap = parent.get_node_or_null("TileMap")
			if tilemap:
				break
			parent = parent.get_parent()
	
	if !tilemap:
		# Last resort: find any TileMap in the scene
		var all_tilemaps = get_tree().get_nodes_in_group("tilemap")
		if all_tilemaps.size() == 0:
			# Look for any TileMap node
			var root = get_tree().current_scene
			tilemap = find_tilemap_recursive(root)
	
	if tilemap and tilemap is TileMap:
		var used_rect = tilemap.get_used_rect()
		var tile_size = Vector2(16, 16)  # Default tile size for most tilesets
		if tilemap.tile_set:
			tile_size = tilemap.tile_set.tile_size
		
		# Calculate world boundaries - convert Vector2i to Vector2 for math
		var top_left = tilemap.global_position + (Vector2(used_rect.position) * tile_size)
		var bottom_right = tilemap.global_position + (Vector2(used_rect.position + used_rect.size) * tile_size)
		
		# Get viewport size at current zoom level for padding
		var viewport_size = get_viewport().get_visible_rect().size / camera.zoom
		var padding_x = viewport_size.x * 0.25  # Quarter of viewport width
		var padding_y = viewport_size.y * 0.25  # Quarter of viewport height
		
		# Set camera limits with appropriate padding
		camera.limit_left = int(top_left.x - padding_x)
		camera.limit_top = int(top_left.y - padding_y)
		camera.limit_right = int(bottom_right.x + padding_x)
		camera.limit_bottom = int(bottom_right.y + padding_y)
		camera.limit_smoothed = true
		
		print("Camera limits set from TileMap: Left=", camera.limit_left, ", Top=", camera.limit_top, ", Right=", camera.limit_right, ", Bottom=", camera.limit_bottom)
	else:
		print("Warning: Could not find TileMap for automatic camera limits, using constants")

func find_tilemap_recursive(node: Node) -> TileMap:
	"""Recursively search for a TileMap node in the scene tree"""
	if node is TileMap:
		return node as TileMap
	
	for child in node.get_children():
		var result = find_tilemap_recursive(child)
		if result:
			return result
	
	return null

func is_sneaking() -> bool:
	"""Returns true if the player is currently sneaking"""
	return current_state == MovementState.SNEAKING

func can_sneak() -> bool:
	"""Check if player can sneak (no guards are in alert state)"""
	var all_guards = get_tree().get_nodes_in_group("guards")
	for guard in all_guards:
		if guard.current_state == 1:  # GuardState.ALERT = 1
			return false
	return true

func update_crouch_cache(delta: float) -> void:
	"""Optimize guard checking by caching the result"""
	guard_check_timer += delta
	if guard_check_timer >= guard_check_interval:
		guard_check_timer = 0.0
		cached_can_sneak_check = can_sneak()  # Renamed from cached_can_crouch

func update_stamina(delta: float) -> void:
	"""Update stamina based on current state"""
	if current_state == MovementState.SNEAKING:
		# Drain stamina while sneaking (4 stamina per second)
		current_stamina -= STAMINA_DRAIN_RATE * delta
		current_stamina = max(0.0, current_stamina)  # Don't go below 0
		
		# Force player to stand if stamina is depleted
		if current_stamina <= 0.0:
			current_state = MovementState.WALKING
			current_noise_level = 10
	# Stamina NO LONGER regenerates automatically - must eat peaches!

func activate_nearby_objects() -> void:
	"""Activate/interact with nearby objects in front of the player.
	This basically:
		1. Create a circle in front of the player
		2. Checks all objects in that circle
		3. Runs any object's 'activate' method if it exists
	"""
	var interaction_distance := 16.0  # Distance to check for interactable objects
	var direction_vector := Vector2.ZERO
	
	match last_direction: # Be very dumb if we could activate without looking at it.
		8: direction_vector = Vector2(0, -1)  # Up
		2: direction_vector = Vector2(0, 1)   # Down
		4: direction_vector = Vector2(-1, 0)  # Left
		6: direction_vector = Vector2(1, 0)   # Right
		7: direction_vector = Vector2(-1, -1).normalized()  # Up-Left
		9: direction_vector = Vector2(1, -1).normalized()   # Up-Right
		1: direction_vector = Vector2(-1, 1).normalized()   # Down-Left
		3: direction_vector = Vector2(1, 1).normalized()    # Down-Right
	
	var check_position = global_position + (direction_vector * interaction_distance)
	var space_state = get_world_2d().direct_space_state
	
	# Create query parameters for point intersection
	var params = PhysicsPointQueryParameters2D.new()
	params.position = check_position
	params.collide_with_areas = true
	params.collide_with_bodies = true
	
	var result = space_state.intersect_point(params)
	
	print("Checking interaction at position: ", check_position, " found ", result.size(), " objects.")
	for hit in result:
		print("Hit object: ", hit.collider.name, " and is in group 'interactable': ", hit.collider.is_in_group("interactable"))
		var obj = hit.collider
		if obj and obj.is_in_group("interactable"):
			obj.activate()
			print("Activated object: ", obj.name)
			return  # Only activate one object at a time

func _on_bullet_hit(body: Node) -> void:
	"""Called when a bullet hits the player's detection area"""
	# Don't trigger death if already dying or caught
	if is_dying or is_caught:
		return
		
	# Check if the colliding body is a bullet
	if body.has_signal("hit_player"):
		# Bullet hit us, trigger death
		get_caught()

func _physics_process(delta: float) -> void:
	# Handle death animation
	if is_dying:
		handle_death_animation(delta)
		return
		
	# Don't process input if caught but not yet dying
	if is_caught:
		return
	
	# Update debug timer for throttling debug output
	debug_timer += delta
	
	# Update noise event timer
	noise_event_timer += delta
	
	
	# Update cached guard check periodically (performance optimization)
	update_crouch_cache(delta)
	
	# Update stamina system
	update_stamina(delta)
	
	# Force player to stand if any guards are alerted
	if !cached_can_sneak_check and current_state == MovementState.SNEAKING:
		current_state = MovementState.WALKING
		current_noise_level = 10  # Reduced from 15
		
	# Handle sneaking (renamed from crouching)
	if Input.is_action_just_pressed("crouch"):  # Keep input action as "crouch" for compatibility
		# Can only sneak if no guards are alerted AND has stamina
		if cached_can_sneak_check and current_stamina > 0:
			current_state = MovementState.SNEAKING if current_state == MovementState.WALKING else MovementState.WALKING
			# Don't change noise level when just changing stance - only movement makes noise
		else:
			# Force player to stand if any guards are alerted or no stamina
			if current_state == MovementState.SNEAKING:
				current_state = MovementState.WALKING
				# Don't change noise level when just changing stance

	if Input.is_action_just_pressed("ui_accept"):
		# First check if we are in front of an object
		# Copying RPG Maker style interaction
		activate_nearby_objects()

		# Check win condition
		var win_area = get_tree().get_first_node_in_group("win_area")
		if win_area and global_position.distance_to(win_area.global_position) < 32:
			print("Player reached the win area! You win!")
			# Reset all keycard variables before loading next scene
			reset_keycard_variables()
			# Restart the game after a short delay
			get_tree().reload_current_scene()
	

	
	# Debug: Print current position (P key)
	if Input.is_key_pressed(KEY_P):  # P key for debug
		if debug_timer >= debug_interval:  # Don't spam
			print("PLAYER POSITION: ", global_position)
			debug_timer = 0.0
	
	var input = Vector2(
		Input.get_action_strength("ui_right") - Input.get_action_strength("ui_left"),
		Input.get_action_strength("ui_down") - Input.get_action_strength("ui_up")
	).normalized()
	
	if Input.is_action_pressed("ui_shift"):
		# Camera panning mode - player doesn't move, camera moves
		velocity = Vector2.ZERO
		# Move camera offset in the direction of input (no inversion needed)
		var pan_offset = input * camera_pan_speed * delta
		camera.offset += pan_offset
	else:
		# Normal movement mode
		var move_speed = sneak_speed if current_state == MovementState.SNEAKING else player_speed
		velocity = input * move_speed
		move_and_slide()
		
		# Set noise level ONLY when actually moving (velocity-based)
		if velocity.length() > 5.0:  # Only make noise when moving above threshold
			# Set movement noise based on state
			var movement_noise = 3 if current_state == MovementState.SNEAKING else 10
			current_noise_level = movement_noise
			
			# Emit noise events for both walking and sneaking (but different radii)
			if noise_event_timer >= noise_event_interval:
				var base_noise_radius = sneaking_noise_radius if current_state == MovementState.SNEAKING else walking_noise_radius
				var final_noise_radius = get_final_noise_radius(base_noise_radius)  # Apply terrain multiplier
				var noise_type = "sneaking" if current_state == MovementState.SNEAKING else "walking"
				noise_event.emit(global_position, final_noise_radius, noise_type)
				noise_event_timer = 0.0  # Reset noise event timer
				
				# Show terrain effect in debug
				if terrain_noise_multiplier != 1.0:
					# print("PLAYER NOISE EVENT: ", noise_type, " at ", global_position, " radius: ", base_noise_radius, " -> ", final_noise_radius, " (terrain: ", terrain_noise_multiplier, "x)")
					pass
				else:
					# print("PLAYER NOISE EVENT: ", noise_type, " at ", global_position, " radius: ", final_noise_radius)
					pass
				
				# Only print debug when noise level changes or timer elapsed (to avoid spam)
				if current_noise_level != last_noise_level or debug_timer >= debug_interval:
					if current_state == MovementState.SNEAKING:
						# print("PLAYER NOISE DEBUG: Sneaking at ", velocity.length(), " - SILENT (stealth mode)")
						pass
					else:
						# print("PLAYER NOISE DEBUG: Moving at ", velocity.length(), " - Noise level: ", current_noise_level)
						pass
					debug_timer = 0.0
			else:
				current_noise_level = 0  # Silent when not moving
				# Only print debug if noise level changed or timer elapsed
				if velocity.length() > 0 and (current_noise_level != last_noise_level or debug_timer >= debug_interval):
					# print("PLAYER NOISE DEBUG: Moving slowly at ", velocity.length(), " - Silent (below threshold)")
					debug_timer = 0.0
		
		last_noise_level = current_noise_level
		
		# Flip sprite based on movement direction
		# if velocity.x != 0:
		# 	sprite.flip_h = velocity.x < 0
		if velocity.x == 0 and velocity.y == 0:
			match (last_direction):
				2:
					sprite.play('idle_down')
				4:
					sprite.play('idle_left')
				6:
					sprite.play('idle_right')
				8:
					sprite.play('idle_up')
		elif abs(velocity.x) > abs(velocity.y):
			if velocity.x > 0: #Facing right
				sprite.play('walk_right')
				last_direction = 6;
			else:
				sprite.play('walk_left')
				last_direction = 4;
		else:
			if velocity.y > 0:
				sprite.play('walk_down')
				last_direction = 2;
			else:
				sprite.play('walk_up')
				last_direction = 8;

		
		# Reset camera offset when not panning (return to player-centered)
		camera.offset = camera.offset.lerp(Vector2.ZERO, 10 * delta)

func get_caught() -> void:
	"""Called when the player is caught by a guard or bullet"""
	# Prevent multiple death triggers
	if is_dying or is_caught:
		return
		
	is_caught = true
	is_dying = true
	velocity = Vector2.ZERO
	death_timer = 0.0
	
	# Notify all guards that the player has died to stop their behavior
	notify_guards_of_player_death()
	
	# No death animation; just hold a moment before restart
	
	print("Player caught - death sequence started")

func notify_guards_of_player_death() -> void:
	"""Tell all guards to stop their behavior because the player has died"""
	var all_guards = get_tree().get_nodes_in_group("guards")
	for guard in all_guards:
		if guard.has_method("on_player_died"):
			guard.on_player_died()

func handle_death_animation(delta: float) -> void:
	"""Handle post-death delay and restart"""
	death_timer += delta
	var death_duration = 1.0
	if death_timer >= death_duration:
		print("Death complete - restarting game")
		restart_game()

func restart_game() -> void:
	"""Restart the game scene"""
	# Use GameManager if available
	if has_node("/root/GameManager"):
		get_node("/root/GameManager").restart_game()
	else:
		# Direct restart fallback
		get_tree().reload_current_scene()

func reset_noise_level() -> void:
	"""Reset noise level to appropriate value for current state"""
	current_noise_level = 3 if current_state == MovementState.SNEAKING else 10

# Terrain noise system methods
func set_terrain_noise_multiplier(multiplier: float) -> void:
	"""Set the terrain noise multiplier (called by NoisyTerrain areas)"""
	terrain_noise_multiplier = multiplier
	if multiplier != 1.0:
		print("PLAYER TERRAIN DEBUG: Noise multiplier set to ", multiplier)

func is_player() -> bool:
	"""Helper method for terrain detection"""
	return true

func get_final_noise_radius(base_radius: float) -> float:
	"""Apply terrain multiplier to noise radius"""
	return base_radius * terrain_noise_multiplier

func is_any_guard_alerted() -> bool:
	"""Check if any guard in the scene is in ALERT state"""
	var guards = get_tree().get_nodes_in_group("guards")
	for guard in guards:
		if guard.has_method("get_current_state") and guard.get_current_state() == 1:  # GuardState.ALERT = 1
			return true
	return false

func restore_stamina() -> void:
	"""Restore stamina to full (called by peaches)"""
	current_stamina = MAX_STAMINA
	print("Stamina restored to full!")

func reset_keycard_variables() -> void:
	"""Reset all keycard Dialogic variables when winning a level"""
	# Reset all known keycard variables to false
	Dialogic.VAR.set("bluekey", false)
	Dialogic.VAR.set("redkey", false)
	Dialogic.VAR.set("greenkey", false)
	
	# Reset stamina to empty for the next level
	current_stamina = 0.0
	
	print("All keycard variables reset and stamina emptied")
