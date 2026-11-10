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

var current_path: PackedVector2Array = []

var register_value
@onready var pathfinding: PathfindingManager = %PathfindingManager


func _ready() -> void:
	assert(map, "No Map in Player")
	
	current_cell = map.local_to_map(position)
	position = map.map_to_local(current_cell)
	
	register_value = pathfinding.register_entity(Enums.EntityType.Player, current_cell, 2, true)

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
			
			pathfinding.update_pos(register_value, target)
			
			
	else:
		execute_move(delta)

func calculate_direction() -> Vector2i:
	if input_stack.is_empty():
		return Vector2i.ZERO
	else:
		return input_actions[input_stack.back()]

func is_valid_target(cell: Vector2i) -> bool:
	return pathfinding.has_entity_space(register_value, cell)

func execute_move(delta: float) -> void:
	movement_timer += delta / movement_duration
	
	position = lerp(map.map_to_local(current_cell), map.map_to_local(target_cell), clamp(movement_timer, 0.0, 1.0))
	
	if movement_timer >= 1.0:
		can_move = true
		movement_timer = 0.0
		current_cell = target_cell
