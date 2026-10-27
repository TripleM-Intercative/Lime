extends CharacterBody2D

enum Direction {
	UP = 0,
	DOWN,
	LEFT,
	RIGHT
}

@export var map : TileMapLayer
@export var interp_speed_mult: float

var current_pos: Vector2
var target_pos: Vector2
var lerp_time: float
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	assert(map, "No map provided for player")

	var first_cell : Vector2i = map.get_used_cells().front()
	position = map.map_to_local(first_cell)
	print(global_position)
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:

	pass

func _unhandled_input(event: InputEvent) -> void:
	handel_movement(event)

	pass

func action_for_event(event: InputEvent):
	for action in InputMap.get_actions():
		if event.is_action_pressed(action):
			return action
	return null


func handel_movement(event: InputEvent):
	if position != current_pos:
		return

	match action_for_event(event):
		"player_up":
			move(Direction.UP)
		"player_down":
			move(Direction.DOWN)
		"player_left":
			move(Direction.LEFT)
		"player_right":
			move(Direction.RIGHT)
	pass

func move(dir: Direction):

	var current_cell: Vector2i = map.local_to_map(position)
	print("Curren cell: ", current_cell)
	var next_cell: Vector2i

	match dir:
		Direction.UP:
			next_cell = current_cell + Vector2i(0, -1)
		Direction.DOWN:
			next_cell = current_cell + Vector2i(0, 1)
		Direction.LEFT:
			next_cell = current_cell + Vector2i(-1, 0)
		Direction.RIGHT:
			next_cell = current_cell + Vector2i(1, 0)

	if map.get_cell_source_id(next_cell) != -1:
		new_target_pos(map.map_to_local(next_cell))

	pass

func _physics_process(delta: float) -> void:
	if position != target_pos:
		lerp_time += delta * interp_speed_mult
		position = current_pos.lerp(target_pos, lerp_time)
	elif position == target_pos:
		current_pos = position

	pass

func new_target_pos(pos: Vector2):
	target_pos = pos
	lerp_time = 0
