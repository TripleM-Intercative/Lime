extends Node2D

@export var map: TileMapLayer
@onready var mp: Node = %PathfindingManager


func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	var cell_size = Vector2(map.tile_set.tile_size)
	
	for x in range(100):
		for y in range(100):
			var pos = Vector2i(x, y)
			
			if mp.m_astar_grids[2].is_point_solid(pos):
				var world_pos = map.map_to_local(pos)
				var rect = Rect2(world_pos - (cell_size / 2.0), cell_size)
				draw_rect(rect, Color(1, 0, 0, 0.4))
			elif mp.m_astar_grids[2].get_point_weight_scale(pos) > 1.0:
				var world_pos = map.map_to_local(pos)
				var rect = Rect2(world_pos - (cell_size / 2.0), cell_size)
				draw_rect(rect, Color(0, 0, 1, 0.4))
			
