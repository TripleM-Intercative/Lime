class_name CardVisual
extends Control

signal on_card_gui_input(event: InputEvent)
signal on_card_mouse_entered()
signal on_card_mouse_exited()
signal follow_mouse_changed(is_following: bool)

const SHAKE_RETURN_DURATION: float = 0.1
const ACTIVE_MOUSE_OFFSET: Vector2 = Vector2(16, 16)
const ANCHOR_BLEND_DURATION: float = 0.1
const ACTIVATION_PREVIEW_SCALE: Vector2 = Vector2(0.3, 0.3)

var card_res: BaseCardRes
@onready var card_image_rect: TextureRect = $MarginContainer/VBoxContainer/CardImage
@onready var heat_icon_rect: TextureRect = $MarginContainer/VBoxContainer/HeatInfo/HeatIcon
@onready var heat_amount_label: Label = $MarginContainer/VBoxContainer/HeatInfo/HeatAmount
@onready var card_name_label: Label = $MarginContainer/VBoxContainer/CardName
@onready var card_description_label: RichTextLabel = $MarginContainer/VBoxContainer/CardDescription

#Anims
var scale_tween: Tween
var move_tween: Tween
var rotation_tween: Tween
var shake_tween: Tween
var anchor_tween: Tween

var viewport_size: Vector2
var origin_offset: Vector2 = Vector2.ZERO
var origin_rotation: float
var is_clicked: bool = false
var mouse_velocity: Vector2
var anchor_blend: float = 0.0


func _ready() -> void:
	viewport_size = get_viewport().get_visible_rect().size

func _process(_delta: float) -> void:
	if is_clicked:
		self.offset_transform_position = calculat_card_target_pos()
		snap_to_mouse()
		rotate_on_movment()

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion && is_clicked:
		mouse_velocity = Utils.get_mouse_velocity(event, get_process_delta_time())

func init_card_visual(card_data: BaseCardRes) -> void:
	card_res = card_data
	init_card_ui()

func init_card_ui() -> void:
	card_image_rect.texture = card_res.card_image
	card_image_rect.self_modulate = Utils.RARITY_COLOR.get(card_res.rarity, Color.WHITE)
	card_name_label.text = card_res.card_name
	card_description_label.text = create_card_description()
	
	match card_res.heat_cost:
		Enums.HeatCost.NoCost:
			heat_icon_rect.texture = load("res://assets/default_card_image.png")
		Enums.HeatCost.Increase:
			heat_icon_rect.texture = load("res://assets/images/test_heat_icon.png")
		Enums.HeatCost.Cooldown:
			heat_icon_rect.texture = load("res://assets/images/test_cooldown_icon.png")
	
	heat_amount_label.text = str(card_res.heat_cost_amount)

func create_card_description() -> String:
	var lines: PackedStringArray = []
	for effect: CardEffect in card_res.effects:
		var text: String = effect.get_description()
		if text != "":
			lines.append(text)
	return "\n".join(lines)

func _on_gui_input(event: InputEvent) -> void:
	on_card_gui_input.emit(event)

func _on_mouse_entered() -> void:
	on_card_mouse_entered.emit()

func _on_mouse_exited() -> void:
	on_card_mouse_exited.emit()

func hover_enter() -> void:
	if rotation_tween:
		rotation_tween.kill()
	if move_tween:
		move_tween.kill()
	if shake_tween:
		shake_tween.kill()
	var target_global_y: float = viewport_size.y - self.size.y
	self.offset_transform_position.y = target_global_y - get_layout_global_pos().y
	self.offset_transform_rotation = 0.0

func hover_exit() -> void:
	self.offset_transform_position.y = origin_offset.y
	self.offset_transform_rotation = deg_to_rad(origin_rotation)

func start_follow_mouse() -> void:
	move_card(calculat_card_target_pos(), 0.1, true)

func return_to_origin() -> void:
	move_card(origin_offset, 0.1, false)
	rotate_card(origin_rotation, 0.1)
	scale_card(Vector2.ONE, 0.3)

func set_activation_preview(active: bool) -> void:
	if active:
		scale_card(ACTIVATION_PREVIEW_SCALE, 0.1)
		blend_anchor(1.0)
	else:
		scale_card(Vector2.ONE, 0.1)
		blend_anchor(0.0)

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

	var was_moving: bool = move_tween != null && move_tween.is_running()
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

func blend_anchor(target: float) -> void:
	if anchor_tween:
		anchor_tween.kill()
	anchor_tween = create_tween()
	anchor_tween.set_ease(Tween.EASE_IN_OUT)
	anchor_tween.set_trans(Tween.TRANS_SINE)
	anchor_tween.tween_property(self, "anchor_blend", target, ANCHOR_BLEND_DURATION)

func set_is_clicked(clicked: bool) -> void:
	is_clicked = clicked
	if is_clicked == false:
		blend_anchor(0.0)
	follow_mouse_changed.emit(is_clicked)

func calculat_card_target_pos() -> Vector2:
	var target_global: Vector2 = get_global_mouse_position() - self.size / 2.0
	return target_global - get_layout_global_pos()

func snap_to_mouse() -> void:
	var local_anchor: Vector2 = (self.size / 2.0).lerp(Vector2.ZERO, anchor_blend)
	var actual_anchor: Vector2 = get_global_transform() * local_anchor
	var target: Vector2 = get_global_mouse_position() + ACTIVE_MOUSE_OFFSET * anchor_blend
	self.offset_transform_position += target - actual_anchor

func rotate_on_movment() -> void:
	var vel_x: float = mouse_velocity.x
	var filtered: float = signf(vel_x) * maxf(absf(vel_x) - 100, 0.0)
	rotate_card(clampf(filtered * 0.02, -90, 90), 0.1)
	mouse_velocity = Vector2.ZERO

func get_layout_global_pos() -> Vector2:
	var parent_control: Control = get_parent() as Control
	if parent_control:
		return parent_control.global_position + self.position
	return self.position

func get_visual_global_pos() -> Vector2:
	return get_layout_global_pos() + self.offset_transform_position

func reset_visual() -> void:
	is_clicked = false
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
