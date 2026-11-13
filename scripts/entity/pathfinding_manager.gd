extends Node
class_name PathfindingManager

@export var map: TileMapLayer
@export var obstacle_cost: Dictionary[Enums.ObstacleType, float] = {
	Enums.ObstacleType.Entity: 10.0,
	Enums.ObstacleType.Attack: 2.0
}

const CLEARANCE_NEIGHBORS := [Vector2i.RIGHT, Vector2i.DOWN, Vector2i.ONE]

var m_supported_sizes: Array[int] = [1, 2]
var m_astar_grids: Dictionary[int, AStarGrid2D] = {}
var m_offset_caches: Dictionary[int, Array] = {}

var m_register_id_count: int = 0
var m_entities: Dictionary[int, Structs.Entity] = {}

var m_solid_entities: Dictionary[Vector2i, int] = {}
var m_obstacles: Dictionary[Vector2i, Structs.Obstacle] = {}

var m_dirty_cells: Dictionary[Vector2i, bool] = {}

var m_map_rect: Rect2i
var m_max_size: int
var m_clearance: PackedByteArray
var m_static_version: int = 0

func _ready() -> void:
	assert(map, "No Map in Map_Pathfinding")
	assert(1 in m_supported_sizes, "Size 1 in Map_Pathfinding missing")
	
	m_init_offset_caches()
	
	m_init_astar()
	
	m_init_clearance()
	
	m_sync_grids()

#Entity
func register_entity(type: Enums.EntityType, top_left: Vector2i, size: int, is_solid: bool) -> int:
	assert(m_astar_grids.has(size), "Größe %d nicht in m_supported_sizes" % size)
	
	if !m_is_space_free(top_left, size):
		return -1
		
	m_register_id_count += 1
	
	m_entities[m_register_id_count] = Structs.Entity.new(type, top_left, size, is_solid)
	
	m_add_entity(m_register_id_count)
	
	return m_register_id_count

func unregister_entity(id: int) -> bool:
	if !m_entities.has(id):
		return false
		
	m_remove_entity(id)
	
	m_entities.erase(id)
	
	return true

func update_pos(id: int, target: Vector2i) -> bool:
	if !m_entities.has(id):
		return false
		
	var entity: Structs.Entity = m_entities[id]
	if entity.pos == target || !m_astar_grids[entity.size].is_in_boundsv(target):
		return false
		
	if !m_is_space_free(target, entity.size, id):
		return false
		
	m_remove_entity(id)
	
	entity.pos = target
	
	m_add_entity(id)
	
	return true

func calculate_path(id: int, target: Vector2i) -> PackedVector2Array:
	if !m_entities.has(id):
		return []

	var entity: Structs.Entity = m_entities[id]
	var astar := m_astar_grids[entity.size]

	if !astar.is_in_boundsv(target):
		return []

	m_flush_dirty_cells()

	return astar.get_point_path(entity.pos, target, true)

func calculate_path_segment(id: int, target: Vector2i) -> Vector2i:
	if !m_entities.has(id):
		return Vector2i.ZERO
		
	var path := calculate_path(id, target)
	
	if path.size() <= 1:
		return m_entities[id].pos
		
	return path.get(1)

func has_entity_space(id: int, target: Vector2i) -> bool:
	if !m_entities.has(id):
		return false
		
	return m_is_space_free(target, m_entities[id].size, id)

#Obstacle
func add_obstacle(pos: Vector2i, type: Enums.ObstacleType, is_solid: bool = true) -> bool:
	if !m_is_cell_valid(pos):
		return false
		
	if !m_obstacles.has(pos):
		m_obstacles[pos] = Structs.Obstacle.new()
		
	m_obstacles[pos].add(type, is_solid)
	
	if is_solid:
		m_update_clearance(pos)
	else:
		m_set_area_dirty(pos, 1)
	
	return true

func remove_obstacle(pos: Vector2i, type: Enums.ObstacleType, is_solid: bool = true) -> bool:
	if !m_obstacles.has(pos):
		return false
		
	m_obstacles[pos].remove(type, is_solid)
	
	if m_obstacles[pos].is_completely_empty():
		m_obstacles.erase(pos)
		
	if is_solid:
		m_update_clearance(pos)
	else:
		m_set_area_dirty(pos, 1)
	
	return true

#Init Functions
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
		astar.region = map.get_used_rect()
		astar.cell_size = Vector2i.ONE
		astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
		astar.default_compute_heuristic = AStarGrid2D.HEURISTIC_MANHATTAN
		astar.default_estimate_heuristic = AStarGrid2D.HEURISTIC_MANHATTAN
		astar.update()
		
		m_astar_grids[size] = astar

func m_init_clearance() -> void:
	m_map_rect = map.get_used_rect()
	m_max_size = m_supported_sizes.max()
	m_clearance.resize(m_map_rect.size.x * m_map_rect.size.y)
	m_clearance.fill(0)
	
	for y in range(m_map_rect.end.y - 1, m_map_rect.position.y - 1, -1):
		for x in range(m_map_rect.end.x - 1, m_map_rect.position.x - 1, -1):
			m_compute_clearance_value(Vector2i(x, y))

func m_sync_grids() -> void:
	for size in m_supported_sizes:
		for x in range(m_map_rect.position.x, m_map_rect.end.x):
			for y in range(m_map_rect.position.y, m_map_rect.end.y):
				m_update_anchor(Vector2i(x, y), size)

#Helper Functions

#Space
func m_fits_on_map(top_left: Vector2i, size: int) -> bool:
	return m_get_clearance_value(top_left) >= size

func m_is_space_free(top_left: Vector2i, size: int, ignore_id: int = -1) -> bool:
	if !m_fits_on_map(top_left, size):
		return false
		
	for offset in m_offset_caches[size]:
		var other: int = m_solid_entities.get(top_left + offset, -1)
		if other != -1 and other != ignore_id:
			return false
	return true

func m_is_cell_valid(cell: Vector2i) -> bool:
	return m_map_rect.has_point(cell) && map.get_cell_source_id(cell) != -1

func m_is_cell_passable(cell: Vector2i) -> bool:
	if !m_is_cell_valid(cell):
		return false
		
	return !(m_obstacles.has(cell) && m_obstacles[cell].is_any_solid())

#Cost
func m_get_soft_cost(cell: Vector2i) -> float:
	if !m_obstacles.has(cell):
		return 0.0
	return m_obstacles[cell].get_soft_cost(obstacle_cost)

func m_get_area_soft_cost(pos: Vector2i, size: int) -> float:
	var result: float = 0.0
	for offset in m_offset_caches[size]:
		result = maxf(result, m_get_soft_cost(pos + offset))
	return result

#Entity
func m_add_entity(id: int) -> void:
	var entity: Structs.Entity = m_entities[id]
	
	m_add_obstacle_area(Enums.ObstacleType.Entity, entity.pos, entity.size, false)
	
	if entity.is_solid:
		for offset in m_offset_caches[entity.size]:
			m_solid_entities[entity.pos + offset] = id
			
	m_set_area_dirty(entity.pos, entity.size)

func m_remove_entity(id: int) -> void:
	var entity: Structs.Entity = m_entities[id]
	
	m_remove_obstacle_area(Enums.ObstacleType.Entity, entity.pos, entity.size, false)
	
	if entity.is_solid:
		for offset in m_offset_caches[entity.size]:
			var cell = entity.pos + offset
			
			if m_solid_entities.get(cell, -1) == id:
				m_solid_entities.erase(cell)
				
	m_set_area_dirty(entity.pos, entity.size)

#Obstacle
func m_add_obstacle_area(type: int, pos: Vector2i, size: int, is_solid: bool) -> void:
	for offset in m_offset_caches[size]:
		var check_pos = pos + offset
		
		if !m_obstacles.has(check_pos):
			m_obstacles[check_pos] = Structs.Obstacle.new()
			
		m_obstacles[check_pos].add(type, is_solid)

func m_remove_obstacle_area(type: int, pos: Vector2i, size: int, is_solid: bool) -> void:
	for offset in m_offset_caches[size]:
		var check_pos = pos + offset
		
		if m_obstacles.has(check_pos):
			m_obstacles[check_pos].remove(type, is_solid)
			
			if m_obstacles[check_pos].is_completely_empty():
				m_obstacles.erase(check_pos)

#Dirty
func m_set_area_dirty(top_left: Vector2i, size: int) -> void:
	for offset in m_offset_caches[size]:
		m_dirty_cells[top_left + offset] = true

func m_flush_dirty_cells() -> void:
	if m_dirty_cells.is_empty():
		return
		
	for size in m_supported_sizes:
		var anchors: Dictionary[Vector2i, bool] = {}
		
		for cell in m_dirty_cells:
			for offset in m_offset_caches[size]:
				anchors[cell - offset] = true
				
		for anchor in anchors:
			m_update_anchor(anchor, size)
			
	m_dirty_cells.clear()

func m_update_anchor(anchor: Vector2i, size: int) -> void:
	var astar = m_astar_grids[size]
	
	if !astar.is_in_boundsv(anchor):
		return
		
	if !m_fits_on_map(anchor, size):
		astar.set_point_solid(anchor, true)
		return
		
	astar.set_point_solid(anchor, false)
	astar.set_point_weight_scale(anchor, 1.0 + m_get_area_soft_cost(anchor, size))

#Clearance
func m_cell_to_index(cell: Vector2i) -> int:
	return (cell.y - m_map_rect.position.y) * m_map_rect.size.x + (cell.x - m_map_rect.position.x)

func m_get_clearance_value(cell: Vector2i) -> int:
	if !m_map_rect.has_point(cell):
		return 0
		
	return m_clearance[m_cell_to_index(cell)]

func m_compute_clearance_value(cell: Vector2i) -> void:
	var value = 0
	
	if m_is_cell_passable(cell):
		var neighbors: int = m_max_size
		for direction in CLEARANCE_NEIGHBORS:
			neighbors = mini(neighbors, m_get_clearance_value(cell + direction))

		value = mini(m_max_size, 1 + neighbors)

	m_clearance[m_cell_to_index(cell)] = value

func m_update_clearance(cell: Vector2i) -> void:
	for y in range(cell.y, cell.y - m_max_size, -1):
		for x in range(cell.x, cell.x - m_max_size, -1):
			var check_pos = Vector2i(x, y)
			
			if m_map_rect.has_point(check_pos):
				m_compute_clearance_value(check_pos)
	
	m_dirty_cells[cell] = true
	m_static_version += 1
