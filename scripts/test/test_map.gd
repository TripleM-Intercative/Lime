@tool
extends TileMapLayer

@export var noise_texture : NoiseTexture2D
@export var map_width : int
@export var map_height : int
@export var noise_threshold : float

@export_tool_button("Generate", "Callable") var gen_map_button = gen_map

func _enter_tree() -> void:
	if !Engine.is_editor_hint():
		MapManager.register_map(self)

func _ready() -> void:
	gen_map()
	MapManager.register_map(map)

func gen_map():
	clear()
	var noise = noise_texture.noise

	for x in range(map_width):
		for y in range(map_height):
			var noise_val = abs(noise.get_noise_2d(x,y))
			if (noise_val > noise_threshold):
				continue
			if (noise_val < noise_threshold):
				set_cell(Vector2i(x,y), 0, Vector2i(1,4))

	pass
