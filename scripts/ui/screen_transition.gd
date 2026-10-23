@tool
extends ColorRect

func _ready() -> void:
	material.set_shader_parameter("size", size)
	
	interpolate()

func interpolate() -> void:
	material.set_shader_parameter("effect_value", 0.0)
	
	var tween := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT);
	tween.tween_property(material, "shader_parameter/effect_value", 1.0, 2.0)
