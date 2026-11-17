class_name LimePlayer
extends LUnit

@export var input_buffer_duration: float = 0.3

var input_actions = {
	&"player_up" : Vector2i.UP,
	&"player_left" : Vector2i.LEFT,
	&"player_down" : Vector2i.DOWN,
	&"player_right" : Vector2i.RIGHT
}

var input_stack: Array[StringName] = []
var input_buffer: StringName = &""

var path_target_cell: Vector2i = Vector2i.ZERO
var use_path: bool = false

func _ready() -> void:
	super._ready()

	path_manager_id = path_manager.register_entity(self, current_cell, entity_size, true)

	assert(path_manager_id != -1, "Player could not be registered, start cell is blocked")

func _unhandled_input(event: InputEvent) -> void:
	if event.is_echo():
		return
		
	for action in input_actions:
		if event.is_action_pressed(action):
			input_stack.erase(action)
			input_stack.push_back(action)
			
			if !can_move:
				var threshold: float = 1.0 - (input_buffer_duration / movement_duration)
				
				if movement_timer >= threshold:
					input_buffer = action
					
			if use_path:
				use_path = false
				
				input_buffer = action
			
		if event.is_action_released(action):
			input_stack.erase(action)
			
	if event.is_action_pressed(&"player_to"):
		var clicked_cell: Vector2i = map.local_to_map(map.to_local(get_global_mouse_position()))
		
		if !path_manager.has_entity_space(path_manager_id, clicked_cell):
			return
			
		path_target_cell = clicked_cell
		use_path = true

func _process(delta: float) -> void:
	if can_move:
		if m_calculate_move_target():
			if !_start_move():
				use_path = false
			
	else:
		_update_move(delta)

func _continue_move() -> bool:
	return m_calculate_move_target() && _start_move()

func get_input_stack_direction() -> Vector2i:
	if input_stack.is_empty():
		return Vector2i.ZERO
	
	else:
		return input_actions[input_stack.back()]

func is_valid_target(cell: Vector2i) -> bool:
	return path_manager.has_entity_space(path_manager_id, cell)

func m_calculate_move_target() -> bool:
	var should_move: bool = false
	
	if input_buffer.is_empty():
		if !input_stack.is_empty():
			should_move = true
			use_path = false
			
			move_to_cell = move_from_cell + get_input_stack_direction()
			
		elif use_path:
			var next_cell: Vector2i
			next_cell = path_manager.calculate_path_segment(path_manager_id, path_target_cell)
			
			if next_cell == move_from_cell:
				use_path = false
				
			else:
				should_move = true
				move_to_cell = next_cell
				
	else:
		should_move = true
		use_path = false
		move_to_cell = move_from_cell + input_actions[input_buffer]
		input_buffer = &""
		
	return should_move
