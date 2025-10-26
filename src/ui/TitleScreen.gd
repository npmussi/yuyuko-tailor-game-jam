extends Control

## Title Screen - Main menu with background, title, and controls
## Press any key to start the game
## Shamelessly stolen from https://github.com/DandyLyons/GodotMenuExamples/blob/main/Features/TitleScreen/TitleScreen.tscn

@export var background_texture: Texture2D  # Assign a PNG in the inspector
@export var first_level_scene := "res://scenes/streets.tscn"  # Which level to load on start

@onready var background: ColorRect = $Background
@onready var press_start_label: Label = $MarginContainer/VBoxContainer/PressStartLabel
@onready var title_label: Label = $MarginContainer/VBoxContainer/TitleLabel
@onready var controls_label: Label = $MarginContainer/VBoxContainer/ControlsLabel
@onready var animation_timer: Timer = $AnimationTimer

var can_start := true
var blink_visible := true

func _ready() -> void:
	# Set background color (black by default)
	if background:
		background.color = Color.BLACK
		
		# If a texture is provided, create a TextureRect overlay
		if background_texture:
			var texture_rect = TextureRect.new()
			texture_rect.texture = background_texture
			texture_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
			background.add_child(texture_rect)
	else:
		push_warning("Background node not found in TitleScreen scene!")
	
	# Connect timer for blinking "Press Start" effect
	if animation_timer:
		animation_timer.timeout.connect(_on_blink_timer)

func _process(_delta: float) -> void:
	# Check for any key press to start
	if can_start and Input.is_anything_pressed():
		start_game()

func _on_blink_timer() -> void:
	"""Make 'Press Start' blink"""
	pass
	#if press_start_label:
	#	blink_visible = !blink_visible
	#	press_start_label.visible = blink_visible

func start_game() -> void:
	"""Load the first level"""
	can_start = false  # Prevent multiple starts
	
	print("Starting game, loading: ", first_level_scene)
	
	# Optional: Add fade out effect
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.5)
	await tween.finished
	
	# Load first level
	var error = get_tree().change_scene_to_file(first_level_scene)
	if error != OK:
		print("ERROR: Failed to load first level. Error code: ", error)
