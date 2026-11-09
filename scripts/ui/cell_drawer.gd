extends Node2D
class_name CellDrawer

const HOVER_COLOR: Color = Color(1, 1, 1, 0.25)
const TARGET_COLOR: Color = Color(0.2, 0.8, 0.2, 0.35)
const INVALID_COLOR: Color = Color(0.9, 0.2, 0.2, 0.35)

var map: TileMapLayer
var target_cells: Array[Vector2i] = []

func _ready() -> void:
	map = get_parent() as TileMapLayer
	z_index = 100
	MapManager.hovered_cell_changed.connect(func(_cell): queue_redraw())

func set_target_cells(cells: Array[Vector2i]) -> void:
	target_cells = cells
	queue_redraw()

func _draw() -> void:
	if map == null:
		return
	for cell in target_cells:
		if MapManager.is_valid_cell(cell):
			draw_cell(cell, TARGET_COLOR)
		else:
			draw_cell(cell, INVALID_COLOR)
	draw_cell(MapManager.hovered_cell, HOVER_COLOR)

func draw_cell(cell: Vector2i, color: Color) -> void:
	var tile_size: Vector2 = Vector2(map.tile_set.tile_size)
	var center = map.map_to_local(cell)
	draw_rect(Rect2(center - tile_size / 2.0, tile_size), color)
	draw_rect(Rect2(center - tile_size / 2.0, tile_size), color.lightened(0.4), false, 1.0)
