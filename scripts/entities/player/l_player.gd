class_name LimePlayer
extends LUnit

@export var input_buffer_duration := 0.2

var input_stack: Array[StringName] = []
var input_buffer: StringName = &""

var input_actions = {
	&"player_up" : Vector2i.UP,
	&"player_left" : Vector2i.LEFT,
	&"player_down" : Vector2i.DOWN,
	&"player_right" : Vector2i.RIGHT
}

var current_path: PackedVector2Array = []

func _ready() -> void:
	super._ready()

	path_manager_id = path_manager.register_entity(self, current_cell, 1, true)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_echo():
		return

	for action in input_actions:
		if event.is_action_pressed(action):
			input_stack.erase(action)
			input_stack.push_back(action)

			if !can_move:
				var threshold = 1.0 - (input_buffer_duration / movement_duration)
				if movement_timer >= threshold:
					input_buffer = action

		if event.is_action_released(action):
			input_stack.erase(action)

	if event.is_action_pressed("player_to"):
		var clicked_cell = map.local_to_map(map.to_local(get_global_mouse_position()))

func _process(delta: float) -> void:
	if can_move:
		var has_input := false
		var target: Vector2i

		if input_buffer.is_empty():
			if !input_stack.is_empty():
				has_input = true
				current_path.clear()
				target = calculate_direction() + current_cell
		else:
			has_input = true
			current_path.clear()
			target = input_actions[input_buffer] + current_cell
			input_buffer = &""

		if has_input && is_valid_target(target):
			target_cell = target

			can_move = false
			movement_timer = 0.0

			path_manager.update_pos(path_manager_id, target)

	else:
		execute_move(delta)

func calculate_direction() -> Vector2i:
	if input_stack.is_empty():
		return Vector2i.ZERO
	else:
		return input_actions[input_stack.back()]

func is_valid_target(cell: Vector2i) -> bool:
	return path_manager.has_entity_space(path_manager_id, cell)
