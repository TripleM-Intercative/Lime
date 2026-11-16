extends State
class_name LobberPatrol

var parent: Lobber

# state control vars
var target_patrol_cell: Vector2i

func _enter() -> void:
	parent = (get_parent() as LobberStateMachine).parent
	new_patrol_cell()

	pass

func _exit() -> void:
	pass

func _update(_delta: float) -> void:
	if target_patrol_cell == parent.current_cell:
		transitioned.emit(self, "LobberIdle")

	elif parent.can_move:
		parent.target_cell = parent.path_manager.calculate_path_segment(parent.path_manager_id, target_patrol_cell)
		parent.can_move = false

	pass

func _physics_update(_delta: float) -> void:
	if !parent.can_move:
		parent.execute_move(_delta)
	pass

func new_patrol_cell() -> void:
	var cells = MapManager.get_cells_in_radius(parent.center_rect, 10.0, 2.0)
	var random_cell = randi() % cells.size()
	target_patrol_cell = cells[random_cell]

	# TODO: this is unoptimized shit
	if !parent.path_manager.has_entity_space(parent.path_manager_id, target_patrol_cell):
		new_patrol_cell()
	else:
		parent.can_move = false
