extends Node
class_name Deck

const BASE_CARD_SCENE_PATH: String = "res://scenes/basecard.tscn"
const CARD_SCRIPTS_PATH: String = "res://scripts/cards/"

var card_blueprint: Resource = preload(BASE_CARD_SCENE_PATH)
var card_pool: Array[GDScript]
var current_deck: Array[Control]

func _ready() -> void:
	init_card_deck()


func _init() -> void:
	set_up_card_pool()
	

func init_card_deck():
	for card in card_pool:
		get_tree().current_scene.add_child.call_deferred(creat_new_card(card))

func creat_new_card(script: GDScript) -> Control:
	var new_card: Control = card_blueprint.instantiate()
	new_card.set_script(script)
	print(new_card.get_script())
	return new_card

func set_up_card_pool():
	var script_files = DirAccess.get_files_at(CARD_SCRIPTS_PATH)
	for script in script_files:
		if script.ends_with(".uid"):
			continue
		elif script.ends_with("_card.gd"):
			var full_script_path: String = CARD_SCRIPTS_PATH.path_join(script)
			var card_script: GDScript = load(full_script_path)
			if card_script:
				card_pool.append(card_script)
