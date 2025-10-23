# ==============================================================================
# SPIKE TRAP - Animated Environmental Hazard System  
# ==============================================================================
#
# USER CONTEXT:
# This script controls animated spike traps that emerge from the ground in
# timed cycles. Players must time their movement to avoid deadly spikes that
# follow a predictable pattern: down (safe) → warning → rising → up (deadly)
# → retracting → down again. Each spike trap operates independently with
# configurable timing. Touching spikes when they're up kills the player.
# Visual and collision feedback help players learn the timing patterns.
#
# AI CONTEXT:
# StaticBody2D with AnimatedSprite2D for 8-frame spike animation cycle.
# SpikeState enum manages DOWN/RISING/UP/RETRACTING states with timer-based
# transitions. Area2D DangerArea child handles player collision detection.
# Collision shape enabled/disabled based on spike state for accurate hitbox.
# Configurable @export timing variables for cycle customization. Death
# triggering via player get_caught() method call. Animation freeze capability
# for game over states. Frame-based animation with manual frame control
# instead of AnimationPlayer for precise timing synchronization.
# ==============================================================================

extends StaticBody2D

@export var spike_frames := 8  # Total animation frames (0-7)
@export var cycle_time := 2.0  # Time for full up/down cycle
@export var warning_time := 0.8  # Time spikes stay down before rising (more time)
@export var danger_time := 1.2  # Time spikes stay up (deadly)
@export var retract_time := 0.6  # Time to retract back down
@export var safe_grace_time := 0.2  # Extra safe time after spikes visually retract

@onready var sprite := $AnimatedSprite2D
@onready var collision := $CollisionShape2D
@onready var danger_area := $DangerArea2D

var current_frame := 0
var cycle_timer := 0.0
var current_state := SpikeState.DOWN
var is_frozen := false  # Flag to freeze animation when player dies

enum SpikeState {
	DOWN,      # Frame 0 - Safe
	RISING,    # Frames 1-3 - Frame 1 safe, 2-3 deadly (going up)
	UP,        # Frame 4 - Deadly (fully extended)
	RETRACTING, # Frames 5-7 - Frames 5-6 deadly, 6-7 safe (going down)
	SAFE_GRACE  # Extra safe period after visual retraction
}

func _ready():
	# Start with spikes down (safe)
	sprite.frame = 0
	collision.disabled = true  # No collision when down
	
	# Set up danger area to detect player (layer 1)
	if danger_area:
		danger_area.collision_mask = 1  # Detect player layer
		danger_area.body_entered.connect(_on_danger_area_entered)
		print("Setting up danger area...")
		
		# Make sure the area has a collision shape
		var area_collision_shape = null
		for child in danger_area.get_children():
			if child is CollisionShape2D:
				area_collision_shape = child
				break
		
		if area_collision_shape == null:
			print("Creating collision shape for danger area...")
			area_collision_shape = CollisionShape2D.new()
			var area_shape = RectangleShape2D.new()
			area_shape.size = Vector2(16, 16)
			area_collision_shape.shape = area_shape
			danger_area.add_child(area_collision_shape)
		else:
			print("Danger area already has collision shape")
	
	# Set up animation frames
	if sprite and sprite.sprite_frames:
		# Assuming your spike animation is called "spike"
		sprite.play("spike")
		sprite.pause()  # We'll control frames manually
	
	# Force Z ordering after everything is ready
	call_deferred("_set_z_ordering")

func _set_z_ordering():
	# Make spikes render above tilemap but below player
	z_index = 1
	z_as_relative = false  # Use absolute Z ordering
	sprite.z_index = 1  # Also set sprite's Z index explicitly
	sprite.z_as_relative = false
	print("Z ordering set: ", z_index, " sprite: ", sprite.z_index)

func _physics_process(delta):
	# Don't update animation if frozen
	if is_frozen:
		return
		
	cycle_timer += delta
	
	match current_state:
		SpikeState.DOWN:
			if cycle_timer >= warning_time:
				current_state = SpikeState.RISING
				cycle_timer = 0.0
		
		SpikeState.RISING:
			var progress = cycle_timer / (cycle_time * 0.25)  # 25% of cycle to rise
			current_frame = int(progress * 3) + 1  # Frames 1-3 (rising)
			sprite.frame = min(current_frame, 3)
			collision.disabled = false  # Enable collision when rising
			
			if cycle_timer >= (cycle_time * 0.25):
				current_state = SpikeState.UP
				cycle_timer = 0.0
				sprite.frame = 4  # Fully extended
		
		SpikeState.UP:
			sprite.frame = 4  # Fully extended frame
			if cycle_timer >= danger_time:
				current_state = SpikeState.RETRACTING
				cycle_timer = 0.0
		
		SpikeState.RETRACTING:
			var progress = cycle_timer / retract_time
			current_frame = 5 + int(progress * 3)  # Frames 5-7 (retracting)
			sprite.frame = min(current_frame, 7)
			
			if cycle_timer >= retract_time:
				current_state = SpikeState.SAFE_GRACE
				cycle_timer = 0.0
				sprite.frame = 0  # Back to safe position
				collision.disabled = true  # Disable collision when down
		
		SpikeState.SAFE_GRACE:
			sprite.frame = 0  # Keep spikes visually down
			if cycle_timer >= safe_grace_time:
				current_state = SpikeState.DOWN
				cycle_timer = 0.0

func _on_danger_area_entered(body: Node2D):
	print("Spike area entered by: ", body.name, " State: ", current_state, " Frame: ", sprite.frame)
	
	# Determine if current frame is deadly
	var is_deadly = false
	
	match current_state:
		SpikeState.RISING:
			# Only frames 2-3 are deadly during rising (frame 1 is safe)
			if sprite.frame >= 2 and sprite.frame <= 3:
				is_deadly = true
		SpikeState.UP:
			# Frame 4 is always deadly
			is_deadly = true
		SpikeState.RETRACTING:
			# Only frame 5 is deadly during retracting (frames 6-7 are safe)
			if sprite.frame == 5:
				is_deadly = true
		# DOWN and SAFE_GRACE are always safe
	
	if is_deadly and body.has_method("get_caught"):
		print("Player hit spike trap! Killing player at deadly frame: ", sprite.frame)
		freeze_animation()  # Freeze spikes at moment of death
		body.get_caught()
	else:
		print("Spikes are safe at frame: ", sprite.frame)

func freeze_animation():
	"""Freeze spike animation at current state"""
	is_frozen = true
	print("Spike animation frozen at state: ", current_state, " frame: ", sprite.frame)

func unfreeze_animation():
	"""Resume spike animation (called when game restarts)"""
	is_frozen = false
	print("Spike animation unfrozen")

func reset_trap():
	"""Reset trap to initial state (useful for level restarts)"""
	is_frozen = false  # Unfreeze animation
	current_state = SpikeState.DOWN
	cycle_timer = 0.0
	sprite.frame = 0
	collision.disabled = true
