class_name LEntity
extends CharacterBody2D

signal died
signal cell_changed(old: Vector2i, new: Vector2i)

@export var health: int:
	set = _set_heath

@export var faction_id: = 0

@onready var path_manager: PathManager = %PathManager
var path_manager_id: int

var map: TileMapLayer

var current_cell := Vector2i(0, 0)
var target_cell := Vector2i(0, 0): set = _set_target_cell

func _ready() -> void:

	map = MapManager.current_map

	current_cell = map.local_to_map(position)
	cell_changed.emit(null, current_cell)
	position = map.map_to_local(current_cell)

	path_manager.entity_cell_changed.connect(_characer_cell_changed)

func _set_heath(val: int) -> void:
	health = val
	if (health <= 0):
		died.emit()

func _set_target_cell(target: Vector2i) -> void:
	target_cell = target
	path_manager.update_pos(path_manager_id, target_cell)

func _characer_cell_changed(_type: LEntity, _old: Vector2i, _new: Vector2i) -> void:
	pass
