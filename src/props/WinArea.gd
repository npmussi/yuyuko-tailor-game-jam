# ==============================================================================
# WIN AREA - Level Completion Trigger and Victory Screen System
# ==============================================================================
#
# USER CONTEXT:
# This script manages the win condition for each level. When the player enters
# the designated win area (usually a green highlighted zone), it:
# - Displays a full-screen "YOU WIN!" overlay with fade effects
# - Freezes all guards and game mechanics to prevent interference
# - Shows a countdown timer before automatically restarting the level
# - Provides hooks for future level progression (next_level_scene)
# - Prevents multiple triggers if player repeatedly enters the area
# The win area is typically placed at the end/goal of each level layout.
#
# AI CONTEXT:
# Area2D-based trigger system using body_entered signal detection. Creates
# CanvasLayer with ColorRect background and label UI on win trigger. Implements
# guard freezing via "guards" group node iteration and freeze_guard() calls.
# Uses Timer node for restart delay with automatic scene reloading. Future-proofed
# with next_level_scene export for level progression. Collision layer/mask
# configured for player detection only. Prevents duplicate win triggers with
# has_won boolean flag. Tween-based fade effects for smooth UI transitions.
# ==============================================================================

extends Area2D

@export var win_message := "YOU WIN!"
@export var restart_delay := 3.0  # Seconds to wait before restarting
@export_file("*.dtl") var timeline := ""  # Indicates which Dialogic timeline to play on win
@export_file("*.tscn") var next_level_scene := ""  # Set this to load next level (empty = restart current level)
@export_file("*.wav") var level_clear_sfx := ""  # Sound effect to play when level is cleared

var has_won := false  # Prevent multiple triggers

func _ready():
	# Connect the body_entered signal to our win function
	body_entered.connect(_on_player_entered)
	
	# Set up collision layers
	collision_layer = 0  # Win area doesn't collide with anything
	collision_mask = 1   # Only detect player (assuming player is on layer 1)

func _on_player_entered(body: Node2D):
	# Check if it's the player and we haven't already won
	if body.is_in_group("player") and !has_won:
		trigger_win()

func trigger_win():
	has_won = true
	
	# Print to console for debugging
	print(win_message)
	
	# Play level clear sound effect if specified
	if level_clear_sfx != "" and ResourceLoader.exists(level_clear_sfx):
		var sfx = AudioStreamPlayer.new()
		sfx.stream = load(level_clear_sfx)
		get_tree().root.add_child(sfx)
		sfx.play()
		sfx.finished.connect(sfx.queue_free)
		print("Playing level clear sound effect: ", level_clear_sfx)
	
	# Play Dialogic timeline if specified
	if timeline != "" and ResourceLoader.exists(timeline):
		print("Playing win timeline: ", timeline)
		var timeline_resource = ResourceLoader.load(timeline)
		if timeline_resource == null:
			push_warning("Failed to load timeline: %s" % timeline)
		else:
			freeze_player_and_guards()
			Dialogic.start(timeline_resource)
			# Connect to timeline_ended to proceed after dialogue finishes
			Dialogic.timeline_ended.connect(_on_win_timeline_finished)
			
			# Freeze player and guards but don't show win screen yet
			# (let the dialogue play first)
			return  # Exit early - will continue after dialogue
	
	# If no timeline or failed to load, proceed normally
	freeze_player_and_guards()
	# create_win_screen()  # Removed - no win screen
	
	# Proceed to next stage immediately
	proceed_to_next_stage()


func _on_win_timeline_finished() -> void:
	"""Called when the win timeline dialogue finishes"""
	# create_win_screen()  # Removed - no win screen
	
	# Proceed to next stage immediately
	proceed_to_next_stage()


func freeze_player_and_guards() -> void:
	"""Freeze player and guards (separated from trigger_win for reuse)"""
	# Freeze player completely - disable all input processing
	var player = get_tree().get_first_node_in_group("player")
	if player:
		player.velocity = Vector2.ZERO
		player.set_process_input(false)  # Disable input processing
		player.set_physics_process(false)  # Disable physics updates
		if player.has_method("get_caught"):
			player.is_caught = true  # Use existing caught system to freeze player
	
	# Freeze all guards too for dramatic effect
	freeze_all_guards()

func freeze_all_guards():
	"""Freeze all guards when player wins"""
	var guards = get_tree().get_nodes_in_group("guards")
	for guard in guards:
		if guard.has_method("freeze_guard"):
			guard.freeze_guard()
		else:
			# Fallback: manually freeze guard
			guard.velocity = Vector2.ZERO
			guard.set_physics_process(false)

func create_win_screen():
	pass  # Removed win screen creation

func reset_keycard_variables():
	"""Resets all Dialogic variables related to keycards to false."""
	print("Resetting keycard variables for next level...")
	Dialogic.VAR.set("bluekey", false)
	Dialogic.VAR.set("redkey", false)
	Dialogic.VAR.set("greenkey", false)
	# Add any other keycard variables here if you create more key types

func proceed_to_next_stage():
	"""Handle what happens after win delay - restart or next level"""
	
	print("DEBUG: proceed_to_next_stage called")
	print("DEBUG: next_level_scene = ", next_level_scene)
	print("DEBUG: Scene exists? ", ResourceLoader.exists(next_level_scene) if next_level_scene != "" else false)
	
	# Reset keycard states before changing level
	reset_keycard_variables()
	
	if next_level_scene != "" and ResourceLoader.exists(next_level_scene):
		# Load next level
		print("Loading next level: ", next_level_scene)
		
		# Change to next scene
		var error = get_tree().change_scene_to_file(next_level_scene)
		if error != OK:
			print("ERROR: Failed to load next level. Error code: ", error)
			restart_level()  # Fallback to restart if loading fails
	else:
		# No next level specified or file doesn't exist - restart current level
		print("No valid next level scene, restarting current level")
		restart_level()

func restart_level():
	"""Restart the current scene"""
	# Clean up win UI before restarting
	# if win_ui:
	# 	win_ui.queue_free()
	
	# Restart the current scene
	get_tree().reload_current_scene()
