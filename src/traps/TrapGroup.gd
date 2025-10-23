# ==============================================================================
# TRAP GROUP - Coordinated Multi-Trap Management System
# ==============================================================================
#
# USER CONTEXT:
# This script manages multiple spike traps as a coordinated group, allowing
# for complex timing patterns between multiple traps. You can set different
# activation patterns (sequential, alternating, random, synchronized) and
# timing delays to create challenging puzzle-like obstacle sequences.
# All SpikeTrap children are automatically detected and managed.
#
# AI CONTEXT:
# Node2D container that collects all SpikeTrap child nodes at startup and
# manages their activation timing through enum-defined patterns. Uses Timer
# nodes for precise coordination between multiple trap instances. Pattern
# system includes SEQUENTIAL (one-by-one), ALTERNATING (every other),
# RANDOM (unpredictable timing), and SYNCHRONIZED (all together) modes.
# Inspector-exposed variables for pattern type, delays, and sync offset.
# Automatically starts pattern execution on scene ready.
# ==============================================================================

extends Node2D

@export var trap_pattern := PatternType.SEQUENTIAL
@export var pattern_delay := 0.5  # Delay between trap activations
@export var sync_offset := 0.0    # Offset for this group

enum PatternType {
	SEQUENTIAL,  # Activate one after another
	ALTERNATING, # Every other trap
	RANDOM,      # Random timing
	SYNCHRONIZED # All at once
}

var spike_traps: Array[Node2D] = []

func _ready():
	# Find all spike traps as children
	for child in get_children():
		if child.has_method("reset_trap"):
			spike_traps.append(child)
	
	# Set up pattern
	setup_pattern()

func setup_pattern():
	match trap_pattern:
		PatternType.SEQUENTIAL:
			for i in spike_traps.size():
				var trap = spike_traps[i]
				trap.cycle_timer = -(i * pattern_delay)  # Stagger timing
		
		PatternType.ALTERNATING:
			for i in spike_traps.size():
				var trap = spike_traps[i]
				if i % 2 == 0:
					trap.cycle_timer = 0.0
				else:
					trap.cycle_timer = -pattern_delay
		
		PatternType.SYNCHRONIZED:
			for trap in spike_traps:
				trap.cycle_timer = -sync_offset
