extends Node

# Game Over System
signal game_over_triggered
signal fade_complete

var is_game_over := false
var fade_overlay: ColorRect

func _ready() -> void:
	get_tree().node_added.connect(_on_scene_changed)
	create_fade_overlay()
	# Start with a fade-in when the game begins
	fade_in()

func create_fade_overlay() -> void:
	# Create a fullscreen black overlay for fading
	fade_overlay = ColorRect.new()
	fade_overlay.color = Color.BLACK
	fade_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fade_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fade_overlay.z_index = 1000  # Ensure it's on top of everything
	fade_overlay.process_mode = Node.PROCESS_MODE_ALWAYS  # Work during pause
	
	# Add to the scene tree at the highest level
	get_tree().current_scene.add_child(fade_overlay)

func fade_out(duration: float = 1.0) -> void:
	if !fade_overlay:
		create_fade_overlay()
	
	fade_overlay.color.a = 0.0
	fade_overlay.visible = true
	
	# Create tween for this specific fade
	var tween = create_tween()
	tween.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	tween.tween_property(fade_overlay, "color:a", 1.0, duration)
	await tween.finished

func fade_in(duration: float = 1.0) -> void:
	if !fade_overlay:
		create_fade_overlay()
	
	fade_overlay.color.a = 1.0
	fade_overlay.visible = true
	
	# Create tween for this specific fade
	var tween = create_tween()
	tween.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	tween.tween_property(fade_overlay, "color:a", 0.0, duration)
	await tween.finished
	fade_overlay.visible = false
	fade_complete.emit()

func trigger_game_over() -> void:
	if is_game_over:
		return  # Prevent multiple game over triggers
	
	is_game_over = true
	print("Game Over! Death animation will play...")
	
	# Emit signal for any UI or effects
	game_over_triggered.emit()
	
	# Note: Player will handle death animation and call restart_game() when done

func restart_game() -> void:
	is_game_over = false
	
	# Reset all guards before reloading scene
	var guards = get_tree().get_nodes_in_group("guards")
	for guard in guards:
		if guard.has_method("reset_guard_state"):
			guard.reset_guard_state()
	
	# Optional: Add a fade-out before restart for smoother transition
	if fade_overlay:
		await fade_out(0.3)  # Quick fade out
	
	get_tree().reload_current_scene()
	# Note: fade_in will be called automatically in _ready()

# Reset game over state when scene changes
func _on_scene_changed(_node: Node) -> void:
	is_game_over = false
	# Recreate fade overlay for the new scene
	call_deferred("create_fade_overlay")
	call_deferred("fade_in")
