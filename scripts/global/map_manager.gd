extends Node

signal hovered_cell_changed(cell: Vector2i)
signal map_changed(map: TileMapLayer)

var current_map: TileMapLayer = null
var hovered_cell: Vector2i = Vector2i.ZERO
var cell_drawer: CellDrawer


func register_map(map: TileMapLayer) -> void:
	if current_map == map:
		return
	remove_cell_drawer()
	current_map = map
	cell_drawer = CellDrawer.new()
	current_map.add_child.call_deferred(cell_drawer)
	map_changed.emit(current_map)

func unregister_map(map: TileMapLayer) -> void:
	if current_map == map:
		remove_cell_drawer()
		current_map = null
		hovered_cell = Vector2i.ZERO
		map_changed.emit(null)

func has_map() -> bool:
	return is_instance_valid(current_map)


func _process(_delta: float) -> void:
	if !has_map():
		return
	var cell: Vector2i = current_map.local_to_map(current_map.get_local_mouse_position())
	if cell != hovered_cell:
		hovered_cell = cell
		hovered_cell_changed.emit(cell)


func is_valid_cell(cell: Vector2i) -> bool:
	return has_map() && current_map.get_cell_source_id(cell) != -1

func cell_to_world(cell: Vector2i) -> Vector2:
	return current_map.to_global(current_map.map_to_local(cell))

func get_tile_data(cell: Vector2i) -> TileData:
	if has_map():
		return current_map.get_cell_tile_data(cell)
	else:
		return null
	
func get_hoverd_cell() -> Vector2i:
	return hovered_cell
	
func get_cells_in_range(cell_offsets: Array[Vector2i]) -> Array[Vector2i]:
	var target_cells: Array[Vector2i] = []
	for offset in cell_offsets:
		target_cells.append(hovered_cell + offset)
	return target_cells


func highlight_cells(cells: Array[Vector2i]) -> void:
	if cell_drawer:
		cell_drawer.set_target_cells(cells)

func clear_highlight() -> void:
	var empty: Array[Vector2i] = []
	highlight_cells(empty)

func remove_cell_drawer() -> void:
	if cell_drawer:
		cell_drawer.queue_free()
	cell_drawer = null
