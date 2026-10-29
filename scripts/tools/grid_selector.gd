extends Node
class_name GridSelector

const DEFAULT_SIZE: int = 3

var grid_container: GridContainer = GridContainer.new()
var selected_pos: Array[Vector2]
var cells: Array[SelectorCell]
var grid_window: Window
var grid_size: int
var grid_mid: Vector2

signal set_grid_positions(positions: Array[Vector2], origin: Vector2)

func _init() -> void:
	grid_container.add_theme_constant_override("h_separation", 0)
	grid_container.add_theme_constant_override("v_separation", 0)

func get_real_grid_size() -> int:
	return (grid_size - 1) * 2 + 1

func create_new_grid(size: int, marked_offsets: Array[Vector2] = []):
	grid_size = clampi(size, 1, Utils.INT_MAX)
	var real_grid_size: int = get_real_grid_size()
	grid_container.columns = real_grid_size
	grid_mid = Vector2(grid_size - 1, grid_size - 1)
	
	for row in range(real_grid_size):
		for column in range(real_grid_size):
			var new_cell := SelectorCell.new()
			new_cell.pos_in_grid = Vector2(row, column)
			new_cell.is_mid = new_cell.pos_in_grid == grid_mid
			new_cell.set_marked(marked_offsets.has(new_cell.pos_in_grid - grid_mid))
			cells.append(new_cell)
			grid_container.add_child(new_cell)
	
	_fit_window()

func remove_grid():
	for cell in cells:
		grid_container.remove_child(cell)
		cell.queue_free()
	cells.clear()

func get_marked_offsets() -> Array[Vector2]:
	var offsets: Array[Vector2] = []
	for cell in cells:
		if cell.is_marked:
			offsets.append(cell.pos_in_grid - grid_mid)
	return offsets

func resize_grid(value):
	var new_size: int = clampi(int(value), 1, Utils.INT_MAX)
	if new_size == grid_size and !cells.is_empty():
		return
	var offsets: Array[Vector2] = get_marked_offsets()
	remove_grid()
	create_new_grid(new_size, offsets)

func fill_grid():
	for cell in cells:
		cell.set_marked(true)

func clear_grid():
	for cell in cells:
		cell.set_marked(false)

func circle_grid():
	var radius: int = grid_size - 1
	for cell in cells:
		var offset: Vector2 = cell.pos_in_grid - grid_mid
		cell.set_marked(offset.length_squared() <= radius * radius + radius)

func edit_grid():
	grid_window = Window.new()
	grid_window.title = "Grid Selector"
	grid_window.wrap_controls = true
	grid_window.close_requested.connect(close_grid_window)
	
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["margin_left", "margin_top", "margin_right", "margin_bottom"]:
		margin.add_theme_constant_override(side, 8)
	grid_window.add_child(margin)
	
	var root_vbox := VBoxContainer.new()
	margin.add_child(root_vbox)
	
	var resize_input: HBoxContainer = Utils.create_int_input_field("Grid Size:", func(value): resize_grid(value))
	root_vbox.add_child(resize_input)
	
	var grid_hbox := HBoxContainer.new()
	root_vbox.add_child(grid_hbox)
	
	var tool_vbox := VBoxContainer.new()
	tool_vbox.add_child(_create_tool_button("Fill", fill_grid))
	tool_vbox.add_child(_create_tool_button("Circle", circle_grid))
	tool_vbox.add_child(_create_tool_button("Clear", clear_grid))
	grid_hbox.add_child(tool_vbox)
	
	if cells.is_empty():
		create_new_grid(DEFAULT_SIZE)
	resize_input.get_child(1).value = grid_size
	grid_hbox.add_child(grid_container)
	
	var done_button := Button.new()
	done_button.text = "Done"
	done_button.pressed.connect(set_selected_pos)
	root_vbox.add_child(done_button)
	
	EditorInterface.popup_dialog_centered(grid_window)
	_fit_window()

func _create_tool_button(text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.pressed.connect(callback)
	return button

func _fit_window():
	if !is_instance_valid(grid_window) or !grid_window.is_inside_tree():
		return
	_apply_window_size.call_deferred()

func _apply_window_size():
	if is_instance_valid(grid_window):
		grid_window.reset_size()

func close_grid_window():
	var parent := grid_container.get_parent()
	if parent:
		parent.remove_child(grid_container)
	grid_window.queue_free()

func set_selected_pos():
	selected_pos.clear()
	for cell in cells:
		if cell.is_marked:
			selected_pos.append(cell.pos_in_grid)
	set_grid_positions.emit(selected_pos, grid_mid)
	close_grid_window()
