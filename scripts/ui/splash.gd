extends Control

@export var after_splash_scene: PackedScene
@export var screens: Array[Control]
@export var transition_rect: ColorRect

@onready var transition_material = transition_rect.material as ShaderMaterial

var current_screen: int = 0

var screenshot: Texture2D

func _ready() -> void:
	transition_material.set_shader_parameter("size", size)
	
	for screen in screens:
		screen.visible = false
		
	screens[current_screen].visible = true
	
	transition_rect.visible = false
	
	$AnimationPlayer.play("transition")

func make_screenshot() -> void:
	transition_rect.visible = false
	 
	await RenderingServer.frame_post_draw
	screenshot = ImageTexture.create_from_image(get_viewport().get_texture().get_image())
	
	transition_material.set_shader_parameter("screen_texture", screenshot)
	
	transition_material.set_shader_parameter("effect_value", 0.0)
	transition_rect.visible = true
	
	next_screen()

func next_screen() -> void:
	screens[current_screen].visible = false
	
	current_screen += 1
	if current_screen >= screens.size():
		return
		
	screens[current_screen].visible = true

func play_transition() -> void:
	
	make_screenshot()
	
	var tween = create_tween()
	
	transition_material.set_shader_parameter("effect_value", 0.0)
	tween.tween_property(transition_material, "shader_parameter/effect_value", 1.0, 2.0)
	

func load_scene() -> void:
	get_tree().change_scene_to_packed(after_splash_scene)
