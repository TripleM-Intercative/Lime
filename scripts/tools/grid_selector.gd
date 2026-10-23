extends Node
class_name GridSelector

var grid_container: GridContainer = GridContainer.new()
var selected_pos: Array[Vector2]

func _init() -> void:
	grid_container.columns = 5
	grid_container.add_theme_constant_override("h_separation", 0)
	grid_container.add_theme_constant_override("v_separation", 0)

func _ready() -> void:
	for i in range(25):
		var new_cell = SelectorCell.new()
		grid_container.add_child(new_cell)
	
	grid_container.scale = Vector2(10,10)
	
	get_tree().current_scene.add_child.call_deferred(grid_container)
	
	
