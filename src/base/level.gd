extends Node2D

## Base class for all level scenes
## Provides common functionality like playing intro timelines

@export_file("*.dtl") var timeline := ""  # Dialogic timeline to play at start of level


func _ready() -> void:
	# Play Dialogic timeline if specified
	if timeline != "" and ResourceLoader.exists(timeline):
		print("Playing level start timeline: ", timeline)
		var timeline_resource = ResourceLoader.load(timeline)
		if timeline_resource == null:
			push_warning("Failed to load timeline: %s" % timeline)
		else:
			Dialogic.start(timeline_resource)
			# Optional: Connect to timeline_ended if you need to do something after
			# Dialogic.timeline_ended.connect(_on_timeline_finished)
