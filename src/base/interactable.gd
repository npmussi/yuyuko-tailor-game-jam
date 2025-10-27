extends CharacterBody2D
class_name Interactable

## Base class for interactable objects in the game.
## Akin to Events in RPG Maker triggered by Action.
## Extend other .gd scripts to enforce using the _activate function.

@export var interaction_distance := 32.0 # Distance within which the player can interact
@export_file("*.dtl") var timeline := ""  # Dialogic timeline to play on first interaction
@export var pause_game_during_timeline := true  # Whether to freeze player/guards during dialogue

var has_been_activated := false  # Track if this has been interacted with before


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	add_to_group("interactable")


func activate() -> void:
	# Play timeline on first activation if specified
	if !has_been_activated and timeline != "" and ResourceLoader.exists(timeline):
		has_been_activated = true
		play_timeline()
		return
	
	# Mark as activated even if no timeline
	has_been_activated = true
	
	# Call the child class implementation
	_on_activate()


func play_timeline() -> void:
	"""Play the Dialogic timeline for this interactable"""
	print("Playing interactable timeline: ", timeline)
	var timeline_resource = ResourceLoader.load(timeline)
	if timeline_resource == null:
		push_warning("Failed to load timeline: %s" % timeline)
		_on_activate()  # Fallback to normal activation
		return
	Dialogic.start(timeline_resource)
	# Connect to timeline_ended to continue after dialogue finishes
	Dialogic.timeline_ended.connect(_on_timeline_finished)


func _on_timeline_finished() -> void:
	"""Called when the interactable's timeline dialogue finishes"""
	
	# Now do the actual activation effect
	_on_activate()


func _on_activate() -> void:
	"""Override this in child classes to implement actual activation behavior"""
	print("INTERACTABLE BASE: _on_activate() called on ", name, " - this should be overridden!")
	push_error("Did you forget to implement the _on_activate() function in " + name + "?")
	assert(false, "Interactable._on_activate() not implemented in " + name)
