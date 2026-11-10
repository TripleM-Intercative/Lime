extends Node
class_name PathfindingManager

@export var m_map: TileMapLayer
@export var m_obstacle_weights: Dictionary[Enums.ObstacleType, int] = {
	Enums.ObstacleType.Entity: 100,
	Enums.ObstacleType.Attack: 20
}

var m_supported_sizes: Array[int] = [1, 2]
var m_astar_grids: Dictionary[int, AStarGrid2D] = {}
var m_offset_caches: Dictionary[int, Array] = {}

var m_register_value_count: int = 0
var m_entities: Dictionary[int, Structs.Entity] = {}
var m_obstacles: Dictionary[Vector2i, Structs.Obstacle] = {}

func _ready() -> void:
	assert(m_map, "No Map in Map_Pathfinding")
	
	m_init_offset_caches()
	
	m_init_astar()

func calculate_path(value: int, target: Vector2i) -> PackedVector2Array:
	if !m_entities.has(value):
		return []
		
	var type = Enums.ObstacleType.Entity
	var pos = m_entities[value].pos
	var size = m_entities[value].size
	var is_solid = m_entities[value].is_solid
	
	var astar = m_astar_grids[size]
	
	if !astar.is_in_boundsv(target):
		return []
	
	m_remove_obstacle_area(type, pos, size, is_solid)
	m_refresh_grid_area(pos, size)
	
	var path := astar.get_point_path(pos, target, true)
	
	m_add_obstacle_area(type, pos, size, is_solid)
	m_refresh_grid_area(pos, size)
	
	return path

func calculate_path_segment(value: int, target: Vector2i) -> Vector2i:
	if !m_entities.has(value):
		return Vector2i.ZERO
		
	var path := calculate_path(value, target)
	
	if path.size() <= 1:
		return m_entities[value].pos
		
	return path.get(1)

func add_obstacle(pos: Vector2i, type: Enums.ObstacleType, is_solid: bool = true) -> bool:
	if !m_obstacles.has(pos) && m_astar_grids[1].is_point_solid(pos):
		return false
		
	if !m_obstacles.has(pos):
		m_obstacles[pos] = Structs.Obstacle.new()
		
	m_obstacles[pos].add(type, is_solid)
	
	m_refresh_grid_area(pos, 1)
	
	return true

func remove_obstacle(pos: Vector2i, type: Enums.ObstacleType, is_solid: bool = true) -> bool:
	if !m_obstacles.has(pos):
		return false
		
	m_obstacles[pos].remove(type, is_solid)
	
	if m_obstacles[pos].is_completely_empty():
		m_obstacles.erase(pos)
		
	m_refresh_grid_area(pos, 1)
	
	return true

func register_entity(type: Enums.EntityType, pos: Vector2i, size: int, is_solid: bool) -> int:
	if !m_astar_grids[1].is_in_boundsv(pos) || m_astar_grids[size].is_point_solid(pos):
		return -1
		
	m_register_value_count += 1
	
	m_entities[m_register_value_count] = Structs.Entity.new(type, pos, size, is_solid)
	
	m_add_obstacle_area(Enums.ObstacleType.Entity, pos, size, is_solid)
	m_refresh_grid_area(pos, size)
	
	return m_register_value_count

func unregister_entity(value: int) -> bool:
	if !m_entities.has(value):
		return false
		
	var pos = m_entities[value].pos
	var size = m_entities[value].size
	var is_solid = m_entities[value].is_solid
	
	m_remove_obstacle_area(Enums.ObstacleType.Entity, pos, size, is_solid)
	m_refresh_grid_area(pos, size)
	
	m_entities.erase(value)
	
	return true

func update_pos(value: int, target: Vector2i) -> bool:
	if !m_entities.has(value):
		return false
		
	var type = Enums.ObstacleType.Entity
	var pos = m_entities[value].pos
	var size = m_entities[value].size
	var is_solid = m_entities[value].is_solid
	
	var diff = abs(target - pos)
	
	var astar = m_astar_grids[size]
	
	if pos == target || !astar.is_in_boundsv(target):
		return false
	
	m_remove_obstacle_area(type, pos, size, is_solid)
	
	if !m_is_valid_pos(target, size):
		m_add_obstacle_area(type, pos, size, is_solid)
		m_refresh_grid_area(pos, size)
		
		return false
	
	m_add_obstacle_area(type, target, size, is_solid)
	
	m_entities[value].pos = target
	
	if diff.x > size || diff.y > size:
		m_refresh_grid_area(pos, size)
		m_refresh_grid_area(target, size)
		
	else:
		var bounding_min = Vector2i(mini(pos.x, target.x), mini(pos.y, target.y))
		var bounding_max = Vector2i(maxi(pos.x, target.x) + size, maxi(pos.y, target.y) + size)
		
		var refresh_area = maxi(bounding_max.x - bounding_min.x, bounding_max.y - bounding_min.y)
		
		m_refresh_grid_area(bounding_min, refresh_area)
		
	return true

func has_entity_space(value: int, target: Vector2i) -> bool:
	if !m_entities.has(value):
		return false
		
	var type = Enums.ObstacleType.Entity
	var pos = m_entities[value].pos
	var size = m_entities[value].size
	var is_solid = m_entities[value].is_solid
	
	m_remove_obstacle_area(type, pos, size, is_solid)
	m_refresh_grid_area(pos, size)
	
	var valid = m_is_valid_pos(target, size)
	
	m_add_obstacle_area(type, pos, size, is_solid)
	m_refresh_grid_area(pos, size)
	
	return valid

func m_init_offset_caches() -> void:
	for size in m_supported_sizes:
		var offsets: Array[Vector2i] = []
		
		for x in range(size):
			for y in range(size):
				offsets.append(Vector2i(x, y))
				
		m_offset_caches[size] = offsets

func m_init_astar() -> void:
	
	for size in m_supported_sizes:
		var astar = AStarGrid2D.new()
		astar.region = m_map.get_used_rect()
		astar.cell_size = Vector2i.ONE
		astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
		astar.default_compute_heuristic = AStarGrid2D.HEURISTIC_MANHATTAN
		astar.default_estimate_heuristic = AStarGrid2D.HEURISTIC_MANHATTAN
		astar.update()
		
		m_astar_grids[size] = astar
		
		m_set_astar_for_size(size)

func m_set_astar_for_size(size: int) -> void:
	var rect = m_map.get_used_rect()
	var astar = m_astar_grids[size]
	
	for x in range(rect.position.x, rect.end.x):
		for y in range(rect.position.y, rect.end.y):
			var check_pos = Vector2i(x, y)
			
			if !m_is_valid_pos(check_pos, size):
				astar.set_point_solid(check_pos, true)

func m_is_valid_pos(top_left: Vector2i, size: int) -> bool:
	var astar = m_astar_grids[size]
	
	for offset in m_offset_caches.get(size, [Vector2i.ZERO]):
		var check_pos = top_left + offset
			
		if !astar.is_in_boundsv(check_pos) || m_map.get_cell_source_id(check_pos) == -1:
			return false
			
		if m_obstacles.has(check_pos):
			if m_obstacles[check_pos].is_any_solid():
				return false
				
	return true

func m_get_obstacle_weight(pos: Vector2i) -> int:
	if !m_obstacles.has(pos):
		return 0
		
	var obstacle = m_obstacles[pos]
	var total_weight = 0
	
	for obstacle_type in obstacle.soft_data.keys():
		var count = obstacle.soft_data[obstacle_type]
		var base_weight = m_obstacle_weights.get(obstacle_type, 1)
		total_weight += count * max(base_weight, 1)
		
	return total_weight

func m_get_area_max_weight(pos: Vector2i, size: int) -> int:
	var max_weight = 0
	
	for offset in m_offset_caches.get(size, [Vector2i.ZERO]):
		var check_pos = pos + offset
		
		max_weight = maxi(max_weight, m_get_obstacle_weight(check_pos))
		
	return max_weight

func m_add_obstacle_area(type: int, pos: Vector2i, size: int, is_solid: bool) -> void:
	for offset in m_offset_caches.get(size, [Vector2i.ZERO]):
		var check_pos = pos + offset
		
		if !m_obstacles.has(check_pos):
			m_obstacles[check_pos] = Structs.Obstacle.new()
			
		m_obstacles[check_pos].add(type, is_solid)

func m_remove_obstacle_area(type: int, pos: Vector2i, size: int, is_solid: bool) -> void:
	for offset in m_offset_caches.get(size, [Vector2i.ZERO]):
		var check_pos = pos + offset
		
		if m_obstacles.has(check_pos):
			m_obstacles[check_pos].remove(type, is_solid)
			
			if m_obstacles[check_pos].is_completely_empty():
				m_obstacles.erase(check_pos)

func m_refresh_grid_area(pos: Vector2i, size: int) -> void:
	for grid_size in m_astar_grids.keys():
		var astar = m_astar_grids[grid_size]
		
		var bounding_min = Vector2i(pos.x - grid_size + 1, pos.y - grid_size + 1)
		var bounding_max = Vector2i(pos.x + size, pos.y + size)
		
		for x in range(bounding_min.x, bounding_max.x):
			for y in range(bounding_min.y, bounding_max.y):
				var check_pos = Vector2i(x, y)
				
				if !astar.is_in_boundsv(check_pos):
					continue
				
				if m_is_valid_pos(check_pos, grid_size):
					astar.set_point_solid(check_pos, false)
					
					var weight = m_get_area_max_weight(check_pos, grid_size)
					
					if weight > 0:
						astar.set_point_weight_scale(check_pos, 1.0 + (float(weight) / 10.0))
					else:
						astar.set_point_weight_scale(check_pos, 1.0)
				else:
					astar.set_point_solid(check_pos, true)
