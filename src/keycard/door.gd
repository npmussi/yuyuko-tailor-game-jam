extends StaticBody2D

## Door that can be unlocked by a keycard
## Disappears when unlocked
## Checks Dialogic variable on ready - if player already has key, door disappears immediately

@export var door_id := "blue_door"  # ID that matches the keycard
@export var required_keycard_variable := "bluekey"  # Dialogic variable to check (e.g., "bluekey", "redkey", "greenkey")
@export var is_locked := true

func _ready() -> void:
	add_to_group("doors")
	
	# Color the door based on the keycard type
	var sprite = get_node_or_null("Sprite2D")
	if sprite:
		match required_keycard_variable:
			"bluekey":
				sprite.modulate = Color(0.3, 0.5, 1.0)  # Blue
			"redkey":
				sprite.modulate = Color(1.0, 0.3, 0.3)  # Red
			"greenkey":
				sprite.modulate = Color(0.3, 1.0, 0.3)  # Green
			_:
				sprite.modulate = Color.WHITE  # Default white
	
	# Check if player already has the keycard (from Dialogic variable)
	if Dialogic.VAR.get(required_keycard_variable) == true:
		print("Door ", name, " - Player already has ", required_keycard_variable, ", removing door")
		queue_free()
		return
	
	if !is_locked:
		queue_free()  # Remove immediately if not locked

func get_door_id() -> String:
	return door_id

func unlock() -> void:
	if is_locked:
		is_locked = false
		print("Door ", name, " unlocked!")
		
		# Optional: Add a tween for smooth disappearance
		var tween = create_tween()
		tween.set_parallel(true)
		tween.tween_property(self, "modulate:a", 0.0, 0.3)
		tween.tween_property(self, "scale", Vector2(0.5, 0.5), 0.3)
		tween.finished.connect(queue_free)
		
		# Disable collision immediately so player can pass through
		collision_layer = 0
		collision_mask = 0
