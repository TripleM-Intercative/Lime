extends Control

class_name CardBase

var card_data: BaseCardRes
@onready var card_image_rect: TextureRect = $MarginContainer/VBoxContainer/CardImage
@onready var heat_icon_rect: TextureRect = $MarginContainer/VBoxContainer/HeatInfo/HeatIcon
@onready var heat_amount_label: Label = $MarginContainer/VBoxContainer/HeatInfo/HeatAmount

@onready var card_name_label: Label = $MarginContainer/VBoxContainer/CardName
@onready var card_description_label: Label = $MarginContainer/VBoxContainer/CardDescription

signal card_used(card: CardBase)

#Anims
var scale_tween: Tween
var move_tween: Tween
var rotation_tween: Tween

var viewport_size: Vector2
var origin_offset: Vector2 = Vector2.ZERO
var origin_rotation: float
var base_z_index: int
var is_clicked: bool = false

func _ready() -> void:
	if card_data:
		init_card_ui()
	viewport_size = get_viewport().get_visible_rect().size

func _process(delta: float) -> void:
	if is_clicked:
		self.offset_transform_position = calculat_card_target_pos()

func init_card_ui() -> void:
	card_image_rect.texture = card_data.card_image
	card_name_label.text = card_data.card_name
	card_description_label.text = "Sehr tolle Karte, mit der man ganz viel Spaß hat!!"

	match card_data.heat_cost:
		Enums.HeatCost.NoCost:
			heat_icon_rect.texture = load("res://assets/default_card_image.png")
		Enums.HeatCost.Increase:
			heat_icon_rect.texture = load("res://assets/images/test_heat_icon.png")
		Enums.HeatCost.Cooldown:
			heat_icon_rect.texture = load("res://assets/images/test_cooldown_icon.png")

	heat_amount_label.text = str(card_data.heat_cost_amount)
	base_z_index = self.z_index

func _on_mouse_entered() -> void:
	if rotation_tween:
		rotation_tween.kill()
	if move_tween:
		move_tween.kill()
	var target_global_y: float = viewport_size.y - self.size.y
	self.offset_transform_position.y = target_global_y - get_layout_global_pos().y
	self.offset_transform_rotation = 0.0
	self.z_index = 999


func _on_mouse_exited() -> void:
	self.offset_transform_position.y = origin_offset.y
	self.offset_transform_rotation = deg_to_rad(origin_rotation)
	self.z_index = base_z_index

func scale_card(target: Vector2, duration: float) -> void:
	if scale_tween:
		scale_tween.kill()
	scale_tween = create_tween()
	scale_tween.set_ease(Tween.EASE_IN_OUT)
	scale_tween.set_trans(Tween.TRANS_SINE)
	scale_tween.tween_property(self, "scale", target, duration)

func move_card(target: Vector2, duration: float, clicked: bool) -> void:
	if move_tween:
		move_tween.kill()
	move_tween = create_tween()
	move_tween.set_ease(Tween.EASE_IN_OUT)
	move_tween.set_trans(Tween.TRANS_SINE)
	move_tween.tween_property(self, "offset_transform_position", target, duration)

	move_tween.finished.connect(set_is_clicked.bind(clicked))

func rotate_card(target: float, duration: float) -> void:
	if rotation_tween:
		rotation_tween.kill()
	rotation_tween = create_tween()
	rotation_tween.set_ease(Tween.EASE_IN_OUT)
	rotation_tween.set_trans(Tween.TRANS_SINE)
	rotation_tween.tween_property(self, "offset_transform_rotation", deg_to_rad(target), duration)

func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var target = calculat_card_target_pos()
		move_card(target, 0.1, true)

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		if is_in_activation_range() and is_clicked:
			use_card()
		else:
			move_card(origin_offset, 0.1, false)
			scale_card(Vector2(1,1), 0.3)
			self.z_index = base_z_index

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		if is_clicked:
			move_card(origin_offset, 0.1, false)
			self.z_index = base_z_index

func calculat_card_target_pos() -> Vector2:
	var target_global: Vector2 = get_global_mouse_position() - self.size / 2
	return target_global - get_layout_global_pos()

func get_layout_global_pos() -> Vector2:
	var parent_control: Control = get_parent() as Control
	if parent_control:
		return parent_control.global_position + self.position
	return self.position

func get_visual_global_pos() -> Vector2:
	return get_layout_global_pos() + self.offset_transform_position

func set_is_clicked(clicked: bool):
	is_clicked = clicked

func is_in_activation_range() -> bool :
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	var activation_line: float = viewport_size.y * 0.7
	if get_viewport().get_mouse_position().y < activation_line:
		return true
	else:
		return false

func use_card():
	card_used.emit(self)
	print("Used: " + card_data.card_name)
	#self.queue_free()

func reset_card():
	is_clicked = false
	scale = Vector2.ONE
	offset_transform_position = Vector2.ZERO
	offset_transform_rotation = 0.0
