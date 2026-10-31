extends TextureRect

const MAX_POINTS: int = 100
const RIBBON_WIDTH_RATIO: float = 1.0

@onready var ribbon: Line2D = $Line2D
var timer: float = 0.0

func _ready() -> void:
	ribbon.top_level = true
	ribbon.z_as_relative = false
	ribbon.z_index = 8
	ribbon.global_transform = Transform2D.IDENTITY
	print(scale)

func _get_drawn_rect() -> Rect2:
	var tex_size: Vector2 = texture.get_size()
	var fit: float = min(size.x / tex_size.x, size.y / tex_size.y)
	var drawn: Vector2 = tex_size * fit
	return Rect2((size - drawn) / 2.0, drawn)

func _process(delta: float) -> void:
	if not is_visible_in_tree():
		if ribbon.get_point_count() > 0:
			ribbon.clear_points()
		return
	
	var drawn: Rect2 = _get_drawn_rect()
	var xf: Transform2D = get_global_transform()
	
	ribbon.width = drawn.size.x * xf.get_scale().x * RIBBON_WIDTH_RATIO
	var tail: Vector2 = xf * Vector2(drawn.get_center().x, drawn.end.y)
	ribbon.add_point(tail, 0)
	if ribbon.get_point_count() > MAX_POINTS:
		ribbon.remove_point(ribbon.get_point_count() - 1)
