extends Control

class_name CardBase

const CARD_VISUAL_SCENE: PackedScene = preload("res://scenes/ui/basecard.tscn")
const VIEWPORT_ACTIVATION_MARGIN: float = 0.7

signal card_used(card: CardBase)
signal returned_card_to_hand(card: CardBase)

var card_data: BaseCardRes
var card_visual: CardVisual

var base_z_index: int
var is_held: bool = false
var can_activate: bool = false
var target_cells: Array[Vector2i]

var gamble_active: bool = false

func _init() -> void:
	card_visual = CARD_VISUAL_SCENE.instantiate() as CardVisual
	card_visual.offset_transform_enabled = true
	card_visual.offset_transform_visual_only = false
	add_child(card_visual)
	size = card_visual.size
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	card_visual.on_card_gui_input.connect(_on_visual_gui_input)
	card_visual.on_card_mouse_entered.connect(_on_visual_mouse_entered)
	card_visual.on_card_mouse_exited.connect(_on_visual_mouse_exited)
	card_visual.follow_mouse_changed.connect(_on_follow_mouse_changed)

func _ready() -> void:
	if card_data:
		init_card()
	if card_data.range_type == Enums.RangeType.SingelTarget:
		target_cells.clear()
		target_cells.append(Vector2i.ZERO)
	for effect in card_data.effects:
		effect.init_effect(self)

func _process(_delta: float) -> void:
	if card_visual.is_clicked:
		var in_range: bool = is_in_activation_range()
		if in_range != can_activate:
			can_activate = in_range
			card_visual.set_activation_preview(can_activate)
	if is_held:
		if can_activate:
			MapManager.highlight_cells(MapManager.get_cells_in_range(target_cells))
		else:
			MapManager.clear_highlight()


func init_card() -> void:
	card_visual.init_card_visual(card_data)
	target_cells = card_data.target_cells
	base_z_index = self.z_index


func _on_visual_mouse_entered() -> void:
	card_visual.hover_enter()
	self.z_index = 999

func _on_visual_mouse_exited() -> void:
	card_visual.hover_exit()
	self.z_index = base_z_index

func _on_follow_mouse_changed(is_following: bool) -> void:
	if !is_following:
		can_activate = false

func _on_visual_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton && event.button_index == MOUSE_BUTTON_LEFT && event.pressed:
		is_held = true
		card_visual.start_follow_mouse()
	
	if event is InputEventMouseButton && event.button_index == MOUSE_BUTTON_LEFT && !event.pressed:
		if can_activate && card_visual.is_clicked:
			is_held = false
			use_card()
		else:
			return_to_hand()
	
	if event is InputEventMouseButton && event.button_index == MOUSE_BUTTON_RIGHT && event.pressed:
		if card_visual.is_clicked:
			return_to_hand()

func return_to_hand() -> void:
	if !is_held:
		return
	is_held = false
	MapManager.clear_highlight()
	card_visual.return_to_origin()
	self.z_index = base_z_index
	returned_card_to_hand.emit(self)

func is_in_activation_range() -> bool:
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	var activation_line: float = viewport_size.y * VIEWPORT_ACTIVATION_MARGIN
	return get_viewport().get_mouse_position().y < activation_line

func use_card() -> void:
	var cells: Array[Vector2i] = MapManager.get_cells_in_range(target_cells)
	var targets: Array[LEntity] = MapManager.get_entities_in_cells(cells)
	MapManager.clear_highlight()
	
	if !gamble_active:
		apply_card_effects(targets)
	else:
		if Utils.chance(0.5):
			apply_card_effects(targets)
			apply_card_effects(targets)
			print("luckie you")
		else:
			print("no luck")
	
	card_used.emit(self)

func reset_card() -> void:
	is_held = false
	card_visual.reset_visual()

func apply_card_effects(targets: Array[LEntity]) -> void:
	for target: LEntity in targets:
		for effect: CardEffect in card_data.effects:
			effect.apply(target)
