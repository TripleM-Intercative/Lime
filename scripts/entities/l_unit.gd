## A Unit is everything movable
class_name LUnit
extends LEntity

@export var movement_duration: float = 0.5

var movement_timer := 0.0
var can_move := true

func execute_move(delta: float) -> void:
	movement_timer += delta / movement_duration

	position = lerp(map.map_to_local(current_cell), map.map_to_local(target_cell), clamp(movement_timer, 0.0, 1.0))

	if movement_timer >= 1.0:
		can_move = true
		movement_timer = 0.0
		var old_cell = current_cell
		current_cell = target_cell
		cell_changed.emit(old_cell, current_cell)
