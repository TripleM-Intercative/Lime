extends Node
class_name Deck

const BASE_CARD_SCENE_PATH: String = "res://scenes/basecard.tscn"
const CARD_SCRIPTS_PATH: String = "res://scripts/cards/"
const BASE_Z_INDEX: int = 10

const MAX_SPACING: float = 120.0
const MIN_SPACING: float = 1.0
const MAX_HAND_WIDTH: float = 600.0
const MAX_ROTATION: float = 15
const DECK_HEIGHT: float = 30.0
const DEFAULT_HAND_SIZE: int = 5

var card_blueprint: Resource = preload(BASE_CARD_SCENE_PATH)
var card_pool: Array[GDScript]

var current_deck: Array[CardBase]   
var current_hand: Array[CardBase]   
var discard_pile: Array[CardBase]   
var draw_deck: Array[CardBase]     

var deck_container: HBoxContainer
var viewport_size: Vector2
var card_size: Vector2

var spawn_positions: Dictionary = {}


func _init() -> void:
	set_up_card_pool()


func _ready() -> void:
	viewport_size = get_viewport().get_visible_rect().size
	init_card_deck()


func init_card_deck() -> void:
	create_random_deck(15)
	setup_deck_container()
	draw_cards(DEFAULT_HAND_SIZE)
	get_tree().current_scene.add_child.call_deferred(deck_container)
	organize_hand.call_deferred()


func setup_deck_container() -> void:
	deck_container = HBoxContainer.new()
	deck_container.alignment = BoxContainer.ALIGNMENT_CENTER
	deck_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	deck_container.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	deck_container.offset_top = -card_size.y / 2.0
	deck_container.offset_bottom = card_size.y / 2.0


func creat_new_card(script: GDScript) -> CardBase:
	var new_card: CardBase = card_blueprint.instantiate()
	new_card.set_script(script)
	new_card.card_used.connect(move_card_to_discard_pile)
	new_card.custom_minimum_size = new_card.size
	new_card.offset_transform_enabled = true
	new_card.offset_transform_visual_only = false
	return new_card


func set_up_card_pool() -> void:
	var script_files = DirAccess.get_files_at(CARD_SCRIPTS_PATH)
	for script in script_files:
		if script.ends_with(".uid"):
			continue
		elif script.ends_with("_card.gd"):
			var full_script_path: String = CARD_SCRIPTS_PATH.path_join(script)
			var card_script: GDScript = load(full_script_path)
			if card_script:
				card_pool.append(card_script)


func organize_hand() -> void:
	if current_hand.is_empty():
		return
	
	var old_visual_pos: Dictionary = {}
	for card in current_hand:
		old_visual_pos[card] = spawn_positions.get(card, card.get_visual_global_pos())
	spawn_positions.clear()
	
	var spacing: float = calculate_card_spacing(current_hand.size())
	deck_container.add_theme_constant_override("separation", roundi(spacing - card_size.x))
	deck_container.queue_sort()
	await deck_container.sort_children
	
	var center_index: float = (current_hand.size() - 1) / 2.0
	for index in current_hand.size():
		var card: CardBase = current_hand[index]
		if not is_instance_valid(card):
			continue
	
		var hand_pos: float = 0.0
		if center_index > 0:
			hand_pos = (index - center_index) / center_index
	
		var target_offset: Vector2 = Vector2(0.0, hand_pos * hand_pos * DECK_HEIGHT)
		var target_rotation: float = hand_pos * MAX_ROTATION
	
		card.offset_transform_position = old_visual_pos[card] - card.get_layout_global_pos()
		card.origin_offset = target_offset
		card.origin_rotation = target_rotation
		card.move_card(target_offset, 0.5, false)
		card.rotate_card(target_rotation, 0.5)
	
		card.z_index = BASE_Z_INDEX + index
		card.base_z_index = card.z_index


func create_random_deck(amount: int) -> void:
	for i in range(amount):
		var new_card: CardBase = creat_new_card(card_pool[randi_range(0, card_pool.size() - 1)])
		current_deck.append(new_card)
		draw_deck.append(new_card)
	if not current_deck.is_empty():
		card_size = current_deck[0].size


func add_card_to_hand(card: CardBase) -> void:
	current_hand.append(card)
	spawn_positions[card] = Vector2(0, viewport_size.y)
	deck_container.add_child(card)


func draw_cards(amount: int) -> void:
	for i in range(amount):
		if draw_deck.is_empty():
			break
		add_card_to_hand(draw_deck.pop_back())


func get_random_cards_form_deck(amount: int) -> void:
	if amount > draw_deck.size():
		return
	for i in range(amount):
		var card_index: int = randi_range(0, draw_deck.size() - 1)
		add_card_to_hand(draw_deck.pop_at(card_index))
	organize_hand()


func move_card_to_discard_pile(card: CardBase) -> void:
	var card_index: int = current_hand.find(card)
	if card_index == -1:
		return
	current_hand.remove_at(card_index)
	discard_pile.append(card)
	spawn_positions.erase(card)
	deck_container.remove_child(card)
	if(current_hand.is_empty()):
		draw_cards(DEFAULT_HAND_SIZE)
	organize_hand()


func remove_card_from_deck(card: CardBase) -> void:
	current_deck.erase(card)
	current_hand.erase(card)
	draw_deck.erase(card)
	discard_pile.erase(card)
	spawn_positions.erase(card)
	if card.get_parent() == deck_container:
		deck_container.remove_child(card)
	organize_hand()


func get_random_pos_above_screen(max_distance: float) -> Vector2:
	var x: float = randf_range(0.0, viewport_size.x)
	var y: float = -randf_range(0.0, max_distance)
	return Vector2(x, y)


func calculate_card_spacing(card_count: int) -> float:
	if card_count <= 1:
		return 0.0
	var spacing: float = MAX_HAND_WIDTH / (card_count - 1)
	return clampf(spacing, MIN_SPACING, MAX_SPACING)
