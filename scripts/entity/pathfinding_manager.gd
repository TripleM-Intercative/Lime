extends Node
class_name PathfindingManager

@export var map: TileMapLayer
@export var obstacle_weights: Dictionary[Enums.ObstacleType, int] = {
	Enums.ObstacleType.Entity: 100,
	Enums.ObstacleType.Attack: 20
}

var supported_sizes: Array[int] = [1, 2]
var astar_grids: Dictionary[int, AStarGrid2D] = {}
var offset_caches: Dictionary[int, Array] = {}

var register_value_count := 0
var entities: Dictionary[int, Structs.Entity] = {}
var obstacles: Dictionary[Vector2i, Structs.Obstacle] = {}

#Privat
func _ready() -> void:
	assert(map, "No Map in Map_Pathfinding")
	
	_init_offset_caches()
	
	_init_astar()

func _init_offset_caches() -> void:
	for size in supported_sizes:
		var offsets: Array[Vector2i] = []
		
		for x in range(size):
			for y in range(size):
				offsets.append(Vector2i(x, y))
				
		offset_caches[size] = offsets

func _init_astar() -> void:
	
	for size in supported_sizes:
		var astar = AStarGrid2D.new()
		astar.region = map.get_used_rect()
		astar.cell_size = Vector2i.ONE
		astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
		astar.default_compute_heuristic = AStarGrid2D.HEURISTIC_MANHATTAN
		astar.default_estimate_heuristic = AStarGrid2D.HEURISTIC_MANHATTAN
		astar.update()
		
		astar_grids[size] = astar
		
		_set_astar_for_size(size)

func _set_astar_for_size(size: int) -> void:
	var rect = map.get_used_rect()
	var astar = astar_grids[size]
	
	for x in range(rect.position.x, rect.end.x):
		for y in range(rect.position.y, rect.end.y):
			var check_pos = Vector2i(x, y)
			
			if !_is_valid_pos(check_pos, size):
				astar.set_point_solid(check_pos, true)

func _is_valid_pos(top_left: Vector2i, size: int) -> bool:
	var astar = astar_grids[size]
	
	for offset in offset_caches.get(size, [Vector2i.ZERO]):
		var check_pos = top_left + offset
			
		if !astar.is_in_boundsv(check_pos) || map.get_cell_source_id(check_pos) == -1:
			return false
			
		if obstacles.has(check_pos):
			if obstacles[check_pos].is_any_solid():
				return false
				
	return true

func _get_obstacle_weight(pos: Vector2i) -> int:
	if !obstacles.has(pos):
		return 0
		
	var obstacle := obstacles[pos]
	var total_weight := 0
	
	for obstacle_type in obstacle.soft_data.keys():
		var count = obstacle.soft_data[obstacle_type]
		var base_weight = obstacle_weights.get(obstacle_type, 1)
		total_weight += count * max(base_weight, 1)
		
	return total_weight

func _get_area_max_weight(pos: Vector2i, size: int) -> int:
	var max_weight = 0
	
	for offset in offset_caches.get(size, [Vector2i.ZERO]):
		var check_pos = pos + offset
		
		max_weight = maxi(max_weight, _get_obstacle_weight(check_pos))
		
	return max_weight

func _add_obstacle_area(type: int, pos: Vector2i, size: int, is_solid: bool) -> void:
	for offset in offset_caches.get(size, [Vector2i.ZERO]):
		var check_pos = pos + offset
		
		if !obstacles.has(check_pos):
			obstacles[check_pos] = Structs.Obstacle.new()
			
		obstacles[check_pos].add(type, is_solid)

func _remove_obstacle_area(type: int, pos: Vector2i, size: int, is_solid: bool) -> void:
	for offset in offset_caches.get(size, [Vector2i.ZERO]):
		var check_pos = pos + offset
		
		if obstacles.has(check_pos):
			obstacles[check_pos].remove(type, is_solid)
			
			if obstacles[check_pos].is_completely_empty():
				obstacles.erase(check_pos)

func _refresh_grid_area(pos: Vector2i, size: int) -> void:
	for grid_size in astar_grids.keys():
		var astar := astar_grids[grid_size]
		
		var bounding_min = Vector2i(pos.x - grid_size + 1, pos.y - grid_size + 1)
		var bounding_max = Vector2i(pos.x + size, pos.y + size)
		
		for x in range(bounding_min.x, bounding_max.x):
			for y in range(bounding_min.y, bounding_max.y):
				var check_pos = Vector2i(x, y)
				
				if !astar.is_in_boundsv(check_pos):
					continue
				
				if _is_valid_pos(check_pos, grid_size):
					astar.set_point_solid(check_pos, false)
					
					var weight = _get_area_max_weight(check_pos, grid_size)
					
					if weight > 0:
						astar.set_point_weight_scale(check_pos, 1.0 + (float(weight) / 10.0))
					else:
						astar.set_point_weight_scale(check_pos, 1.0)
				else:
					astar.set_point_solid(check_pos, true)

#Public
func calculate_path(value: int, target: Vector2i) -> PackedVector2Array:
	if !entities.has(value):
		return []
		
	var type = Enums.ObstacleType.Entity
	var pos = entities[value].pos
	var size = entities[value].size
	var is_solid = entities[value].is_solid
	
	var astar = astar_grids[size]
	
	if !astar.is_in_boundsv(target):
		return []
	
	_remove_obstacle_area(type, pos, size, is_solid)
	_refresh_grid_area(pos, size)
	
	var path := astar.get_point_path(entities[value].pos, target, true)
	
	_add_obstacle_area(type, pos, size, is_solid)
	_refresh_grid_area(pos, size)
	
	return path

func calculate_path_segment(value: int, target: Vector2i) -> Vector2i:
	if !entities.has(value):
		return Vector2i.ZERO
		
	var path := calculate_path(value, target)
	
	if path.size() <= 1:
		return entities[value].pos
		
	return path.get(1)

func add_obstacle(pos: Vector2i, type: Enums.ObstacleType, is_solid: bool = true) -> bool:
	if !obstacles.has(pos) && astar_grids[1].is_point_solid(pos):
		return false
		
	if !obstacles.has(pos):
		obstacles[pos] = Structs.Obstacle.new()
		
	obstacles[pos].add(type, is_solid)
	
	_refresh_grid_area(pos, 1)
	
	return true

func remove_obstacle(pos: Vector2i, type: Enums.ObstacleType, is_solid: bool = true) -> bool:
	if !obstacles.has(pos):
		return false
		
	obstacles[pos].remove(type, is_solid)
	
	if obstacles[pos].is_completely_empty():
		obstacles.erase(pos)
		
	_refresh_grid_area(pos, 1)
	
	return true

func register_entity(type: Enums.EntityType, pos: Vector2i, size: int, is_solid: bool) -> int:
	if !astar_grids[1].is_in_boundsv(pos) || astar_grids[size].is_point_solid(pos):
		return -1
		
	register_value_count += 1
	
	entities[register_value_count] = Structs.Entity.new(type, pos, size, is_solid)
	
	_add_obstacle_area(Enums.ObstacleType.Entity, pos, size, is_solid)
	_refresh_grid_area(pos, size)
	
	return register_value_count

func unregister_entity(value: int) -> bool:
	if !entities.has(value):
		return false
		
	var pos = entities[value].pos
	var size = entities[value].size
	var is_solid = entities[value].is_solid
	
	_remove_obstacle_area(Enums.ObstacleType.Entity, pos, size, is_solid)
	_refresh_grid_area(pos, size)
	
	entities.erase(value)
	
	return true

func update_pos(value: int, target: Vector2i) -> bool:
	if !entities.has(value):
		return false
		
	var type = Enums.ObstacleType.Entity
	var pos = entities[value].pos
	var size = entities[value].size
	var is_solid = entities[value].is_solid
	
	var diff = abs(target - pos)
	
	var astar = astar_grids[size]
	
	if pos == target || !astar.is_in_boundsv(target):
		return false
	
	_remove_obstacle_area(type, pos, size, is_solid)
	
	if !_is_valid_pos(target, size):
		_add_obstacle_area(type, pos, size, is_solid)
		_refresh_grid_area(pos, size)
		
		return false
	
	_add_obstacle_area(type, target, size, is_solid)
	
	entities[value].pos = target
	
	if diff.x > size || diff.y > size:
		_refresh_grid_area(pos, size)
		_refresh_grid_area(target, size)
		
	else:
		var bounding_min = Vector2i(mini(pos.x, target.x), mini(pos.y, target.y))
		var bounding_max = Vector2i(maxi(pos.x, target.x) + size, maxi(pos.y, target.y) + size)
		
		var refresh_area = maxi(bounding_max.x - bounding_min.x, bounding_max.y - bounding_min.y)
		
		_refresh_grid_area(bounding_min, refresh_area)
		
	return true

func has_entity_space(value: int, target: Vector2i) -> bool:
	if !entities.has(value):
		return false
		
	var type = Enums.ObstacleType.Entity
	var pos = entities[value].pos
	var size = entities[value].size
	var is_solid = entities[value].is_solid
	
	_remove_obstacle_area(type, pos, size, is_solid)
	_refresh_grid_area(pos, size)
	
	var valid = _is_valid_pos(target, size)
	
	_add_obstacle_area(type, pos, size, is_solid)
	_refresh_grid_area(pos, size)
	
	return valid
