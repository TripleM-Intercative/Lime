extends CharacterBody2D

@export var map : TileMapLayer

@export var movement_duration := 0.2
@export var input_buffer_duration := 0.1

var current_cell := Vector2i(0, 0)
var target_cell := Vector2i(0, 0)

var target_direction := Vector2i(0, 0)
var movement_direction := Vector2i(0, 0)
var buffer_direction := Vector2i(0, 0)
var target_pos := Vector2(0.0, 0.0)

var movement_timer := 0.0
var can_move := true
var active_input_buffer := false

var input_direction : InputEvent

var actions = {
	&"player_up" : Vector2i.UP,
	&"player_left" : Vector2i.LEFT,
	&"player_down" : Vector2i.DOWN,
	&"player_right" : Vector2i.RIGHT
}

func _ready() -> void:
	assert(map, "No Map in Player")

	current_cell = map.local_to_map(position)
	position = map.map_to_local(current_cell)

func _unhandled_input(event: InputEvent) -> void:
	#print(event)
	pass

func _process(delta: float) -> void:
	execute_movement(delta)

func execute_movement(delta: float) -> void:
	if can_move:
		if calculate_target():
			can_move = false
			active_input_buffer = false
			movement_timer = 0.0
	else:
		position = lerp(map.map_to_local(current_cell), map.map_to_local(target_cell), clamp(movement_timer / movement_duration, 0.0, 1.0))
		
		movement_timer += delta
		
		if movement_timer >= movement_duration - input_buffer_duration:
			active_input_buffer = true
		
		if movement_timer >= movement_duration:
			movement_timer = 0.0
			can_move = true
			active_input_buffer = false
			current_cell = target_cell

func calculate_direction() -> Vector2i:
	if buffer_direction == Vector2i.ZERO:
		return movement_direction
	else:
		return buffer_direction
	
func calculate_target() -> bool:
	
	var direction = calculate_direction()
	buffer_direction = Vector2i.ZERO
	
	if direction != Vector2i.ZERO && map.get_cell_source_id(current_cell + direction) != -1:
			target_cell = current_cell + direction
			
			return true
	else:
		return false

func calculate_input() -> void:
	pass
	

func _on_input_manager_input_changed(new: Array[InputData]) -> void:
	prints(new.get(0).value, new.get(0).hold, 
	new.get(1).value, new.get(1).hold, 
	new.get(2).value, new.get(2).hold, 
	new.get(3).value, new.get(3).hold)
