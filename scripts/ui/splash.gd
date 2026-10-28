extends Control

@export var after_splash_scene : PackedScene
@export var screens : Array[Node]
@export var transition_rect : ColorRect
@export var screen_expose_time : float

@onready var sh_material = transition_rect.material as ShaderMaterial

var current_screen : int = -1

func _ready() -> void:
	sh_material.set_shader_parameter("size", size)

	for screen : Node in screens:
		screen.visible = false

	next_screen()
	pass

func interpolate(reverse: bool = false) -> void:
	var start : float
	var end : float
	if reverse:
		start = 1.0
		end = 0.0
	else:
		start = 0.0
		end = 1.0

	sh_material.set_shader_parameter("effect_value", start)

	var tween := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	tween.tween_property(sh_material, "shader_parameter/effect_value", end, screen_expose_time / 2)

	if reverse:
		tween.tween_callback(next_screen)
	else:
		tween.tween_callback(interpolate.bind(true)).set_delay(screen_expose_time)

func next_screen() -> void:
	if current_screen >= 0 and current_screen < screens.size():
		screens[current_screen].visible = false
	current_screen += 1
	if current_screen < screens.size():
		screens[current_screen].visible = true
		interpolate()
	else:
		get_tree().change_scene_to_packed(after_splash_scene)
