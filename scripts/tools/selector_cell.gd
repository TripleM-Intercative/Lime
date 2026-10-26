extends Button
class_name SelectorCell

const CELL_SIZE: Vector2 = Vector2(32, 32)
const COLOR_EMPTY: Color = Color(0.25, 0.25, 0.25)
const COLOR_MARKED: Color = Color(0.2, 0.75, 0.2)
const COLOR_MID: Color = Color.ORANGE
const COLOR_BORDER: Color = Color(0.12, 0.12, 0.12)
const MID_BORDER_WIDTH: int = 4

var pos_in_grid: Vector2
var is_marked: bool = false
var is_mid: bool = false:
	set(value):
		is_mid = value
		_update_style()

var _style: StyleBoxFlat = StyleBoxFlat.new()
var _hover_style: StyleBoxFlat = StyleBoxFlat.new()

func _init() -> void:
	custom_minimum_size = CELL_SIZE
	size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	focus_mode = Control.FOCUS_NONE
	
	for style in [_style, _hover_style]:
		style.set_corner_radius_all(0)
		style.set_content_margin_all(0)
		style.anti_aliasing = false
	
	add_theme_stylebox_override("normal", _style)
	add_theme_stylebox_override("pressed", _style)
	add_theme_stylebox_override("disabled", _style)
	add_theme_stylebox_override("hover", _hover_style)
	add_theme_stylebox_override("hover_pressed", _hover_style)
	add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	
	pressed.connect(_on_pressed)
	mouse_entered.connect(_paint_from_mouse)
	mouse_exited.connect(_paint_from_mouse)
	_update_style()

func set_marked(value: bool) -> void:
	is_marked = value
	_update_style()

func _paint_from_mouse() -> void:
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		set_marked(true)
	elif Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		set_marked(false)

func _on_pressed() -> void:
	set_marked(!is_marked)

func _update_style() -> void:
	var fill: Color = COLOR_EMPTY
	if is_marked:
		fill = COLOR_MARKED
	elif is_mid:
		fill = COLOR_MID
	
	var border_color: Color = COLOR_MID if is_mid else COLOR_BORDER
	var border_width: int = MID_BORDER_WIDTH if is_mid else 1
	
	for style in [_style, _hover_style]:
		style.bg_color = fill
		style.border_color = border_color
		style.set_border_width_all(border_width)
	_hover_style.bg_color = fill.lightened(0.25)
