extends Control

class_name CardBase

const VIEWPORT_ACTIVATION_MARGIN: float = 0.7
const ACTIVATION_SCALE: Vector2 = Vector2(0.1, 0.1)
const ACTIVATION_SCALE_DURATION: float = 0.2
const SHAKE_RETURN_DURATION: float = 0.1
const ACTIVE_MOUSE_OFFSET: Vector2 = Vector2(16, 16)
const ANCHOR_BLEND_DURATION: float = 0.1

var card_data: BaseCardRes
@onready var card_image_rect: TextureRect = $MarginContainer/VBoxContainer/CardImage
@onready var heat_icon_rect: TextureRect = $MarginContainer/VBoxContainer/HeatInfo/HeatIcon
@onready var heat_amount_label: Label = $MarginContainer/VBoxContainer/HeatInfo/HeatAmount

@onready var card_name_label: Label = $MarginContainer/VBoxContainer/CardName
@onready var card_description_label: Label = $MarginContainer/VBoxContainer/CardDescription

signal card_used(card: CardBase)
signal returned_card_to_hand(card: CardBase)

#Anims
var scale_tween: Tween
var move_tween: Tween
var rotation_tween: Tween
var shake_tween: Tween
var anchor_tween: Tween

var viewport_size: Vector2
var origin_offset: Vector2 = Vector2.ZERO
var origin_rotation: float
var base_z_index: int
var is_clicked: bool = false
var is_held: bool = false
var mouse_velocity: Vector2
var can_activate: bool = false
var target_cells: Array[Vector2i]
var anchor_blend: float = 0.0

func _ready() -> void:
	if card_data:
		init_card_ui()
	viewport_size = get_viewport().get_visible_rect().size

func _process(delta: float) -> void:
	if is_clicked:
		self.offset_transform_position = calculat_card_target_pos()
		snap_to_mouse()
		rotate_on_movment()
		var in_range: bool = is_in_activation_range()
		if in_range != can_activate:
			can_activate = in_range
			if can_activate:
				scale_card(Vector2(0.3, 0.3), 0.1)
				blend_anchor(1.0)
			else:
				scale_card(Vector2.ONE, 0.1)
				blend_anchor(0.0)
	if is_held:
		if can_activate:
			MapManager.highlight_cells(MapManager.get_cells_in_range(target_cells))
		else:
			MapManager.clear_highlight()

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion && is_clicked:
		mouse_velocity = Utils.get_mouse_velocity(event, get_process_delta_time())


func init_card_ui() -> void:
	card_image_rect.texture = card_data.card_image
	card_name_label.text = card_data.card_name
	card_description_label.text = "Sehr tolle Karte, mit der man ganz viel Spaß hat!!"
	target_cells = card_data.target_cells

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
	if shake_tween:
		shake_tween.kill()
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
	scale_tween.tween_property(self, "offset_transform_scale", target, duration)

func move_card(target: Vector2, duration: float, clicked: bool) -> void:
	if move_tween:
		move_tween.kill()
	if shake_tween:
		shake_tween.kill()
	move_tween = create_tween()
	move_tween.set_ease(Tween.EASE_IN_OUT)
	move_tween.set_trans(Tween.TRANS_SINE)
	move_tween.tween_property(self, "offset_transform_position", target, duration)

	if clicked:
		move_tween.finished.connect(set_is_clicked.bind(true))
	else:
		set_is_clicked(false)

func rotate_card(target: float, duration: float) -> void:
	if rotation_tween:
		rotation_tween.kill()
	rotation_tween = create_tween()
	rotation_tween.set_ease(Tween.EASE_IN_OUT)
	rotation_tween.set_trans(Tween.TRANS_SINE)
	rotation_tween.tween_property(self, "offset_transform_rotation", deg_to_rad(target), duration)

func shake_card(strength: float = 10.0, duration: float = 0.3, steps: int = 8) -> void:
	if is_clicked:
		return
	
	var was_moving: bool = move_tween != null and move_tween.is_running()
	if move_tween:
		move_tween.kill()
	if shake_tween:
		shake_tween.kill()
	
	shake_tween = create_tween()
	if was_moving:
		shake_tween.tween_property(self, "offset_transform_position", origin_offset, SHAKE_RETURN_DURATION)
	else:
		offset_transform_position = origin_offset
	
	var step_time: float = duration / steps
	for i in steps:
		var falloff: float = 1.0 - float(i) / steps
		var offset: Vector2 = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * strength * falloff
		shake_tween.tween_property(self, "offset_transform_position", origin_offset + offset, step_time)
	
	shake_tween.tween_property(self, "offset_transform_position", origin_offset, step_time)

func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		is_held = true
		var target = calculat_card_target_pos()
		move_card(target, 0.1, true)

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		if can_activate and is_clicked:
			is_held = false
			use_card()
		else:
			return_to_hand()

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		if is_clicked:
			return_to_hand()

func return_to_hand() -> void:
	if not is_held:
		return
	is_held = false
	MapManager.clear_highlight()
	move_card(origin_offset, 0.1, false)
	rotate_card(origin_rotation, 0.1)
	scale_card(Vector2.ONE, 0.3)
	self.z_index = base_z_index
	returned_card_to_hand.emit(self)

func calculat_card_target_pos() -> Vector2:
	var target_global: Vector2 = get_global_mouse_position() - self.size / 2.0
	return target_global - get_layout_global_pos()

func snap_to_mouse() -> void:
	var local_anchor: Vector2 = (self.size / 2.0).lerp(Vector2.ZERO, anchor_blend)
	var actual_anchor: Vector2 = get_global_transform() * local_anchor
	var target: Vector2 = get_global_mouse_position() + ACTIVE_MOUSE_OFFSET * anchor_blend
	self.offset_transform_position += target - actual_anchor

func blend_anchor(target: float) -> void:
	if anchor_tween:
		anchor_tween.kill()
	anchor_tween = create_tween()
	anchor_tween.set_ease(Tween.EASE_IN_OUT)
	anchor_tween.set_trans(Tween.TRANS_SINE)
	anchor_tween.tween_property(self, "anchor_blend", target, ANCHOR_BLEND_DURATION)

func get_layout_global_pos() -> Vector2:
	var parent_control: Control = get_parent() as Control
	if parent_control:
		return parent_control.global_position + self.position
	return self.position

func get_visual_global_pos() -> Vector2:
	return get_layout_global_pos() + self.offset_transform_position

func set_is_clicked(clicked: bool):
	is_clicked = clicked
	if is_clicked == false:
		can_activate = false
		blend_anchor(0.0)

func is_in_activation_range() -> bool :
	viewport_size = get_viewport().get_visible_rect().size
	var activation_line: float = viewport_size.y * VIEWPORT_ACTIVATION_MARGIN
	return get_viewport().get_mouse_position().y < activation_line

func use_card():
	MapManager.clear_highlight()
	for effect: CardEffect in card_data.effects:
		effect.apply(self)
	card_used.emit(self)
	print("Used: " + card_data.card_name)
	#self.queue_free()

func reset_card():
	is_clicked = false
	is_held = false
	if scale_tween:
		scale_tween.kill()
	if shake_tween:
		shake_tween.kill()
	if anchor_tween:
		anchor_tween.kill()
	anchor_blend = 0.0
	scale = Vector2.ONE
	offset_transform_scale = Vector2.ONE
	offset_transform_position = Vector2.ZERO
	offset_transform_rotation = 0.0

func rotate_on_movment() -> void:
	var vel_x: float = mouse_velocity.x
	var filtered: float = signf(vel_x) * maxf(absf(vel_x) - 100, 0.0)
	
	rotate_card(clampf(filtered * 0.02, -90, 90), 0.1)
	mouse_velocity = Vector2.ZERO
