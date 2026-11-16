class_name CellDrawerEx
extends Node2D

var target_layer: TileMapLayer:
	set(value):
		target_layer = value
		queue_redraw()

## Internal data structure for each highlight group
class HighlightGroup:
	var cell_set: Dictionary = {} # Vector2i -> true (for O(1) neighbor lookup)
	var outline_color: Color
	var fill_color: Color
	var line_width: float
	var outline_segments: PackedVector2Array = PackedVector2Array()
	var fill_rects: Array[Rect2] = []


# Stores active groups: StringName -> HighlightGroup
var _groups: Dictionary = {}


func _ready() -> void:
	target_layer = MapManager.current_map
	# Automatically link to parent if placed as a child of a TileMapLayer
	if not target_layer and get_parent() is TileMapLayer:
		target_layer = get_parent()


## Adds or updates a named highlight group.
## Pass fill_color with alpha > 0 (e.g., Color(1, 0, 0, 0.2)) if you also want shaded tiles.
func set_highlight(
	group_id: StringName,
	cells: Array[Vector2i],
	outline_color: Color = Color.CYAN,
	line_width: float = 2.0,
	fill_color: Color = Color.TRANSPARENT
) -> void:
	var group := HighlightGroup.new()
	group.outline_color = outline_color
	group.line_width = line_width
	group.fill_color = fill_color

	for cell in cells:
		group.cell_set[cell] = true

	_rebuild_geometry(group)
	_groups[group_id] = group
	queue_redraw()


## Removes a specific highlight group by ID.
func remove_highlight(group_id: StringName) -> void:
	if _groups.erase(group_id):
		queue_redraw()


## Clears all active highlights.
func clear_all() -> void:
	if not _groups.is_empty():
		_groups.clear()
		queue_redraw()


## Precalculates the outer boundary segments and tile rectangles in local space.
func _rebuild_geometry(group: HighlightGroup) -> void:
	group.outline_segments.clear()
	group.fill_rects.clear()

	if not target_layer or not target_layer.tile_set:
		return

	var tile_size := Vector2(target_layer.tile_set.tile_size)
	var half_size := tile_size * 0.5

	for cell: Vector2i in group.cell_set.keys():
		# Convert tile coordinate to the highlighter's local space
		var layer_pos := target_layer.map_to_local(cell)
		var center := to_local(target_layer.to_global(layer_pos))

		var top_left := center - half_size
		var top_right := center + Vector2(half_size.x, -half_size.y)
		var bottom_left := center + Vector2(-half_size.x, half_size.y)
		var bottom_right := center + half_size

		if group.fill_color.a > 0.0:
			group.fill_rects.append(Rect2(top_left, tile_size))

		# Check all 4 neighbors; only add an edge if the neighbor is NOT in the group
		if not group.cell_set.has(cell + Vector2i.UP):
			group.outline_segments.append(top_left)
			group.outline_segments.append(top_right)

		if not group.cell_set.has(cell + Vector2i.DOWN):
			group.outline_segments.append(bottom_left)
			group.outline_segments.append(bottom_right)

		if not group.cell_set.has(cell + Vector2i.LEFT):
			group.outline_segments.append(top_left)
			group.outline_segments.append(bottom_left)

		if not group.cell_set.has(cell + Vector2i.RIGHT):
			group.outline_segments.append(top_right)
			group.outline_segments.append(bottom_right)


func _draw() -> void:
	for group: HighlightGroup in _groups.values():
		# 1. Draw translucent fills first so outlines render cleanly on top
		if group.fill_color.a > 0.0:
			for rect in group.fill_rects:
				draw_rect(rect, group.fill_color, true)

		# 2. Draw all outer perimeter edges in a single batch call
		if not group.outline_segments.is_empty():
			draw_multiline(group.outline_segments, group.outline_color, group.line_width)
