extends Control

@onready var bar: TextureProgressBar = $TextureProgressBar

func _set_heat(new_heat: float) -> bool:
	if new_heat >= 0.0 and new_heat <= 1.0:
		bar.value = new_heat
		return true
	else:
		push_warning("tried setting unnormalised heat value on bar")

	return false

func _modulate_heat(delta: float) -> bool:
	var new_val = bar.value + delta
	if new_val >= 0.0 and new_val <= 1.0:
		bar.value = new_val
		return true
	else:
		push_warning("new heat val exceeds heat meter bounds")

	return false
