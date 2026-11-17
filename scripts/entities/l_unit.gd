## A Unit is everything movable
class_name LUnit
extends LEntity

@export var movement_duration: float = 0.5

var movement_timer: float = 0.0
var can_move: bool = true

func _start_move() -> bool:
	if !path_manager.update_pos(path_manager_id, move_to_cell):
		return false
		
	can_move = false
	movement_timer = 0.0
	
	return true

func _update_move(delta: float) -> void:
	movement_timer += delta / movement_duration
	
	if movement_timer < 1.0:
		position = move_from_pos.lerp(move_to_pos, movement_timer)
		
		return
	
	cell_changed.emit(move_from_cell, move_to_cell)
	
	var overflow: float = movement_timer - 1.0
	
	position = move_to_pos
	move_from_cell = move_to_cell
	can_move = true
	movement_timer = 0.0
	
	if _continue_move():
		movement_timer = minf(overflow, 1.0)
		can_move = false
		position = move_from_pos.lerp(move_to_pos, movement_timer)

func _continue_move() -> bool:
	return false
