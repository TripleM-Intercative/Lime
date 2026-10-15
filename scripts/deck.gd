extends Node
class_name Deck

const BASE_CARD_SCENE_PATH: String = "res://scenes/basecard.tscn"
const CARD_SCRIPTS_PATH: String = "res://scripts/cards/"
const BASE_Z_INDEX: int = 10

const MAX_SPACING: float = 120.0 
const MIN_SPACING: float = 15.0
const MAX_HAND_WIDTH: float = 600.0
const MAX_ROTATION: float = 15
const DECK_HEIGHT: float = 30.0

var card_blueprint: Resource = preload(BASE_CARD_SCENE_PATH)
var card_pool: Array[GDScript]
var current_deck: Array[CardBase]

func _ready() -> void:
	init_card_deck()


func _init() -> void:
	set_up_card_pool()
	

func init_card_deck() -> void:
	create_random_deck(10)
	
	organize_deck.call_deferred()

func creat_new_card(script: GDScript) -> CardBase:
	var new_card: CardBase = card_blueprint.instantiate()
	new_card.set_script(script)
	new_card.card_used.connect(remove_card_from_deck)
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

func organize_deck() -> void:
	if current_deck.is_empty():
		return
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	var card_size: Vector2 = current_deck[0].size
	var deck_anchor_pos: Vector2 = Vector2((viewport_size.x - card_size.x) / 2.0,viewport_size.y - card_size.y / 2.0)
	var center_index: float = (current_deck.size() - 1) / 2.0
	var spacing: float = calculate_card_spacing(current_deck.size())

	for index in current_deck.size():
		var card: CardBase = current_deck[index]
		var offset: float = spacing * (index - center_index)
		var deck_pos: float = 0.0
		
		deck_pos = (index - center_index) / center_index
		var new_pos: Vector2 = Vector2(deck_anchor_pos.x + offset, deck_anchor_pos.y + deck_pos * deck_pos * DECK_HEIGHT)
		
		if center_index > 0:
			var new_rotation = deck_pos * MAX_ROTATION
			card.origin_rotation = new_rotation
			card.rotate_card(new_rotation, 0.5)
		
		card.move_card(new_pos, 0.5, false)
		
		card.origin_pos = new_pos
		card.z_index = BASE_Z_INDEX + index
		card.base_z_index = card.z_index

func create_random_deck(amount: int) -> void :
	for i in range(amount):
		var new_card: CardBase = creat_new_card(card_pool[randi_range(0, card_pool.size() - 1)])
		current_deck.append(new_card)
		new_card.position = get_random_pos_above_screen(500)
		get_tree().current_scene.add_child.call_deferred(new_card)

func remove_card_from_deck(card: CardBase):
	current_deck.erase(card)
	organize_deck()
	
func get_random_pos_above_screen(max_distance: float) -> Vector2:
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	var x: float = randf_range(0.0, viewport_size.x)
	var y: float = -randf_range(0.0, max_distance)
	return Vector2(x, y)
	
func calculate_card_spacing(card_count: int) -> float:
	if card_count <= 1:
		return 0.0
	var spacing: float = MAX_HAND_WIDTH / (card_count - 1)
	return clampf(spacing, MIN_SPACING, MAX_SPACING)
	
	
	
	
