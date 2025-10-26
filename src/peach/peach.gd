extends Interactable

## Peach that restores player's stamina to full
## Disappears after being eaten, then reappears after 5 seconds

var is_available := true  # Track if peach can be eaten

func _ready() -> void:
	super._ready()  # Call parent _ready() to add to "interactable" group

func activate() -> void:
	if !is_available:
		return  # Can't eat if already eaten
	
	print("Peach eaten!")
	
	# Find the player and restore their stamina
	var player = get_tree().get_first_node_in_group("player")
	if player and player.has_method("restore_stamina"):
		player.restore_stamina()
		print("Player stamina restored to full!")
	
	# Hide the peach and disable interaction
	is_available = false
	visible = false
	
	# Respawn after 5 seconds
	await get_tree().create_timer(5.0).timeout
	visible = true
	is_available = true
	print("Peach respawned!")
