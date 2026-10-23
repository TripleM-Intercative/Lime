extends Button
class_name SelectorCell

var pos_in_grid: Vector2
var is_marked: bool
var base_color: Color = self_modulate

func _ready() -> void:
	pressed.connect(on_pressed)
	mouse_entered.connect(_on_mouse_entered)
	var style := StyleBoxFlat.new()
	style.set_corner_radius_all(0)

func _on_mouse_entered() -> void:
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		is_marked = true
		self_modulate = Color.GREEN if is_marked else Color.WHITE
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		is_marked = false
		self_modulate = base_color

func on_pressed() -> void:
	if !is_marked:
		is_marked = true
		self_modulate = Color.GREEN if is_marked else Color.WHITE
	else:
		is_marked = false
		self_modulate = base_color
