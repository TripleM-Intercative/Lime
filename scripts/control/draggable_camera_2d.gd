extends Camera2D

var dragging: bool = false

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:

		match event.button_index:
			MOUSE_BUTTON_MIDDLE:
				dragging = !event.is_released()
			MOUSE_BUTTON_WHEEL_UP:
				zoom += Vector2(0.01, 0.01)
			MOUSE_BUTTON_WHEEL_DOWN:
				if zoom > Vector2(0.1, 0.1):
					zoom -= Vector2(0.01, 0.01)

	if event is InputEventMouseMotion and dragging:
		offset -= event.relative / zoom
		pass
