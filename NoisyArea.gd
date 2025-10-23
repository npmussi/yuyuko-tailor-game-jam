# ==============================================================================
# NOISY AREA - Environmental Sound Modification System
# ==============================================================================
#
# USER CONTEXT:
# This script creates zones that modify how much noise the player makes
# when moving through them. For example, walking on gravel, metal, or
# broken glass areas would make more noise than normal surfaces. When
# the player enters the area, their noise multiplier changes, and when
# sneaking, they can move silently regardless of surface type.
#
# AI CONTEXT:
# Area2D that modifies player noise generation through direct method calls.
# Uses body_entered/body_exited signals to track player presence and
# continuously updates noise multiplier in _process. Checks for player
# identity through has_method("is_player") and respects sneaking state
# through is_sneaking() check. Sets terrain_noise_multiplier on player
# to either 1.0 (silent when sneaking) or configured noise_multiplier
# value. Inspector-exposed multiplier for different surface types.
# ==============================================================================

extends Area2D

@export var noise_multiplier: float = 2.0
var player_in_area: Node2D = null

func _ready():
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _process(_delta):
	# Continuously update noise multiplier based on player's sneaking state
	if player_in_area and player_in_area.has_method("is_player") and player_in_area.is_player():
		if player_in_area.is_sneaking():
			player_in_area.set_terrain_noise_multiplier(1.0)  # Silent when sneaking
		else:
			player_in_area.set_terrain_noise_multiplier(noise_multiplier)  # Noisy when walking

func _on_body_entered(body):
	if body.has_method("is_player") and body.is_player():
		player_in_area = body
		# Set initial multiplier based on current sneaking state
		if body.is_sneaking():
			body.set_terrain_noise_multiplier(1.0)  # Silent when sneaking
		else:
			body.set_terrain_noise_multiplier(noise_multiplier)  # Noisy when walking

func _on_body_exited(body):
	if body.has_method("is_player") and body.is_player():
		player_in_area = null
		body.set_terrain_noise_multiplier(1.0)
