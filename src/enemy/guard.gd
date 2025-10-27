# ==============================================================================
# ENEMY GUARD - AI-Controlled Guard with Patrol/Alert/Investigation System
# ==============================================================================
#
# USER CONTEXT:
# This script controls enemy guards that patrol areas, detect the player through
# vision and hearing, and respond with different behaviors. Key systems include:
# - Patrol system: Guards walk between assigned waypoints at random speeds
# - Vision system: Cone-based sight with peripheral detection and stealth modifiers
# - Alert system: When player spotted, guard chases and shoots, alerts nearby guards
# - Investigation system: Guards investigate noise locations and player positions
# - Scanning system: Guards occasionally stop and look around during patrol
# - State icons: Alert (!) and investigation (?) icons appear above guard heads
# - Shooting system: Guards shoot bullets when player is in range and visible
# - Catch system: Physical contact with guards triggers player death
#
# AI CONTEXT:
# CharacterBody2D with NavigationAgent2D for pathfinding. GuardState enum manages
# PATROL/ALERT/INVESTIGATE/SCANNING states. Vision system uses RayCast2D with
# configurable cone angle, range, and collision masks. Noise detection via
# player noise_event signal with radius overlap checks. Alert propagation system
# notifies guards group within radius. AnimatedSprite2D StateIcon for visual
# feedback. Shooting creates RigidBody2D bullets with collision/particle systems.
# Extensive @export variables for tweaking AI behavior. Hysteresis system prevents
# behavior oscillation. Investigation escalation tracks player evasion attempts.
# Debug visualization with vision cones and patrol routes via _draw() override.
# ==============================================================================

extends CharacterBody2D

enum GuardState { PATROL, ALERT, INVESTIGATE, SCANNING }

# Performance constants
const VISION_CHECK_INTERVAL := 0.1  # Check vision 10 times per second
const ICON_DURATION := 1.5  # How long to show state icons
const CLOSE_RANGE_DETECTION := 7.5  # Very close range detection (scaled from 15.0)
const MOVEMENT_THRESHOLD := 5.0  # Minimum velocity to be considered "moving" (scaled from 10.0)

# Key Inspector Variables - Core Mechanics
@export var enemy_speed := 25.0  # Main enemy movement speed (used during alert/chase)
@export var view_angle := 90.0  # Total angle of the vision cone (degrees)  
@export var view_distance := 75.0  # Main vision detection range
@export var alert_time := 1.5  # Time before aggressive behavior starts in alert state

# Patrol System
@export var patrol_points: Array[Node2D] = []
@export var min_patrol_speed := 15.0  # Minimum patrol speed
@export var max_patrol_speed := 25.0  # Maximum patrol speed
@export var stationary := false  # If true, guard will not move from initial position
@export var wait_time := 0.0 # How long to wait at each patrol point

# Vision System
@export var target: Node2D
@export var num_rays := 8  # Number of rays in the cone
@export var peripheral_range := 9.5  # Close range detection radius
@export var peripheral_rays := 16  # More rays for smoother circle
@export var vision_collision_mask := 7  # Which layers block vision (1=player, 2=walls, 4=obstacles)

# Combat System  
@export var shoot_range := 56.25  # Shooting range
@export var melee_range := 25.0  # Close range for melee attacks
@export var chase_range := 100.0  # Maximum range to start chasing player
@export var shoot_cooldown := 1.0  # Time between shots
@export var bullet_speed := 150.0  # Speed of the bullet
@export var always_shoot := false # If true, guard continuously shoots in facing direction
@export_file("*.wav") var gun_fire_sfx := ""  # Sound effect to play when guard shoots (should be quiet)

# Behavior System
@export var investigation_wait_time := 3.0  # Time to investigate at a location
@export var scan_chance := 0.6  # 60% chance to scan at patrol points
@export var mid_patrol_scan_chance := 0.15  # 15% chance to scan mid-patrol
@export var mid_patrol_scan_interval := 2.0  # Check every 2 seconds during patrol
@export var reverse_patrol_chance := 0.3  # 30% chance to reverse direction after mid-patrol scan
@export var min_scan_time := 3.0  # Minimum scanning time
@export var max_scan_time := 6.0  # Maximum scanning time
@export var scan_rotation_speed := 2.0  # How fast they turn during scan

# Debug
@export var show_debug_visuals := false  # Toggle to show/hide vision cones and patrol routes
@export var sprite_facing_offset := 0.0  # Degrees to add to sprite rotation if asset faces different direction

# Hysteresis values to prevent oscillation between behaviors
var current_behavior_zone := "none"  # Track current behavior to add hysteresis
const HYSTERESIS_BUFFER := 5.0  # Buffer zone to prevent rapid switching

var current_patrol_index := 0
var current_state: GuardState = GuardState.PATROL
var player: Node2D
var last_known_position: Vector2
var base_patrol_speed: float  # Store the randomized patrol speed
var movement_speed: float  # Current movement speed (dynamically adjusted based on state)

# Scanning variables
var is_scanning := false
var scan_timer := 0.0

# Debug throttling variables
var debug_timer := 0.0
var debug_interval := 1.0  # Print debug info once per second max
var last_hearing_result := false  # Track changes in hearing result
var scan_duration := 0.0
var scan_directions: Array[float] = []
var current_scan_index := 0
var scan_target_angle := 0.0
var mid_patrol_timer := 0.0  # Timer for mid-patrol scan checks
var should_reverse_patrol := false  # Flag to reverse patrol direction after scan

var investigation_timer := 0.0
var investigation_position := Vector2.ZERO
var last_patrol_index := 0
var last_shot_time := 0.0  # Track when we last shot
var is_shooting := false  # Flag to track if currently shooting
var last_heard_noise_distance := INF  # Track distance to last heard noise
var noise_cooldown := 0.0  # Cooldown timer for noise responses
const NOISE_RESPONSE_COOLDOWN := 0.5  # Only respond to noise every 0.5 seconds

# Stuck detection system
var stuck_detection_timer := 0.0
var last_position_check := Vector2.ZERO
const STUCK_CHECK_INTERVAL := 2.0  # Check every 2 seconds
const STUCK_MOVEMENT_THRESHOLD := 10.0  # If moved less than 10 units in 2 seconds, consider stuck

@onready var nav_agent := $NavigationAgent2D
@onready var sprite: Sprite2D = $Sprite2D
@onready var ray_cast := $RayCast2D
@onready var catch_area := $CatchArea2D
@onready var state_icon: AnimatedSprite2D = $StateIcon

var current_facing_angle := 0.0
var target_facing_angle := 0.0
var has_seen_player := false  # Track if guard has spotted the player
var is_game_over := false  # Flag to freeze guard during game over/death
@export var rotation_speed := 5.0  # Adjust this to control turn speed

# State icon variables
var vision_check_timer := 0.0
var vision_check_interval := VISION_CHECK_INTERVAL
var last_player_visible := false  # Cache the result

# State icon variables
var icon_timer := 0.0
var icon_duration := ICON_DURATION

# Alert system variables
var alert_timer := 0.0  # Track how long we've been in alert state

# Investigation escalation system
var consecutive_investigations := 0  # Track how many times guard has been led to investigate
const MAX_INVESTIGATIONS_BEFORE_SUSPICIOUS := 4  # After 4 investigations, guard becomes suspicious
var total_investigation_time := 0.0  # Track total time spent investigating
const MAX_INVESTIGATION_TIME := 16.0  # If investigating for more than 8 seconds, become alert



func on_player_died() -> void:
	"""Called when the player dies - freeze all guard behavior"""
	is_game_over = true
	velocity = Vector2.ZERO

func freeze_guard() -> void:
	"""Called when player wins - freeze all guard behavior"""
	is_game_over = true
	velocity = Vector2.ZERO
	set_physics_process(false)  # Stop all physics updates

func _ready() -> void:
	# Auto-bind patrol points from scene if not assigned via export
	auto_bind_patrol_points()
	
	# If no patrol points assigned, create a spawn point marker so guard stays at spawn
	if patrol_points.size() == 0:
		var spawn_marker = Node2D.new()
		spawn_marker.name = name + "_SpawnPoint"
		spawn_marker.global_position = global_position
		add_child(spawn_marker)
		patrol_points.append(spawn_marker)
		#print("Guard ", name, " has no patrol points - created spawn point at ", global_position)

	if target == null:
		push_warning("Guard has no target assigned; some logic may fail.")
	player = target
	
	# Add this guard to the guards group for alert checking
	add_to_group("guards")
	
	# Configure RayCast2D for vision (detect walls and obstacles)
	if ray_cast:
		# Use the configurable collision mask for vision detection
		# Default: Layer 1 (player) + Layer 2 (walls) + Layer 3 (obstacles/crates)
		ray_cast.collision_mask = vision_collision_mask
		ray_cast.collide_with_areas = false  # Only detect bodies, not areas
		ray_cast.collide_with_bodies = true
	
	# Randomize patrol speed for this guard
	base_patrol_speed = randf_range(min_patrol_speed, max_patrol_speed)
	movement_speed = base_patrol_speed
	
	# Ensure sprite exists
	assert(sprite != null)
	
	# Connect the catch area signal
	if catch_area:
		catch_area.body_entered.connect(_on_catch_area_body_entered)
	
	# Connect to player's noise events
	if player and player.has_signal("noise_event"):
		player.noise_event.connect(_on_noise_event)
	
	# Ensure game over flag is reset when scene restarts
	is_game_over = false

	if stationary:
		movement_speed = 0.0
		change_state(GuardState.PATROL)
	
	setup()

func setup() -> void:
	await get_tree().physics_frame
	
	# Configure NavigationAgent2D
	nav_agent.path_desired_distance = 4.0
	nav_agent.target_desired_distance = 4.0
	nav_agent.path_max_distance = 10.0
	
	# Pick the closest patrol point as the starting point, then advance to it
	set_nearest_patrol_as_start()
	set_next_patrol_point()

func reset_guard_state() -> void:
	"""Reset guard to initial patrol state (called on game restart)"""
	is_game_over = false
	current_state = GuardState.PATROL
	velocity = Vector2.ZERO
	has_seen_player = false
	investigation_timer = 0.0
	last_shot_time = 0.0
	is_shooting = false
	consecutive_investigations = 0  # Reset investigation counter
	total_investigation_time = 0.0  # Reset investigation timer
	
	# Reset patrol
	current_patrol_index = 0
	movement_speed = base_patrol_speed
	set_next_patrol_point()
	pass

func _physics_process(delta: float) -> void:
	# Don't process if game is over
	if is_game_over:
		velocity = Vector2.ZERO
		move_and_slide()
		return
	
	# Update debug timer for throttling debug output
	debug_timer += delta
	
	# Update noise cooldown timer
	if noise_cooldown > 0.0:
		noise_cooldown -= delta
	
	# Stuck detection for patrol state with multiple patrol points
	if current_state == GuardState.PATROL and patrol_points.size() > 1:
		stuck_detection_timer += delta
		if stuck_detection_timer >= STUCK_CHECK_INTERVAL:
			var distance_moved = global_position.distance_to(last_position_check)
			if distance_moved < STUCK_MOVEMENT_THRESHOLD:
				# Guard hasn't moved significantly - skip to next patrol point
				if debug_timer >= debug_interval:
					print("GUARD STUCK DEBUG: Guard at ", global_position, " only moved ", distance_moved, " units in ", STUCK_CHECK_INTERVAL, " seconds - advancing to next patrol point")
				set_next_patrol_point()
			
			# Reset timer and position
			stuck_detection_timer = 0.0
			last_position_check = global_position
	
	# Track alert timer
	if current_state == GuardState.ALERT:
		alert_timer += delta
	else:
		alert_timer = 0.0  # Reset when not in alert
	
	# Handle state icon timer (but keep alert and investigation icons visible during their states)
	if state_icon and state_icon.visible:
		icon_timer += delta
		# Only hide icon after timer if NOT in alert or investigation state
		if icon_timer >= icon_duration and current_state != GuardState.ALERT and current_state != GuardState.INVESTIGATE:
			hide_state_icon()
	
	# Handle always_shoot behavior
	if always_shoot:
		if !is_shooting:
			var current_time = Time.get_time_dict_from_system()["second"] + Time.get_time_dict_from_system()["minute"] * 60
			var time_since_last_shot = current_time - last_shot_time
			
			if time_since_last_shot >= shoot_cooldown:
				if stationary:
					# Stationary turrets: shoot in facing direction continuously
					var facing_direction = Vector2.RIGHT.rotated(deg_to_rad(current_facing_angle))
					shoot_in_direction(facing_direction)
				else:
					# Non-stationary guards: only shoot when they can see the player
					if can_see_player():
						shoot_at_player()
	
	match current_state:
		GuardState.PATROL:
			handle_patrol_state()
		GuardState.ALERT:
			handle_alert_state()
		GuardState.INVESTIGATE:
			handle_investigate_state(delta)
		GuardState.SCANNING:
			handle_scanning_state(delta)

	if stationary:
		velocity = Vector2.ZERO
		move_and_slide()
	
	# Handle rotation for all guards (including stationary ones)
	# Smoothly interpolate to target angle
	current_facing_angle = lerp_angle(
		deg_to_rad(current_facing_angle),
		deg_to_rad(target_facing_angle),
		delta * rotation_speed
	)
	current_facing_angle = rad_to_deg(current_facing_angle)
	
	# Update sprite direction for stationary guards
	if stationary:
		# Rotate sprite to face the current direction, accounting for asset facing
		sprite.rotation = deg_to_rad(current_facing_angle + sprite_facing_offset)
		# Redraw vision cone to match new facing direction
		queue_redraw()
		return
	
	# Improved movement code (only if not scanning and has multiple patrol points)
	if current_state != GuardState.SCANNING and !nav_agent.is_navigation_finished() and (current_state != GuardState.PATROL or patrol_points.size() > 1):
		var next_pos = nav_agent.get_next_path_position()
		var dir = global_position.direction_to(next_pos)
		
		# Normal movement logic
		# Update target angle based on movement direction (but not when shooting)
		if dir.length() > 0.1 and !is_shooting:  # Only update when actually moving and not shooting
			target_facing_angle = rad_to_deg(dir.angle())
		
		# Ensure consistent movement speed
		velocity = dir * movement_speed
		
		move_and_slide()
		
		# Update sprite direction
		sprite.rotation = deg_to_rad(current_facing_angle + sprite_facing_offset)
	else:
		# Navigation fallback: if no path is available, walk directly toward patrol target
		if current_state == GuardState.PATROL and patrol_points.size() > 1:
			var patrol_target: Vector2 = patrol_points[current_patrol_index].global_position
			var dir_fb = global_position.direction_to(patrol_target)
			if dir_fb.length() > 0.01:
				# Move
				velocity = dir_fb * movement_speed
				move_and_slide()
				sprite.rotation = deg_to_rad(current_facing_angle + sprite_facing_offset)
			# Consider we have reached the point when close enough
			if global_position.distance_to(patrol_target) <= 6.0:
				set_next_patrol_point()
		else:
			# No movement in other states
			pass
	
	# Handle scanning rotation separately
	if current_state == GuardState.SCANNING:
		handle_scan_rotation(delta)
	

	
	queue_redraw()

func handle_patrol_state() -> void:
	if can_see_player():
		change_state(GuardState.ALERT)
		return
	
	# If only 1 patrol point (spawn point), stay in place - don't try to navigate
	if patrol_points.size() <= 1:
		velocity = Vector2.ZERO
		move_and_slide()
		return
	
	# Check for mid-patrol scanning while moving (only when actually en route)
	if !nav_agent.is_navigation_finished():
		mid_patrol_timer += get_process_delta_time()
		if mid_patrol_timer >= mid_patrol_scan_interval:
			mid_patrol_timer = 0.0
			if randf() < mid_patrol_scan_chance:
				# Decide if we should reverse patrol direction after scan
				should_reverse_patrol = randf() < reverse_patrol_chance
				setup_scan()
				change_state(GuardState.SCANNING)
				return
	
	# Handle reaching patrol points: only advance when actually near the target
	if nav_agent.is_navigation_finished():
		# Reset mid-patrol timer when reaching a point
		mid_patrol_timer = 0.0
		# Consider we have reached the point only if within threshold
		if patrol_points.size() > 0:
			var target_pos = patrol_points[current_patrol_index].global_position
			var distance = global_position.distance_to(target_pos)
			if distance <= 6.0:
				# Random chance to scan at patrol point
				if randf() < scan_chance:
					should_reverse_patrol = false  # Don't reverse at patrol points
					setup_scan()
					change_state(GuardState.SCANNING)
				else:
					set_next_patrol_point()
	
	# Actually move the guard towards the target (only if we have multiple patrol points)
	if patrol_points.size() > 1:
		var direction = nav_agent.get_next_path_position() - global_position
		direction = direction.normalized()
		velocity = direction * movement_speed
		
		# Update sprite direction based on movement
		if velocity.length() > 0.1:
			sprite.rotation = deg_to_rad(current_facing_angle + sprite_facing_offset)
		
		move_and_slide()

func handle_alert_state() -> void:
	# Always update last known position
	last_known_position = player.global_position
	
	var distance_to_player = global_position.distance_to(player.global_position)
	var current_time = Time.get_time_dict_from_system()["second"] + Time.get_time_dict_from_system()["minute"] * 60
	var time_since_last_shot = current_time - last_shot_time
	var can_see = can_see_player()
	
	# Use hysteresis to prevent oscillation between zones
	var effective_melee_range = melee_range
	var effective_shoot_range = shoot_range
	var effective_chase_range = chase_range
	
	# Adjust ranges based on current behavior to add hysteresis
	if current_behavior_zone == "melee":
		effective_melee_range += HYSTERESIS_BUFFER  # Stay in melee longer
	elif current_behavior_zone == "shoot":
		effective_melee_range -= HYSTERESIS_BUFFER  # Easier to enter melee
		effective_shoot_range += HYSTERESIS_BUFFER  # Stay in shooting longer
	elif current_behavior_zone == "chase":
		effective_shoot_range -= HYSTERESIS_BUFFER  # Easier to enter shooting
		effective_chase_range += HYSTERESIS_BUFFER  # Stay in chase longer
	
	# Zone 1: MELEE RANGE - Rush to kill player directly
	if distance_to_player <= effective_melee_range:
		current_behavior_zone = "melee"
		if !is_shooting:
			nav_agent.target_position = player.global_position
			# Increase movement speed for melee rush
			movement_speed = enemy_speed * 2.5  # Even faster melee rush
			
			# Check if close enough to kill (within 15 units - increased range)
			if distance_to_player <= 15.0:
				kill_player_melee()
		return
	
	# Zone 2: SHOOTING RANGE - Shoot while advancing
	elif distance_to_player <= effective_shoot_range:
		current_behavior_zone = "shoot"
		movement_speed = enemy_speed  # Fast alert movement
		
		if can_see and time_since_last_shot >= shoot_cooldown and !is_shooting:
			# Shoot while still advancing toward player
			shoot_at_player()
		
		# ALWAYS advance toward player in shooting range (removed hold position logic)
		if !is_shooting:
			nav_agent.target_position = player.global_position
		return
	
	# Zone 3: CHASE RANGE - Run to get into shooting range
	elif distance_to_player <= effective_chase_range:
		current_behavior_zone = "chase"
		movement_speed = enemy_speed * 1.2  # 20% faster than base alert speed for chasing
		
		if !is_shooting:
			nav_agent.target_position = player.global_position
		return
	
	# Zone 4: OUT OF RANGE - Lost the player, start investigating
	else:
		current_behavior_zone = "investigate"
		# Player is too far away, switch to investigate mode at last known position
		investigation_position = last_known_position
		investigation_timer = 0.0
		change_state(GuardState.INVESTIGATE)

func kill_player_melee() -> void:
	"""Called when guard gets close enough for a melee kill"""
	if !is_instance_valid(player) or is_game_over:
		return
	
	# Trigger player death
	if player.has_method("get_caught"):
		player.get_caught()
	
	# Set game over flag
	is_game_over = true

func handle_investigate_state(delta: float) -> void:
	# Always increment total investigation time
	total_investigation_time += delta
	
	# FAILSAFE: If investigating too long, guard gives up and returns to patrol
	if total_investigation_time > MAX_INVESTIGATION_TIME:
		total_investigation_time = 0.0
		consecutive_investigations = 0  # Reset investigation counter
		# SMART: Find nearest patrol point instead of using potentially invalid last_patrol_index
		set_nearest_patrol_as_start()
		change_state(GuardState.PATROL)
		return
	
	if can_see_player():
		# Player spotted during investigation - reset counters and go to alert
		consecutive_investigations = 0
		total_investigation_time = 0.0
		change_state(GuardState.ALERT)
		return
	
	# Check if investigation is complete
	if nav_agent.is_navigation_finished():
		investigation_timer += delta
		
		# Face the investigation position while waiting
		var direction_to_target = (investigation_position - global_position).normalized()
		if direction_to_target.length() > 0.01:
			target_facing_angle = rad_to_deg(direction_to_target.angle())
			
			# Update sprite direction
			sprite.rotation = deg_to_rad(target_facing_angle + sprite_facing_offset)
		
		# Adjust investigation wait time based on suspicion level
		var effective_wait_time = investigation_wait_time
		if consecutive_investigations >= MAX_INVESTIGATIONS_BEFORE_SUSPICIOUS:
			effective_wait_time = investigation_wait_time * 0.5  # Suspicious guards give up faster
		
		if investigation_timer >= effective_wait_time:
			# Investigation complete - return to patrol normally (this resets suspicion)
			consecutive_investigations = 0
			total_investigation_time = 0.0
			# SMART: Find the nearest patrol point instead of trying to return to old position
			set_nearest_patrol_as_start()
			change_state(GuardState.PATROL)

func change_state(new_state: GuardState) -> void:
	if new_state == current_state:
		return
	
	current_state = new_state
	
	# Reset alert state when changing from alert
	if new_state != GuardState.ALERT:
		alert_timer = 0.0
		collision_mask = 7  # Restore normal collision
		# Reset navigation settings
		nav_agent.avoidance_enabled = true
		nav_agent.path_max_distance = 10.0
		nav_agent.path_desired_distance = 4.0
		nav_agent.target_desired_distance = 4.0
	
	# Force icon change when transitioning states
	match new_state:
		GuardState.ALERT:
			show_alert_icon()
		GuardState.INVESTIGATE:
			show_investigate_icon()
		GuardState.PATROL, GuardState.SCANNING:
			hide_state_icon()
	
	match new_state:
		GuardState.PATROL:
			movement_speed = base_patrol_speed  # Use randomized speed
			mid_patrol_timer = 0.0  # Reset mid-patrol timer
			set_next_patrol_point()
		GuardState.ALERT:
			consecutive_investigations = 0  # Reset when actually spotting player
			total_investigation_time = 0.0  # Reset investigation timer
			movement_speed = enemy_speed  # Faster alert speed (swapped with investigation)
			nav_agent.target_position = player.global_position
		GuardState.INVESTIGATE:
			consecutive_investigations += 1  # Increment investigation counter
			# DON'T reset total_investigation_time here - let it accumulate across interruptions
			
			# Set investigation speed based on suspicion level
			if consecutive_investigations >= MAX_INVESTIGATIONS_BEFORE_SUSPICIOUS:
				movement_speed = enemy_speed  # Alert speed when suspicious
			else:
				movement_speed = base_patrol_speed  # Normal slow investigation speed
			
			investigation_timer = 0.0
			nav_agent.target_position = investigation_position
			
			# Debug: Show where we're actually navigating to
			if debug_timer >= debug_interval:
				#print("GUARD STATE DEBUG: Entering INVESTIGATE state - nav target set to ", investigation_position)
				pass
		GuardState.SCANNING:
			velocity = Vector2.ZERO  # Stop moving while scanning
	
	# If this guard just entered ALERT state, alert nearby guards
	if new_state == GuardState.ALERT:
		alert_nearby_guards()

func alert_nearby_guards() -> void:
	"""Alert other guards within range instantly - no sound checks"""
	var all_guards = get_tree().get_nodes_in_group("guards")
	var alert_radius = 500.0  # Much larger radius to cover the level better
	
	for guard in all_guards:
		if guard == self:  # Don't alert self
			continue
		if guard.current_state == GuardState.ALERT:  # Already alerted
			continue
			
		var distance = global_position.distance_to(guard.global_position)
		
		if distance <= alert_radius:
			# Instantly alert nearby guards as if they saw the player too
			guard.has_seen_player = true
			guard.last_known_position = player.global_position
			guard.change_state(GuardState.ALERT)

func show_alert_icon() -> void:
	"""Show alert exclamation icon above the guard's head"""
	if !state_icon:
		return
	
	state_icon.frame = 0  # Frame 0 = alert icon
	state_icon.visible = true
	icon_timer = 0.0  # Reset timer so icon stays visible
	
	# Add a subtle bounce animation (scaled down by half for 16x16 sprite)
	var tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_BACK)
	state_icon.scale = Vector2(0.25, 0.25)  # Start smaller
	tween.tween_property(state_icon, "scale", Vector2(0.5, 0.5), 0.3)  # End at half size

func show_investigate_icon() -> void:
	"""Show investigation question icon above the guard's head"""
	if !state_icon:
		return
	
	state_icon.frame = 1  # Frame 1 = investigate icon
	state_icon.visible = true
	icon_timer = 0.0  # Reset timer so icon stays visible
	
	# Add a subtle bounce animation (scaled down by half for 16x16 sprite)
	var investigate_tween = create_tween()
	investigate_tween.set_ease(Tween.EASE_OUT)
	investigate_tween.set_trans(Tween.TRANS_BACK)
	state_icon.scale = Vector2(0.25, 0.25)  # Start smaller
	investigate_tween.tween_property(state_icon, "scale", Vector2(0.5, 0.5), 0.3)  # End at half size

func hide_state_icon() -> void:
	"""Hide the state icon"""
	if state_icon:
		state_icon.visible = false

func can_see_player() -> bool:
	if !is_instance_valid(player):
		return false
	
	# SNEAKING = COMPLETE INVISIBILITY: Guards cannot see sneaking players at all
	var is_player_crouched = player.has_method("is_sneaking") and player.is_sneaking()
	if is_player_crouched:
		return false  # Player is completely invisible when sneaking
	
	var distance_to_player = global_position.distance_to(player.global_position)
	
	# IMMEDIATE CLOSE-RANGE DETECTION - if player is very close, they're always visible
	if distance_to_player <= CLOSE_RANGE_DETECTION:
		has_seen_player = true
		return true
	
	# Check if player is within detection range first (optimization)
	if distance_to_player > view_distance:
		return false
	
	# Check if player is in the vision cone angle
	var direction_to_player = (player.global_position - global_position).normalized()
	var player_angle = rad_to_deg(direction_to_player.angle())
	var angle_diff = abs(angle_difference(deg_to_rad(current_facing_angle), deg_to_rad(player_angle)))
	var half_vision_angle = deg_to_rad(view_angle / 2.0)
	
	var player_in_cone = false
	var player_in_peripheral = false
	
	# Check peripheral vision (close range, 360 degrees)
	if distance_to_player <= peripheral_range:
		player_in_peripheral = true
	
	# Check main vision cone
	if angle_diff <= half_vision_angle:
		player_in_cone = true
	
	# If player is not in either vision area, return false
	if !player_in_cone and !player_in_peripheral:
		return false
	
	# Now check if anything is blocking the line of sight
	ray_cast.target_position = direction_to_player * distance_to_player
	ray_cast.force_raycast_update()
	
	if ray_cast.is_colliding():
		var collider = ray_cast.get_collider()
		if collider == player:
			# Player is the first thing we hit - they're visible
			has_seen_player = true
			return true
		else:
			# Something else is blocking the view
			return false
	else:
		# No collision at all - player should be visible if they're in range and angle
		if player_in_cone or player_in_peripheral:
			has_seen_player = true
			return true
	
	return false

func set_next_patrol_point() -> void:
	if patrol_points.size() == 0:
		return
	current_patrol_index = (current_patrol_index + 1) % patrol_points.size()
	nav_agent.target_position = patrol_points[current_patrol_index].global_position

func reverse_patrol_direction() -> void:
	# Go back to the previous patrol point
	if patrol_points.size() == 0:
		return
	current_patrol_index = (current_patrol_index - 1 + patrol_points.size()) % patrol_points.size()
	nav_agent.target_position = patrol_points[current_patrol_index].global_position

# --- Patrol points helpers ---
func auto_bind_patrol_points() -> void:
	# If patrol points are already assigned in the inspector, respect that
	if patrol_points.size() > 0:
		return
	
	# ONLY check for per-guard patrol points (child container)
	var container: Node = null
	if has_node("PatrolPoints"):
		container = get_node("PatrolPoints")
	
	# Don't auto-bind global patrol points - guards without assigned points stay at spawn
	if container:
		var pts: Array[Node2D] = []
		for child in container.get_children():
			if child is Node2D:
				pts.append(child)
		if pts.size() > 0:
			patrol_points = pts

func set_nearest_patrol_as_start() -> void:
	if patrol_points.size() == 0:
		return
	var nearest_index := 0
	var nearest_dist := INF
	for i in patrol_points.size():
		var d = global_position.distance_to(patrol_points[i].global_position)
		if d < nearest_dist:
			nearest_dist = d
			nearest_index = i
	# We set current_patrol_index to the element right before the nearest,
	# so that set_next_patrol_point() advances to the nearest one.
	current_patrol_index = (nearest_index - 1 + patrol_points.size()) % patrol_points.size()

func _on_velocity(safe_velocity: Vector2) -> void:
	velocity = safe_velocity
	move_and_slide()

func setup_scan() -> void:
	# Randomize scan duration
	scan_duration = randf_range(min_scan_time, max_scan_time)
	scan_timer = 0.0
	current_scan_index = 0
	
	# Generate scan directions optimized for left/right flipping with static sprite
	var possible_directions = [0.0, 180.0]  # right, left only for visible flip
	scan_directions.clear()
	
	# Random number of directions to scan (2-4) to ensure visible look-around
	var num_scans = randi_range(2, 4)
	for i in num_scans:
		var random_direction = possible_directions[randi() % possible_directions.size()]
		scan_directions.append(random_direction)
	
	# Set first scan target
	if scan_directions.size() > 0:
		scan_target_angle = scan_directions[0]

func handle_scanning_state(delta: float) -> void:
	# Always check for player during scanning
	if can_see_player():
		change_state(GuardState.ALERT)
		return
	
	# Stop moving while scanning
	velocity = Vector2.ZERO
	move_and_slide()
	
	scan_timer += delta
	
	# Handle the actual scanning rotation
	handle_scan_rotation(delta)
	
	# Check if scan is complete
	if scan_timer >= scan_duration:
		# Handle patrol direction after scan
		if should_reverse_patrol:
			reverse_patrol_direction()
		change_state(GuardState.PATROL)
		return

func handle_scan_rotation(delta: float) -> void:
	if current_scan_index >= scan_directions.size():
		return
	
	# Update sprite direction based on scan target angle
	var scan_angle = scan_target_angle
	# Normalize angle to 0-360 range
	while scan_angle < 0:
		scan_angle += 360
	while scan_angle >= 360:
		scan_angle -= 360
	
	# Rotate sprite to face the scan direction, accounting for asset facing
	sprite.rotation = deg_to_rad(scan_angle + sprite_facing_offset)

	# Smoothly rotate to target angle
	var angle_diff = angle_difference(deg_to_rad(current_facing_angle), deg_to_rad(scan_target_angle))
	if abs(angle_diff) > 0.1:  # Still rotating
		current_facing_angle = lerp_angle(
			deg_to_rad(current_facing_angle),
			deg_to_rad(scan_target_angle),
			delta * scan_rotation_speed
		)
		current_facing_angle = rad_to_deg(current_facing_angle)
	else:
		# Reached target angle, move to next scan direction
		current_scan_index += 1
		if current_scan_index < scan_directions.size():
			scan_target_angle = scan_directions[current_scan_index]





func _on_bullet_hit_player() -> void:
	# Same as physical collision with guard
	if !is_game_over:
		is_game_over = true
		change_state(GuardState.PATROL)
		velocity = Vector2.ZERO
		
		if player.has_method("get_caught"):
			player.get_caught()
		
		call_deferred("trigger_game_over")

func trigger_game_over() -> void:
	# Use GameManager if available, otherwise fallback to direct restart
	if has_node("/root/GameManager"):
		get_node("/root/GameManager").trigger_game_over()
	else:
		# Simple fallback - let player handle death animation and restart
		pass

func shoot_at_player() -> void:
	if !is_instance_valid(player) or is_game_over:
		return
	
	# Set shooting flag and stop movement temporarily
	is_shooting = true
	velocity = Vector2.ZERO
	
	# Face the player
	var direction_to_player = (player.global_position - global_position).normalized()
	
	target_facing_angle = rad_to_deg(direction_to_player.angle())
	
	print("DEBUG shoot_at_player: guard=", global_position, " player=", player.global_position, " direction=", direction_to_player, " angle=", target_facing_angle)
	
	# Create bullet immediately (no animation wait)
	create_bullet(direction_to_player)
	
	# Update last shot time
	last_shot_time = Time.get_time_dict_from_system()["second"] + Time.get_time_dict_from_system()["minute"] * 60
	
	# Reset shooting flag after a longer delay for better aim (increased from 0.5 to 0.8)
	get_tree().create_timer(0.8).timeout.connect(func(): is_shooting = false)

func shoot_in_direction(direction: Vector2) -> void:
	"""Shoot a bullet in the specified direction (for always_shoot mode)"""

	print("DEBUG shoot_in_direction: Called with direction=", direction, " current_facing_angle=", current_facing_angle, " state=", GuardState.keys()[current_state])
	
	if is_game_over:
		print("DEBUG shoot_in_direction: Game over, not shooting")
		return
	
	# Set shooting flag briefly
	is_shooting = true
	
	# Create bullet immediately
	create_bullet(direction)
	
	# Update last shot time
	last_shot_time = Time.get_time_dict_from_system()["second"] + Time.get_time_dict_from_system()["minute"] * 60
	
	# Reset shooting flag after a short delay
	get_tree().create_timer(0.3).timeout.connect(func(): 
		is_shooting = false
	)

func create_bullet(direction: Vector2) -> void:
	#print("DEBUG create_bullet: Creating bullet with direction=", direction, " speed=", bullet_speed)
	
	# Play gun fire sound effect if specified (positional audio - only hear when nearby)
	if gun_fire_sfx != "" and ResourceLoader.exists(gun_fire_sfx):
		var sfx = AudioStreamPlayer2D.new()
		sfx.stream = load(gun_fire_sfx)
		sfx.volume_db = -10.0  # Quiet volume (-10 dB)
		sfx.max_distance = 300.0  # Can hear from up to 300 pixels away
		sfx.attenuation = 2.0  # How quickly sound fades with distance (higher = faster fadeout)
		sfx.global_position = global_position  # Position sound at guard's location
		get_tree().root.add_child(sfx)
		sfx.play()
		sfx.finished.connect(sfx.queue_free)
	
	# Always create a simple bullet (skip problematic Bullet.tscn)
	var bullet = create_simple_bullet()
	#print("DEBUG create_bullet: Simple bullet created")
	
	# Set bullet properties BEFORE adding to scene (so _ready() uses correct values)
	bullet.global_position = global_position
	bullet.direction = direction
	bullet.speed = bullet_speed
	
	# Add to scene AFTER setting properties
	get_tree().current_scene.add_child(bullet)
	#print("DEBUG create_bullet: Bullet added to scene at position ", bullet.global_position)
	
	# Make bullet ignore the guard that shot it
	bullet.add_collision_exception_with(self)
	
	# Connect bullet hit signal
	if bullet.has_signal("hit_player"):
		bullet.hit_player.connect(_on_bullet_hit_player)
	
	#print("DEBUG create_bullet: Bullet fully configured and ready")

func create_simple_bullet() -> Node2D:
	# Create a simple bullet using built-in nodes
	var bullet = RigidBody2D.new()
	bullet.set_script(preload("res://src/projectiles/SimpleBullet.gd"))
	
	# Set bullet collision layers
	bullet.collision_layer = 8  # Layer 4 (bullets) = 2^3 = 8
	bullet.collision_mask = 18  # Layers 2 + 5 (walls + player_bullets) = 2 + 16 = 18
	
	# Add visual (small yellow circle) - FIXED: proper center calculation
	var sprite_node = Sprite2D.new()
	var texture = ImageTexture.new()
	var image = Image.create(6, 6, false, Image.FORMAT_RGBA8)  # Smaller: 6x6 for better size
	
	# Create a circular bullet instead of square
	for x in range(6):
		for y in range(6):
			var center = Vector2(3, 3)  # Center for 6x6 image
			var distance = Vector2(x, y).distance_to(center)
			if distance <= 2.0:  # Smaller circular shape
				image.set_pixel(x, y, Color.YELLOW)
			else:
				image.set_pixel(x, y, Color.TRANSPARENT)
	
	texture.set_image(image)
	sprite_node.texture = texture
	bullet.add_child(sprite_node)
	
	# Add collision
	var collision = CollisionShape2D.new()
	var shape = CircleShape2D.new()
	shape.radius = 1.5  # Smaller bullet collision to match 6x6 visual
	collision.shape = shape
	bullet.add_child(collision)
	
	# Add trail particles (GPUParticles2D)
	var trail_particles = GPUParticles2D.new()
	trail_particles.name = "GPUParticles2D"
	trail_particles.emitting = false
	trail_particles.amount = 50
	trail_particles.lifetime = 1.0
	# Create a simple particle material
	var trail_material = ParticleProcessMaterial.new()
	trail_material.direction = Vector3(0, 0, 0)
	trail_material.initial_velocity_min = 20.0
	trail_material.initial_velocity_max = 40.0
	trail_material.scale_min = 0.1
	trail_material.scale_max = 0.3
	trail_particles.process_material = trail_material
	bullet.add_child(trail_particles)
	
	# Add impact particles
	var impact_particles = GPUParticles2D.new()
	impact_particles.name = "ImpactParticles"
	impact_particles.emitting = false
	impact_particles.amount = 20
	impact_particles.lifetime = 0.5
	# Create impact particle material
	var impact_material = ParticleProcessMaterial.new()
	impact_material.direction = Vector3(0, 0, 0)
	impact_material.initial_velocity_min = 50.0
	impact_material.initial_velocity_max = 150.0
	impact_material.spread = 45.0
	impact_material.scale_min = 0.2
	impact_material.scale_max = 0.5
	impact_particles.process_material = impact_material
	bullet.add_child(impact_particles)
	
	return bullet

func _on_catch_area_body_entered(body: Node2D) -> void:
	# Check if the player has been caught and guard has previously seen them
	if body == player and has_seen_player and !is_game_over:

		
		# Mark game over but don't freeze everything
		is_game_over = true
		
		# Reset guard to patrol state (so they stop chasing)
		change_state(GuardState.PATROL)
		velocity = Vector2.ZERO
		
		# Notify player they've been caught (triggers death animation)
		if player.has_method("get_caught"):
			player.get_caught()
		
		# Defer the game over to avoid physics callback issues
		call_deferred("trigger_game_over")

func _on_noise_event(origin: Vector2, radius: float, noise_type: String) -> void:
	"""Handle noise events - check if noise radius touches guard"""
	if is_game_over:
		return
	
	# Calculate distance from noise origin to guard's center
	var distance_to_center = global_position.distance_to(origin)
	var guard_radius = 8.0  # Approximate guard collision radius
	
	# Check if noise radius reaches the guard (simple circle overlap)
	if radius < distance_to_center - guard_radius:
		# Noise doesn't reach us at all
		return
	
	# ONLY respond to udonge distractions (ignore player footsteps)
	if noise_type != "udonge":
		if debug_timer >= debug_interval:
			print("GUARD: Ignoring non-udonge noise (", noise_type, ") at ", origin)
		return
	
	# STATIONARY GUARDS: Rotate toward udonge noise but don't move
	if stationary:
		var direction_to_noise = (origin - global_position).normalized()
		if direction_to_noise.length() > 0.01:
			target_facing_angle = rad_to_deg(direction_to_noise.angle())
		
		if debug_timer >= debug_interval:
			print("GUARD: Stationary guard heard udonge at ", origin, " - looking toward it")
		return
	
	# Only respond if this noise is closer than the last one, or cooldown expired
	if noise_cooldown > 0.0 and distance_to_center >= last_heard_noise_distance:
		if debug_timer >= debug_interval:
			print("GUARD: Ignoring noise at ", origin, " (distance ", distance_to_center, ") - already responding to closer noise (", last_heard_noise_distance, ")")
		return
	
	# Update last heard noise distance and start cooldown
	last_heard_noise_distance = distance_to_center
	noise_cooldown = NOISE_RESPONSE_COOLDOWN
	
	# Investigate the NOISE ORIGIN (where udonge was thrown), not player position
	var investigation_target: Vector2 = origin
	
	if debug_timer >= debug_interval:
		print("GUARD NOISE DEBUG: Heard ", noise_type, " from ", origin, " - investigating ", investigation_target)
		print("GUARD POSITION DEBUG: Guard at ", global_position, " - Nav target will be ", investigation_target)
	
	# Investigate udonge distraction (patrol/scanning guards only)
	if current_state == GuardState.PATROL or current_state == GuardState.SCANNING:
		last_known_position = investigation_target
		investigation_position = investigation_target  # Set BEFORE changing state
		change_state(GuardState.INVESTIGATE)
		investigation_timer = 0.0
		
		# Increment consecutive investigations counter
		consecutive_investigations += 1
		
		if debug_timer >= debug_interval:
			print("GUARD: Investigating ", noise_type, " at ", investigation_target, " (investigation #", consecutive_investigations, ")")
			print("GUARD NAV DEBUG: Setting nav_agent.target_position to ", investigation_target)
	elif current_state == GuardState.INVESTIGATE:
		# Update to latest noise position
		last_known_position = investigation_target
		investigation_position = investigation_target
		investigation_timer = 0.0  # Reset investigation timer
		nav_agent.target_position = investigation_position  # Update nav target directly
		
		if debug_timer >= debug_interval:
			print("GUARD: Updated investigation target to ", noise_type, " position ", investigation_target)
			print("GUARD NAV DEBUG: Updated nav_agent.target_position to ", investigation_target)

func _draw() -> void:
	# Only draw debug visuals if enabled
	if !show_debug_visuals:
		return
	
	# Draw alert propagation range (large circle around guard)
	if current_state == GuardState.ALERT:
		draw_arc(Vector2.ZERO, 200.0, 0, TAU, 64, Color.RED * Color(1, 1, 1, 0.2), 2.0)  # Show the 200px alert radius
	
	# Hide ALL vision cones when ANY guard is in alert state
	# Check if this guard or any other guard in the scene is alerted
	var any_guard_alerted = current_state == GuardState.ALERT
	if !any_guard_alerted:
		# Check other guards in the scene
		var guards = get_tree().get_nodes_in_group("guards")
		for guard in guards:
			if guard != self and guard.has_method("get_current_state"):
				if guard.get_current_state() == GuardState.ALERT:
					any_guard_alerted = true
					break
	
	# Don't draw vision cones if any guard is alerted
	if any_guard_alerted:
		# Still draw patrol lines but no vision cones
		return
	
	var effective_detection_range = view_distance
	# Note: Peripheral vision circle removed - will be shown via inventory device later
	
	# Draw main vision cone (using effective range)
	var cone_color = Color.RED if current_state == GuardState.ALERT else Color.GREEN
	if current_state == GuardState.SCANNING:
		cone_color = Color.BLUE
	cone_color.a = 0.2
	
	var points = PackedVector2Array()
	points.append(Vector2.ZERO)
	
	for i in num_rays:
		# Apply debug cone offset to align with sprite facing direction
		var cone_angle = current_facing_angle 
		var angle = deg_to_rad(cone_angle - view_angle/2.0 + 
							(view_angle * i / (num_rays - 1)))
		var direction = Vector2.RIGHT.rotated(angle)
		
		# For visualization, always draw the full cone without collision checks
		var point = direction * effective_detection_range
		points.append(point)
	
	draw_colored_polygon(points, cone_color)

func get_current_state() -> GuardState:
	"""Helper function to get the current state - used by other guards to check alert status"""
	return current_state

func is_any_guard_alerted() -> bool:
	"""Check if any guard in the scene is in alert state"""
	var guards = get_tree().get_nodes_in_group("guards")
	for guard in guards:
		if guard.has_method("get_current_state") and guard.get_current_state() == GuardState.ALERT:
			return true
	return false
