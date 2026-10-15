extends Control

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.

func _on_start_pressed():
	get_tree().change_scene_to_file("res://scenes/ui/test_map.tscn")
	pass

func _on_options_pressed():
	pass

func _on_credits_pressed():
	pass

func _on_exit_pressed():
	get_tree().quit()
