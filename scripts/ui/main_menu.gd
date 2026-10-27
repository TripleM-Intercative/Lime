extends Control

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.

func _on_start_pressed():
	$ColorRect2.interpolate()

func _on_options_pressed():
	pass

func _on_credits_pressed():
	pass

func _on_exit_pressed():
	get_tree().quit()


func _on_color_rect_2_resized() -> void:
	$ColorRect2.material.set_shader_parameter("size", size)
