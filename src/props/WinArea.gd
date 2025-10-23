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
@export var next_level_scene := ""  # Future: Set this to load next level instead of restarting

var has_won := false  # Prevent multiple triggers
var win_ui: CanvasLayer  # Reference to the win screen UI

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
	
	# Create and show win screen UI
	create_win_screen()
	
	# Wait for delay then proceed to next action
	await get_tree().create_timer(restart_delay).timeout
	proceed_to_next_stage()

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
	"""Create full-screen win UI overlay"""
	# Create a CanvasLayer to ensure it appears on top
	var canvas_layer = CanvasLayer.new()
	canvas_layer.layer = 1000  # High layer to appear on top of everything
	
	# Create a full-screen control container
	var control_container = Control.new()
	control_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	
	# Black background
	var background = ColorRect.new()
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.color = Color.BLACK
	control_container.add_child(background)
	
	# Win message label
	var label = Label.new()
	label.text = win_message
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	
	# Make text big and white
	label.add_theme_font_size_override("font_size", 64)
	label.add_theme_color_override("font_color", Color.WHITE)
	
	control_container.add_child(label)
	
	# Technical note label for developers
	var tech_label = Label.new()
	tech_label.text = "// next_level_scene export variable can be set to trigger scene transitions or custom win handlers"
	tech_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	tech_label.offset_top = -60
	tech_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tech_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	
	# Smaller, dimmed text for technical note
	tech_label.add_theme_font_size_override("font_size", 16)
	tech_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7, 0.8))
	
	control_container.add_child(tech_label)
	canvas_layer.add_child(control_container)
	
	# Add to scene tree
	get_tree().root.add_child(canvas_layer)
	win_ui = canvas_layer  # Store reference for cleanup

func proceed_to_next_stage():
	"""Handle what happens after win delay - restart or next level"""
	
	# FUTURE LEVEL PROGRESSION:
	# To make this load the next level instead of restarting:
	# 1. Set next_level_scene to something like "res://scenes/level_2.tscn"
	# 2. Uncomment the next level loading code below
	# 3. Comment out the restart_level() call
	
	if next_level_scene != "" and ResourceLoader.exists(next_level_scene):
		# Load next level
		get_tree().change_scene_to_file(next_level_scene)
	else:
		# Restart current level (prototype behavior)
		restart_level()

func restart_level():
	"""Restart the current scene"""
	# Clean up win UI before restarting
	if win_ui:
		win_ui.queue_free()
	
	# Restart the current scene
	get_tree().reload_current_scene()
