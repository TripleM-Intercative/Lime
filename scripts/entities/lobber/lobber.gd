class_name Lobber
extends LSCUnit

@export var reaction_field_radius: float
@export var area_of_view_radius: float

@export var m_cell_drawer: CellDrawerEx

var center_rect: Rect2i

func _ready() -> void:
	super._ready()

	path_manager_id = path_manager.register_entity(self, current_cell, 2, true)

	cell_changed.connect(_on_cell_changed)

	center_rect = Rect2i(current_cell, Vector2i(current_cell.x + 1, current_cell.y + 1))

	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	pass

func _on_cell_changed(_old: Vector2i, new: Vector2i) -> void:
	center_rect = Rect2i(new, Vector2i(1, 1))
	var aov_cells = MapManager.get_cells_in_radius(center_rect, area_of_view_radius)
	m_cell_drawer.set_highlight(&"lobber_view", aov_cells, Color(0.97, 0.98, 0.99, 0.50), 2.0, Color(0.97, 0.98, 0.99, 0.10))

	var rfr_cells = MapManager.get_cells_in_radius(center_rect, reaction_field_radius)
	m_cell_drawer.set_highlight(&"lobber_reactin", rfr_cells, Color(0.98, 0.57, 0.24, 0.50), 2.0, Color(0.98, 0.57, 0.24, 0.22))
	pass
