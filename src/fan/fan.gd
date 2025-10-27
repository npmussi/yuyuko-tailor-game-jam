extends Interactable

## Fan weapon that the player can pick up
## Allows player to shoot projectiles that instantly destroy guards

func _ready() -> void:
	super._ready()  # Call parent _ready() to add to "interactable" group

func _on_activate() -> void:
	print("Fan picked up!")
	
	# Find the player and give them the fan weapon
	var player = get_tree().get_first_node_in_group("player")
	if player and player.has_method("pickup_fan"):
		player.pickup_fan()
		print("Player acquired the fan weapon!")
	
	# Remove the fan from the scene (it's been picked up)
	queue_free()
