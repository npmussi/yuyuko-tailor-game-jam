extends Node2D


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	const INTRO_TIMELINE = preload("res://src/dialogic/introduction.dtl")
	Dialogic.start(INTRO_TIMELINE)
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
