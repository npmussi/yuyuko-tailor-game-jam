# ==============================================================================
# STAMINA UI - Player Stamina Display System
# ==============================================================================
#
# USER CONTEXT:
# This script manages the on-screen stamina display and movement state indicator
# in the top-left corner. Shows current stamina level (30/30 Stamina) and
# movement mode (Walking/Crouching). Updates in real-time as the player sneaks
# (draining stamina) or walks (regenerating stamina). Provides visual feedback
# for the stealth system, helping players manage their sneaking ability and
# understand their current movement state.
#
# AI CONTEXT:
# CanvasLayer-based UI with two Label child nodes: StaminaLabel and MovementLabel.
# Automatically finds player via "player" group lookup. Updates via _process()
# polling player stamina values and is_sneaking() state. High layer value ensures
# UI renders above game elements. Simple text-based displays with matching font
# size/color (20px, Yellow). Movement label shows "Walking" or "Crouching" based
# on player movement state. Minimal HUD design with vertical label stacking.
# ==============================================================================

extends CanvasLayer

@onready var stamina_label: Label = $StaminaUI/StaminaLabel
@onready var movement_label: Label = $StaminaUI/MovementLabel

var player: CharacterBody2D

func _ready():
	# Find the player node in the scene
	player = get_tree().get_first_node_in_group("player")
	
	# CanvasLayer automatically handles screen positioning
	layer = 100  # High layer to ensure it's always on top
	
	# Position labels at top-left corner with some padding
	if stamina_label:
		stamina_label.position = Vector2(20, 20)
		stamina_label.add_theme_font_size_override("font_size", 20)  # Bigger font
		stamina_label.add_theme_color_override("font_color", Color(0.8, 0.2, 1.0)) # Bright purple
	
	if movement_label:
		movement_label.hide() # Hide the movement label


func _process(_delta):
	if player:
		# Display stamina as a percentage
		if stamina_label:
			var percentage = 0.0
			if player.MAX_STAMINA > 0:
				percentage = (player.current_stamina / player.MAX_STAMINA) * 100.0
			stamina_label.text = "Resurrection Butterfly - %d%% Reflowering-" % [int(percentage)]
		
		# Movement label is hidden, no need to update it.
		
