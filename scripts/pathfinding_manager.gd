extends Node

@export var map: TileMapLayer
@export var obstacle_weights: Dictionary[Enums.ObstacleType, int] = {
	Enums.ObstacleType.Entity: 100,
	Enums.ObstacleType.Attack: 20
}

var supported_sizes: Array[int] = [1, 2]
var astar_grids: Dictionary[int, AStarGrid2D] = {}

var register_value_count := 0
var entities: Dictionary[int, SmartStructs.Entity] = {}
var obstacles: Dictionary[Vector2i, SmartStructs.Obstacle] = {}

func _ready() -> void:
	assert(map, "No Map in Map_Pathfinding")
	
	_init_astar()

func _init_astar() -> void:
	
	for size in supported_sizes:
		var astar = AStarGrid2D.new()
		astar.region = map.get_used_rect()
		astar.cell_size = Vector2i.ONE
		astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
		astar.default_compute_heuristic = AStarGrid2D.HEURISTIC_MANHATTAN
		astar.default_estimate_heuristic = AStarGrid2D.HEURISTIC_MANHATTAN
		astar.update()
		
		_set_astar_for_size(astar, size)
		
		astar_grids[size] = astar

func _set_astar_for_size(astar: AStarGrid2D, size: int) -> void:
	var rect = map.get_used_rect()
	
	for x in range(rect.position.x, rect.end.x):
		for y in range(rect.position.y, rect.end.y):
			
			var check_pos = Vector2i(x, y)
			
			if !_has_entity_space(astar, check_pos, size):
				astar.set_point_solid(check_pos, true)

func _has_entity_space(astar: AStarGrid2D, top_left: Vector2i, size: int) -> bool:
	for x in range(size):
		for y in range(size):
			
			var check_pos = top_left + Vector2i(x, y)
			
			if !astar.is_in_boundsv(check_pos) || map.get_cell_source_id(check_pos) == -1:
				return false
				
			if obstacles.has(check_pos):
				if obstacles[check_pos].is_solid:
					return false
				
	return true

func _get_obstacle_weight(pos: Vector2i) -> int:
	if !obstacles.has(pos):
		return 0
		
	var obstacle := obstacles[pos]
	var total_weight := 0
	
	for obstacle_type in obstacle.data.keys():
		if !obstacle.is_solid:
			var count = obstacle.data[obstacle_type]
			var base_weight = obstacle_weights.get(obstacle_type, 0)
			total_weight += count * base_weight
		
	return total_weight

func _get_area_max_weight(pos: Vector2i, size: int) -> int:
	var max_weight = 0
	
	for x in range(size):
		for y in range(size):
			
			var check_pos = pos + Vector2i(x, y)
			
			max_weight = maxi(max_weight, _get_obstacle_weight(check_pos))
			
	return max_weight

func _refresh_grid_cells(pos: Vector2i, skip_solid: bool = false) -> void:
	for grid_size in astar_grids.keys():
		var astar := astar_grids[grid_size]
		
		for x in range(grid_size):
			for y in range(grid_size):
				
				var check_pos = pos - Vector2i(x, y)
				
				if !astar.is_in_boundsv(check_pos):
					continue
				
				if skip_solid && astar.is_point_solid(check_pos):
					continue
					
				if _has_entity_space(astar, check_pos, grid_size):
					astar.set_point_solid(check_pos, false)
					
					var weight = _get_area_max_weight(check_pos, grid_size)
					if weight > 0:
						astar.set_point_weight_scale(check_pos, 1.0 + (float(weight) / 10.0))
					else:
						astar.set_point_weight_scale(check_pos, 1.0)
				else:
					astar.set_point_solid(check_pos, true)

func calculate_path(value: int, target: Vector2i) -> PackedVector2Array:
	if !entities.has(value):
		return []
		
	var astar = astar_grids[entities[value].size]
	var path := astar.get_point_path(entities[value].pos, target, true)
	
	return path

func calculate_path_segment(value: int, target: Vector2i) -> Vector2i:
	if !entities.has(value):
		return Vector2i.ZERO
		
	var astar = astar_grids[entities[value].size]
	var path := astar.get_point_path(entities[value].pos, target, true)
	
	if path.size() <= 1:
		return entities[value].pos
	
	return path.get(1)

func add_obstacle(pos: Vector2i, type: int, is_solid: bool = true) -> bool:
	if !obstacles.has(pos) && astar_grids[1].is_point_solid(pos):
		return false
		
	if !obstacles.has(pos):
		obstacles[pos] = SmartStructs.Obstacle.new()
		
	obstacles[pos].add(type, is_solid)
	
	_refresh_grid_cells(pos ,true)
	
	return true

func remove_obstacle(pos: Vector2i, type: int, is_solid: bool = true) -> bool:
	if !obstacles.has(pos):
		return false
		
	obstacles[pos].remove(type, is_solid)
	
	if obstacles[pos].is_completely_empty():
		obstacles.erase(pos)
		
	_refresh_grid_cells(pos)
	
	return true

func register_entity(type: Enums.EntityType, pos: Vector2i, size: int, is_solid: bool) -> int:
	if !astar_grids[1].is_in_boundsv(pos) || astar_grids[size].is_point_solid(pos):
		return -1
		
	register_value_count += 1
	
	entities[register_value_count] = SmartStructs.Entity.new(type, pos, size, is_solid)
	
	for x in range(size):
		for y in range(size):
			
			add_obstacle(pos + Vector2i(x, y), Enums.ObstacleType.Entity, is_solid)
			
	return register_value_count

func unregister_entity(value: int) -> bool:
	if !entities.has(value):
		return false
		
	var type = Enums.ObstacleType.Entity
	var pos = entities[value].pos
	var size = entities[value].size
	var is_solid = entities[value].is_solid
	
	for x in range(size):
		for y in range(size):
			
			remove_obstacle(pos + Vector2i(x, y), type, is_solid)
			
	entities.erase(value)
	
	return true

func update_pos(value: int, target: Vector2i) -> void:
	if !entities.has(value):
		return
		
	var type = Enums.ObstacleType.Entity
	var pos = entities[value].pos
	var size = entities[value].size
	var is_solid = entities[value].is_solid
	
	if pos == target:
		return
	
	var diff = target - entities[value].pos
	
	if abs(diff.x) > size || abs(diff.y) > size:
		for x in range(size):
			for y in range(size):
				
				remove_obstacle(pos + Vector2i(x, y), type)
				add_obstacle(target + Vector2i(x, y), type, is_solid)
				
		entities[value].pos = target
		
		return
		
	var bounding_min = Vector2i(mini(pos.x, target.x), mini(pos.y, target.y))
	var bounding_max = Vector2i(maxi(pos.x, target.x) + size, maxi(pos.y, target.y) + size)
	
	for x in range(bounding_min.x, bounding_max.x):
		for y in range(bounding_min.y, bounding_max.y):
			
			var check_pos = Vector2i(x, y)
			
			var was_active_x = (check_pos.x >= pos.x && check_pos.x < pos.x + size)
			var was_active_y = (check_pos.y >= pos.y && check_pos.y < pos.y + size)
			
			var is_active_x = (check_pos.x >= target.x && check_pos.x < target.x + size)
			var is_active_y = (check_pos.y >= target.y && check_pos.y < target.y + size)
			
			var was_active = was_active_x && was_active_y
			var is_active = is_active_x && is_active_y
			
			if was_active && !is_active:
				remove_obstacle(check_pos, type)
				
				continue
				
			if !was_active && is_active:
				add_obstacle(check_pos, type, is_solid)
				
				continue
				
	entities[value].pos = target
