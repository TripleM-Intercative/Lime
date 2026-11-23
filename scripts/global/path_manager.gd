class_name PathManager
extends Node

signal entity_cell_changed(type: LEntity, old: Vector2i, new: Vector2i)

@export var map: TileMapLayer

@export var supported_sizes: Array[int] = [1, 2]

@export var obstacle_cost: Dictionary[Enums.ObstacleType, float] = {
	Enums.ObstacleType.Entity: 10.0,
	Enums.ObstacleType.Attack: 2.0
}

@export var always_update_on_move: bool = false
@export var path_target_recalculation_offset: int = 2

var m_map_rect: Rect2i

#Grid
var m_max_size: int
var m_astar_grids: Dictionary[int, AStarGrid2D] = {}
var m_clearance: PackedByteArray
var m_clearance_version: int = 0

#Entity
var m_register_id_count: int = 0
var m_entities: Dictionary[int, Structs.Entity] = {}
var m_offset_caches: Dictionary[int, Array] = {}

#Collision Data
var m_obstacles: Dictionary[Vector2i, Structs.Obstacle] = {}
var m_solid_entities: Dictionary[Vector2i, int] = {}

#Update Stack
var m_dirty_cells: Dictionary[Vector2i, bool] = {}

#Path
var m_path_cache: Dictionary[int, Structs.CachedPath] = {}

#Build In

func _ready() -> void:
	assert(map, "No Map in Map_Pathfinding")
	assert(1 in supported_sizes, "Size 1 in Map_Pathfinding missing")
	
	m_init_offset_caches()
	
	m_init_astar()
	
	m_init_clearance()
	
	m_sync_grids()
	
	MapManager.path_manager = self

#Public

func reinit() -> void:
	m_astar_grids.clear()
	m_clearance.clear()
	
	m_entities.clear()
	m_offset_caches.clear()
	
	m_obstacles.clear()
	m_solid_entities.clear()
	
	m_dirty_cells.clear()
	
	m_path_cache.clear()
	
	m_clearance_version = 0
	m_register_id_count = 0
	
	m_init_offset_caches()
	
	m_init_astar()
	
	m_init_clearance()
	
	m_sync_grids()

#Entity
func register_entity(type: LEntity, top_left: Vector2i, size: int, solid: bool) -> int:
	assert(m_astar_grids.has(size), "Größe %d nicht in supported_sizes" % size)
	
	if !m_has_space_map_and_entity(top_left, size):
		return -1
		
	m_register_id_count += 1
	
	m_entities[m_register_id_count] = Structs.Entity.new(type, top_left, size, solid)
	
	m_add_entity_data(m_register_id_count)
	
	return m_register_id_count

func unregister_entity(id: int) -> bool:
	if !m_entities.has(id):
		return false
		
	m_remove_entity_data(id)
	
	m_entities.erase(id)
	m_path_cache.erase(id)
	
	return true

func has_entity_space(id: int, target: Vector2i) -> bool:
	if !m_entities.has(id):
		return false
		
	return m_has_space_map_and_entity(target, m_entities[id].size, id)

func update_pos(id: int, target: Vector2i) -> bool:
	if !m_entities.has(id):
		return false
		
	var entity: Structs.Entity = m_entities[id]
	
	if entity.pos == target:
		return false
		
	if !m_has_space_map_and_entity(target, entity.size, id):
		return false
		
	entity_cell_changed.emit(entity.type, entity.pos, target)
	
	m_remove_entity_data(id)
	entity.pos = target
	m_add_entity_data(id)
	
	return true

#Obstacle
func add_obstacle(type: Enums.ObstacleType, top_left: Vector2i, size: int, solid: bool) -> bool:
	if solid:
		for offset in m_get_offset_caches(size):
			var check_pos: Vector2i = top_left + offset
			
			if !m_is_cell_valid(check_pos) || m_is_entity_at(check_pos):
				return false
				
	m_add_obstacle_data(type, top_left, size, solid)
	
	if solid:
		m_update_clearance(top_left, size)
		
	return true

func remove_obstacle(type: Enums.ObstacleType, top_left: Vector2i, size: int, solid: bool) -> bool:
	var found: bool = false
	
	for offset in m_get_offset_caches(size):
		var check_pos: Vector2i = top_left + offset
		
		if m_obstacles.has(check_pos) && m_obstacles[check_pos].has_type(type, solid):
			found = true
			break
			
	if !found:
		return false
		
	m_remove_obstacle_data(type, top_left, size, solid)
	
	if solid:
		m_update_clearance(top_left, size)
		
	return true

#Path
func calculate_path(id: int, target: Vector2i) -> Array[Vector2i]:
	if !m_entities.has(id):
		return []
		
	var entity: Structs.Entity = m_entities[id]
	var astar: AStarGrid2D = m_astar_grids[entity.size]
	
	if !astar.is_in_boundsv(target):
		return []
		
	m_update_dirty_cells()
	
	return astar.get_id_path(entity.pos, target, true)

func calculate_path_segment(id: int, target: Vector2i) -> Vector2i:
	if !m_entities.has(id):
		return Vector2i(-1, -1)
		
	var entity: Structs.Entity = m_entities[id]
	
	var cache: Structs.CachedPath = m_path_cache.get(id)
	
	if !always_update_on_move && cache != null && m_is_cache_valid(cache, target):
		var index: int = cache.cells.find(entity.pos)
		
		if index != -1:
			if index + 1 < cache.cells.size():
				var next: Vector2i = cache.cells[index + 1]
				
				if m_has_space_map_and_entity(next, entity.size, id):
					return next
					
			elif !cache.complete:
				return entity.pos
	
	var path: Array[Vector2i] = calculate_path(id, target)
	
	if !always_update_on_move:
		if !m_path_cache.has(id):
			m_path_cache[id] = Structs.CachedPath.new()
			
		cache = m_path_cache[id]
		cache.cells = path
		cache.target = target
		cache.complete = !path.is_empty() && path[-1] == target
		cache.version = m_clearance_version
	
	if path.size() <= 1:
		return entity.pos
		
	return path[1]

func is_target_reachable(id: int) -> bool:
	if !m_path_cache.has(id):
		return false
		
	var cache: Structs.CachedPath = m_path_cache[id]
	
	return cache.complete

func get_reachable_target(id: int) -> Vector2i:
	if !m_path_cache.has(id):
		return Vector2i(-1, -1)
		
	var cache: Structs.CachedPath = m_path_cache[id]
	
	if cache.cells.is_empty():
		return m_entities[id].pos
		
	return cache.cells[-1]

#Map
func map_cells_changed(cells: Array[Vector2i]) -> void:
	for cell in cells:
		if m_map_rect.has_point(cell):
			m_update_clearance(cell, 1)

func map_area_changed(top_left: Vector2i, size: int) -> void:
	if !m_map_rect.intersects(Rect2i(top_left, Vector2i(size, size))):
		return
		
	m_update_clearance(top_left, size)

#Distance
func is_entity_in_range(id: int, character: LEntity, radius: int) -> bool:
	if !character || !m_entities.has(id):
		return false
		
	var diff: Vector2i = (m_entities[id].pos - character.current_cell).abs()
	
	return (diff.x + diff.y) <= radius

#Get
func get_entities_of_type(type: LEntity) -> Array[Structs.Entity]:
	var entities: Array[Structs.Entity]
	
	for entity: Structs.Entity in m_entities.values():
		if entity.type == type:
			entities.append(entity)
			
	return entities

func get_registerd_entitis() -> Dictionary[int, Structs.Entity]:
	return m_entities

#Private

#Init Functions
func m_init_offset_caches() -> void:
	for size in supported_sizes:
		m_get_offset_caches(size)

func m_init_astar() -> void:
	
	for size in supported_sizes:
		var astar: AStarGrid2D = AStarGrid2D.new()
		astar.region = map.get_used_rect()
		astar.cell_size = Vector2i.ONE
		astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
		astar.default_compute_heuristic = AStarGrid2D.HEURISTIC_MANHATTAN
		astar.default_estimate_heuristic = AStarGrid2D.HEURISTIC_MANHATTAN
		astar.update()
		
		m_astar_grids[size] = astar

func m_init_clearance() -> void:
	m_map_rect = map.get_used_rect()
	m_max_size = supported_sizes.max()
	
	m_clearance.resize(m_map_rect.size.x * m_map_rect.size.y)
	m_clearance.fill(0)
	
	for y in range(m_map_rect.end.y - 1, m_map_rect.position.y - 1, -1):
		for x in range(m_map_rect.end.x - 1, m_map_rect.position.x - 1, -1):
			m_calculate_clearance_value(Vector2i(x, y))

func m_sync_grids() -> void:
	for size in supported_sizes:
		for x in range(m_map_rect.position.x, m_map_rect.end.x):
			for y in range(m_map_rect.position.y, m_map_rect.end.y):
				m_update_anchor(Vector2i(x, y), size)

#Clearance
func m_cell_to_index(cell: Vector2i) -> int:
	return (cell.y - m_map_rect.position.y) * m_map_rect.size.x + (cell.x - m_map_rect.position.x)

func m_get_clearance_value(cell: Vector2i) -> int:
	if !m_map_rect.has_point(cell):
		return 0
		
	return m_clearance[m_cell_to_index(cell)]

func m_calculate_clearance_value(cell: Vector2i) -> void:
	var value: int = 0
	
	if m_is_cell_walkable(cell):
		var neighbors: int = m_max_size
		
		neighbors = mini(neighbors, m_get_clearance_value(cell + Vector2i.RIGHT))
		neighbors = mini(neighbors, m_get_clearance_value(cell + Vector2i.DOWN))
		neighbors = mini(neighbors, m_get_clearance_value(cell + Vector2i.ONE))
		
		value = mini(m_max_size, 1 + neighbors)
		
	m_clearance[m_cell_to_index(cell)] = value

func m_update_clearance(top_left: Vector2i, size: int) -> void:
	var from: Vector2i = top_left + Vector2i(size - 1, size - 1)
	var to: Vector2i = top_left - Vector2i(m_max_size - 1, m_max_size - 1)
	
	for x in range(from.x, to.x - 1, -1):
		for y in range(from.y, to.y - 1, -1):
			var check_pos: Vector2i = Vector2i(x, y)
			
			if m_map_rect.has_point(check_pos):
				m_calculate_clearance_value(check_pos)
				m_dirty_cells[check_pos] = true
				
	m_clearance_version += 1

#Space checks
func m_is_cell_valid(cell: Vector2i) -> bool:
	return m_map_rect.has_point(cell) && map.get_cell_source_id(cell) != -1

func m_is_cell_walkable(cell: Vector2i) -> bool:
	if !m_is_cell_valid(cell):
		return false
		
	return !(m_obstacles.has(cell) && m_obstacles[cell].is_any_solid())

func m_has_space_map_only(top_left: Vector2i, size: int) -> bool:
	return m_get_clearance_value(top_left) >= size

func m_has_space_map_and_entity(top_left: Vector2i, size: int, ignore_id: int = -1) -> bool:
	if !m_has_space_map_only(top_left, size):
		return false
		
	for offset in m_offset_caches[size]:
		var other: int = m_solid_entities.get(top_left + offset, -1)
		
		if other != -1 and other != ignore_id:
			return false
			
	return true

#Weight calculation
func m_get_soft_cost(cell: Vector2i) -> float:
	if !m_obstacles.has(cell):
		return 0.0
		
	return m_obstacles[cell].get_soft_cost(obstacle_cost)

func m_get_area_soft_cost(pos: Vector2i, size: int) -> float:
	var result: float = 0.0
	
	for offset in m_offset_caches[size]:
		result = maxf(result, m_get_soft_cost(pos + offset))
		
	return result

#Area update
func m_update_anchor(top_left: Vector2i, size: int) -> void:
	var astar: AStarGrid2D = m_astar_grids[size]
	
	if !astar.is_in_boundsv(top_left):
		return
		
	if !m_has_space_map_only(top_left, size):
		astar.set_point_solid(top_left, true)
		return
		
	astar.set_point_solid(top_left, false)
	astar.set_point_weight_scale(top_left, 1.0 + m_get_area_soft_cost(top_left, size))

func m_set_area_dirty(top_left: Vector2i, size: int) -> void:
	for offset in m_get_offset_caches(size):
		m_dirty_cells[top_left + offset] = true

func m_update_dirty_cells() -> void:
	if m_dirty_cells.is_empty():
		return
		
	for size in supported_sizes:
		var anchors: Dictionary[Vector2i, bool] = {}
		
		for cell in m_dirty_cells:
			for offset in m_offset_caches[size]:
				anchors[cell - offset] = true
				
		for anchor in anchors:
			m_update_anchor(anchor, size)
			
	m_dirty_cells.clear()

#Entity
func m_add_entity_data(id: int) -> void:
	var entity: Structs.Entity = m_entities[id]
	
	m_add_obstacle_data(Enums.ObstacleType.Entity, entity.pos, entity.size, false)
	
	if entity.solid:
		for offset in m_get_offset_caches(entity.size):
			m_solid_entities[entity.pos + offset] = id

func m_remove_entity_data(id: int) -> void:
	var entity: Structs.Entity = m_entities[id]
	
	m_remove_obstacle_data(Enums.ObstacleType.Entity, entity.pos, entity.size, false)
	
	if entity.solid:
		for offset in m_get_offset_caches(entity.size):
			var cell: Vector2i = entity.pos + offset
			
			if m_solid_entities.get(cell, -1) == id:
				m_solid_entities.erase(cell)

func m_is_entity_at(pos: Vector2i) -> bool:
	var type: Enums.ObstacleType = Enums.ObstacleType.Entity
	
	return m_obstacles.has(pos) && m_obstacles[pos].has_type(type, false)

#Obstacle
func m_add_obstacle_data(type: int, top_left: Vector2i, size: int, solid: bool) -> void:
	for offset in m_get_offset_caches(size):
		var check_pos: Vector2i = top_left + offset
		
		if !m_map_rect.has_point(check_pos):
			continue
		
		if !m_obstacles.has(check_pos):
			m_obstacles[check_pos] = Structs.Obstacle.new()
			
		m_obstacles[check_pos].add(type, solid)
		
	m_set_area_dirty(top_left, size)

func m_remove_obstacle_data(type: int, top_left: Vector2i, size: int, solid: bool) -> void:
	for offset in m_get_offset_caches(size):
		var check_pos = top_left + offset
		
		if m_obstacles.has(check_pos):
			m_obstacles[check_pos].remove(type, solid)
			
			if m_obstacles[check_pos].is_completely_empty():
				m_obstacles.erase(check_pos)
				
	m_set_area_dirty(top_left, size)

func m_get_offset_caches(size: int) -> Array[Vector2i]:
	if !m_offset_caches.has(size):
		var offsets: Array[Vector2i] = []
		
		for x in range(size):
			for y in range(size):
				offsets.append(Vector2i(x, y))
				
		m_offset_caches[size] = offsets
		
	return m_offset_caches[size]

#Path
func m_is_cache_valid(cache: Structs.CachedPath, target: Vector2i) -> bool:
	if cache.version != m_clearance_version:
		return false
		
	var diff: Vector2i = (cache.target - target).abs()
	
	return diff.x + diff.y <= path_target_recalculation_offset
