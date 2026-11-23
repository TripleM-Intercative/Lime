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

var entity_size: int = 1

var move_from_cell: Vector2i = Vector2i.ZERO:
	set = _move_from_cell

var health_component: HealthComponent
var gameplay_states: GameplayStates
var is_stunned: bool = false

var move_to_cell: Vector2i = Vector2i.ZERO:
	set = _move_to_cell

var move_from_pos: Vector2 = Vector2.ZERO

var move_to_pos: Vector2 = Vector2.ZERO

var current_cell: Vector2i = Vector2i.ZERO:
	get = _get_current_cell

func _ready() -> void:

	map = MapManager.current_map

	move_from_cell = map.local_to_map(position)
	move_to_cell = move_from_cell

	cell_changed.emit(null, current_cell)
	
	position = move_from_pos

	path_manager.entity_cell_changed.connect(_characer_cell_changed)
	

func _set_heath(val: int) -> void:
	health = val
	if (health <= 0):
		died.emit()

func _characer_cell_changed(_type: LEntity, _old: Vector2i, _new: Vector2i) -> void:
	pass

func _move_from_cell(val: Vector2i) -> void:
	move_from_cell = val
	move_from_pos = map.map_to_local(val)

func _move_to_cell(val: Vector2i) -> void:
	move_to_cell = val
	move_to_pos = map.map_to_local(val)

func _get_current_cell() -> Vector2i:
	return map.local_to_map(position)
