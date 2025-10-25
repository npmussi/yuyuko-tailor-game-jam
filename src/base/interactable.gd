extends CharacterBody2D
class_name Interactable

## Base class for interactable objects in the game.
## Akin to Events in RPG Maker triggered by Action.
## Extend other .gd scripts to enforce using the _activate function.

@export var interaction_distance := 32.0 # Distance within which the player can interact


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	add_to_group("interactable")


func activate() -> void:
	print("INTERACTABLE BASE: activate() called on ", name, " - this should be overridden!")
	push_error("Did you forget to implement the activate() function in " + name + "?")
	assert(false, "Interactable.activate() not implemented in " + name)
