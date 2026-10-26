extends Node
class_name GridSelector

var grid_container: GridContainer = GridContainer.new()
var selected_pos: Array[Vector2]
var cells: Array[SelectorCell]
var grid_window: Window
var grid_size: int
var grid_mid: Vector2
const DEFAULT_SIZE: int = 3

signal set_grid_positions(positions: Array[Vector2], origin: Vector2)

func _init() -> void:
	grid_container.add_theme_constant_override("h_separation", 0)
	grid_container.add_theme_constant_override("v_separation", 0)

func _ready() -> void:
	pass

func create_new_grid(size: int):
	grid_size = clampi(size, 1, Utils.INT_MAX)
	var real_grid_size: int = (grid_size -1) * 2 +1
	var row: int = 0
	var column: int = 0
	
	grid_container.columns = real_grid_size
	for i in range(real_grid_size * real_grid_size):
		if column >= real_grid_size:
			column = 0
			row += 1
		var new_cell = SelectorCell.new()
		new_cell.pos_in_grid = Vector2(row, column)
		cells.append(new_cell)
		column += 1
		grid_container.add_child(new_cell)
	
	set_mid_point(cells)
	
	grid_container.scale = Vector2(2,2)
	

func set_mid_point(array: Array[SelectorCell]):
	var mid: int = (array.size() - 1) / 2
	cells[mid].base_color = Color.ORANGE
	cells[mid].self_modulate = Color.ORANGE
	grid_mid = cells[mid].pos_in_grid

func remove_grid():
	for cell in cells:
		grid_container.remove_child(cell)
	
	cells.clear()

func edit_grid():
	grid_window = Window.new()
	grid_window.close_requested.connect(close_grid_window)
	EditorInterface.popup_dialog(grid_window, Rect2(Vector2(100, 100), Vector2(1000, 1000)))
	
	var grid_vbox: VBoxContainer = VBoxContainer.new()
	grid_vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	grid_window.add_child(grid_vbox)
	
	var resize_input: HBoxContainer = Utils.create_int_input_field("Grid Size:", func(value): resize_grid(value))
	
	
	var done_button: Button = Button.new()
	done_button.text = "Done"
	done_button.pressed.connect(set_selected_pos)
	
	if selected_pos.is_empty():
		create_new_grid(DEFAULT_SIZE)
		resize_input.get_child(1).value = DEFAULT_SIZE
	
	resize_input.get_child(1).value = grid_size
	
	grid_vbox.add_child(resize_input)
	grid_vbox.add_child(grid_container)
	grid_vbox.add_child(done_button)

func close_grid_window():
	var parent := grid_container.get_parent()
	if parent:
		parent.remove_child(grid_container)
	grid_window.queue_free()

func resize_grid(value):
	grid_size = value
	remove_grid()
	create_new_grid(value)

func set_selected_pos():
	selected_pos.clear()
	for cell in cells:
		if cell.is_marked:
			selected_pos.append(cell.pos_in_grid)
	set_grid_positions.emit(selected_pos, grid_mid)
	close_grid_window()
