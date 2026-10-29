extends CharacterBody2D

@export var map : TileMapLayer

@export var movement_duration := 0.5
@export var input_buffer_duration := 0.2

var current_cell := Vector2i(0, 0)
var target_cell := Vector2i(0, 0)

var movement_timer := 0.0
var can_move := true

var input_stack: Array[StringName] = []
var input_buffer: StringName = &""

var input_actions = {
	&"player_up" : Vector2i.UP,
	&"player_left" : Vector2i.LEFT,
	&"player_down" : Vector2i.DOWN,
	&"player_right" : Vector2i.RIGHT
}

var current_path: Array[Vector2i] = []
var astar = AStarGrid2D.new()

func _ready() -> void:
	assert(map, "No Map in Player")
	
	current_cell = map.local_to_map(position)
	position = map.map_to_local(current_cell)
	
	setup_astar()

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
			
			if !current_path.is_empty():
				var active_path = current_path.front()
				current_path.clear()
				current_path.push_back(active_path)
				input_buffer = action
			
		if event.is_action_released(action):
			input_stack.erase(action)
			
	if event.is_action_pressed("player_to"):
		var clicked_cell = map.local_to_map(map.to_local(get_global_mouse_position()))
		
		if is_valid_target(clicked_cell):
			var path = astar.get_id_path(current_cell, clicked_cell)
			
			if !path.is_empty():
				current_path = path
				current_path.pop_front()

func _process(delta: float) -> void:
	if can_move:
		var has_input := false
		var target: Vector2i
		
		if input_buffer.is_empty():
			if !input_stack.is_empty():
				has_input = true
				current_path.clear()
				target = calculate_direction() + current_cell
			elif !current_path.is_empty():
				has_input = true
				target = current_path.pop_front()
		else:
			has_input = true
			current_path.clear()
			target = input_actions[input_buffer] + current_cell
			input_buffer = &""
			
		if has_input && is_valid_target(target):
			target_cell = target
			
			can_move = false
			movement_timer = 0.0
	else:
		execute_move(delta)

func calculate_direction() -> Vector2i:
	if input_stack.is_empty():
		return Vector2i.ZERO
	else:
		return input_actions[input_stack.back()]

func is_valid_target(cell: Vector2i) -> bool:
	return map.get_cell_source_id(cell) != -1

func execute_move(delta: float) -> void:
	movement_timer += delta / movement_duration
	
	position = lerp(map.map_to_local(current_cell), map.map_to_local(target_cell), clamp(movement_timer, 0.0, 1.0))
	
	if movement_timer >= 1.0:
		can_move = true
		movement_timer = 0.0
		current_cell = target_cell

func setup_astar() -> void:
	var bounds = map.get_used_rect()
	
	astar.region = bounds
	astar.cell_size = Vector2i.ONE
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	astar.default_compute_heuristic = AStarGrid2D.HEURISTIC_MANHATTAN
	astar.default_estimate_heuristic = AStarGrid2D.HEURISTIC_MANHATTAN
	astar.update()
	
	for x in range(bounds.position.x, bounds.end.x):
		for y in range(bounds.position.y, bounds.end.y):
			if !is_valid_target(Vector2i(x, y)):
				astar.set_point_solid(Vector2i(x, y), true)
