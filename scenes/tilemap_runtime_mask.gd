# ==============================================================================
# TILEMAP RUNTIME MASK - Dynamic Navigation Layer Management
# ==============================================================================
#
# USER CONTEXT:
# This script provides runtime control over tile navigation properties.
# It allows certain tiles to have their navigation polygons dynamically
# disabled or modified during gameplay. Currently configured to disable
# navigation on tiles with source ID 1, which can be useful for creating
# temporary obstacles or dynamic pathfinding changes.
#
# AI CONTEXT:
# TileMap extension that overrides _use_tile_data_runtime_update and
# _tile_data_runtime_update to provide per-tile navigation control.
# Uses get_used_cells_by_id to identify specific tile types and
# set_navigation_polygon to modify navigation behavior. Currently
# targets source ID 1 tiles for navigation polygon nullification.
# Part of Godot's runtime tile data system for dynamic level changes.
# ==============================================================================

extends TileMap


func _use_tile_data_runtime_update(layer, coords):
	if coords in get_used_cells_by_id(layer, 1):
		return true
	return false

func _tile_data_runtime_update(_layer: int, _coords: Vector2i, tile_data: TileData):
	tile_data.set_navigation_polygon(0, null)
