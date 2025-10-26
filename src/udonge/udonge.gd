extends Interactable

enum UdongeState {
	OFF,
	ON,
	BROKEN
}

@export var noise_radius := 2000.0 # Radius of noise to lure guards
@export var noise_type := "udonge" # Type of noise to generate, see guard.gd
@export var duration := 4.0 # How long it produces noise for
@export var noise_interval := 0.5 # How often it produces noise

@onready var sprite: Sprite2D = $Sprite2D

const SPEED = 300.0
const JUMP_VELOCITY = -400.0

var current_state: UdongeState = UdongeState.OFF
var state_timer: float = 0 # Controls how long it makes noise for. Easier than guard turning it off
var noise_timer: float = 0 # Controls how often a noise signal is emitted

func _ready() -> void:
	super._ready()  # Call parent _ready() to add to "interactable" group
	# Initially, it's in the OFF state.
	set_state(UdongeState.OFF)

func set_state(state: UdongeState) -> void:
	current_state = state
	print("Udonge state changed to: ", state)
	match state:
		UdongeState.OFF:
			sprite.frame = 10
			set_physics_process(false)
		UdongeState.ON:
			sprite.frame = 12
			set_physics_process(true)
			emit_noise()
		UdongeState.BROKEN:
			sprite.frame = 46
			set_physics_process(false)

func emit_noise() -> void:
	# Emit through player's noise_event so guards hear it
	var player = get_tree().get_first_node_in_group("player")
	if player and player.has_signal("noise_event"):
		player.noise_event.emit(get_global_position(), noise_radius, noise_type)

func _physics_process(delta: float) -> void:
	# Stationary.
	velocity = Vector2.ZERO
	if current_state != UdongeState.ON:
		return

	state_timer += delta
	noise_timer += delta

	if state_timer >= duration:
		set_state(UdongeState.OFF)
		state_timer = 0
		noise_timer = 0
		return
	elif noise_timer >= noise_interval:  # Fixed: should be >=, not <=
		emit_noise()
		noise_timer = 0

func activate() -> void:
	if current_state == UdongeState.OFF:
		print("Udonge activated at position: ", get_global_position())
		set_state(UdongeState.ON)

func break_udonge() -> void:
	set_state(UdongeState.BROKEN) # Sad Reisen
