extends Interactable

## Keycard that can be picked up by the player
## When picked up, sets a Dialogic variable and unlocks corresponding doors

@export var keycard_variable := "bluekey"  # Dialogic variable name (e.g., "bluekey", "redkey", "greenkey")
@export var door_id := "blue_door"  # ID of the door(s) this keycard unlocks
@export var pickup_message := "Keycard acquired!"

func _ready() -> void:
	super._ready()  # Call parent's _ready() to add to group
	
	# Color the keycard based on the variable type
	var sprite = get_node_or_null("Sprite2D")
	if sprite:
		match keycard_variable:
			"bluekey":
				sprite.modulate = Color(0.6, 0.8, 1.0)  # Bright Blue
			"redkey":
				sprite.modulate = Color(1.0, 0.6, 0.6)  # Bright Red
			"greenkey":
				sprite.modulate = Color(0.6, 1.0, 0.6)  # Bright Green
			_:
				sprite.modulate = Color.WHITE  # Default white

func activate() -> void:
	# Call parent activate() first to handle timeline logic
	super.activate()
	
	# Now do key-specific logic
	print("Keycard picked up: ", keycard_variable)
	
	# Set the Dialogic variable to true
	Dialogic.VAR.set(keycard_variable, true)
	print("Set Dialogic.VAR.", keycard_variable, " = true")
	
	# Show pickup message
	print(pickup_message)
	
	# Unlock all matching doors
	unlock_doors()
	
	# Remove the keycard from the scene
	queue_free()

func unlock_doors() -> void:
	# Find all doors in the scene with matching ID
	var all_doors = get_tree().get_nodes_in_group("doors")
	for door in all_doors:
		if door.has_method("get_door_id") and door.get_door_id() == door_id:
			door.unlock()
			print("Unlocked door: ", door.name)

func _on_activate() -> void:
	# This should not be called since we override activate()
	pass