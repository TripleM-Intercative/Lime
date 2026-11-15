extends CharacterBody2D

@export var map: TileMapLayer
 
@export var movement_duration: float = 0.5
@export var input_buffer_duration: float = 0.2
 
@onready var path_manager: PathManager = %PathManager
 
var m_entity_id: int = -1

#Movement
var m_move_from_cell: Vector2i = Vector2i.ZERO
var m_move_to_cell: Vector2i = Vector2i.ZERO

var m_move_from_pos: Vector2 = Vector2.ZERO
var m_move_to_pos: Vector2 = Vector2.ZERO

var m_movement_timer: float = 0.0
var m_can_move: bool = true

var m_input_actions: Dictionary[StringName, Vector2i] = {
	&"player_up": Vector2i.UP,
	&"player_left": Vector2i.LEFT,
	&"player_down": Vector2i.DOWN,
	&"player_right": Vector2i.RIGHT
}

var m_input_stack: Array[StringName] = []
var m_input_buffer: StringName = &""

var m_path_target_cell: Vector2i = Vector2i.ZERO
var m_use_path: bool = false



func _ready() -> void:
	assert(map, "No Map in Player")
	assert(path_manager, "No PathfindingManager in Player")
	
	m_move_from_cell = map.local_to_map(position)
	m_move_to_cell = m_move_from_cell
	
	position = map.map_to_local(m_move_from_cell)
	
	m_move_from_pos = position
	m_move_to_pos = position
	
	m_entity_id = path_manager.register_entity(Enums.EntityType.Player, m_move_from_cell, 1, true)
	
	assert(m_entity_id != -1, "Player could not be registered, start cell is blocked")

func _process(delta: float) -> void:
	if m_can_move:
		if m_calculate_move_target():
			m_start_move()
			
	else:
		m_update_move(delta)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_echo():
		return
		
	for action in m_input_actions:
		if event.is_action_pressed(action):
			m_input_stack.erase(action)
			m_input_stack.push_back(action)
			
			if !m_can_move:
				var threshold: float = 1.0 - (input_buffer_duration / movement_duration)
				
				if m_movement_timer >= threshold:
					m_input_buffer = action
					
			if m_use_path:
				m_use_path = false
				
				m_input_buffer = action
			
		if event.is_action_released(action):
			m_input_stack.erase(action)
			
	if event.is_action_pressed(&"player_to"):
		var clicked_cell: Vector2i = map.local_to_map(map.to_local(get_global_mouse_position()))
		
		if !path_manager.has_entity_space(m_entity_id, clicked_cell):
			return
			
		m_path_target_cell = clicked_cell
		m_use_path = true
 


func get_input_stack_direction() -> Vector2i:
	if m_input_stack.is_empty():
		return Vector2i.ZERO
	
	else:
		return m_input_actions[m_input_stack.back()]

func has_input() -> bool:
	return !m_input_stack.is_empty() || !m_input_buffer.is_empty()



func m_calculate_move_target() -> bool:
	var should_move: bool = false
	
	if m_input_buffer.is_empty():
		if !m_input_stack.is_empty():
			should_move = true
			m_use_path = false
			
			m_move_to_cell = m_move_from_cell + get_input_stack_direction()
			m_move_to_pos = map.map_to_local(m_move_to_cell)
			
		elif m_use_path:
			var next_cell: Vector2i
			
			next_cell = path_manager.calculate_path_segment(m_entity_id, m_path_target_cell)
			
			if next_cell == m_move_from_cell:
				m_use_path = false
				
			else:
				should_move = true
				
				m_move_to_cell = next_cell
				m_move_to_pos = map.map_to_local(next_cell)
				
	else:
		should_move = true
		m_use_path = false
		
		m_move_to_cell = m_move_from_cell + m_input_actions[m_input_buffer]
		m_move_to_pos = map.map_to_local(m_move_to_cell)
		
		m_input_buffer = &""
		
	return should_move

func m_start_move() -> bool:
	if !path_manager.update_pos(m_entity_id, m_move_to_cell):
		m_use_path = false
		
		return false
		
	m_can_move = false
	m_movement_timer = 0.0
	
	return true

func m_update_move(delta: float) -> void:
	m_movement_timer += delta / movement_duration

	if m_movement_timer < 1.0:
		position = m_move_from_pos.lerp(m_move_to_pos, m_movement_timer)
		
		return
		
	var overflow: float = m_movement_timer - 1.0
	
	position = m_move_to_pos
	m_move_from_cell = m_move_to_cell
	m_move_from_pos = m_move_to_pos
	
	m_can_move = true
	m_movement_timer = 0.0
	
	if m_calculate_move_target() && m_start_move():
		m_movement_timer = minf(overflow, 1.0)
		position = m_move_from_pos.lerp(m_move_to_pos, m_movement_timer)
