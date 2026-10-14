extends Node

const BASE_CARD_SCENE_PATH: String = "res://scenes/basecard.tscn"
const CARD_SCRIPTS_PATH: String = "res://scripts/cards/"

var card_blueprint: Resource = preload(BASE_CARD_SCENE_PATH)

var current_deck: Array[Control]
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	init_card_deck()

func init_card_deck():
	var script_files = DirAccess.get_files_at(CARD_SCRIPTS_PATH)
	for script in script_files:
		if script.ends_with(".uid"):
			continue
		elif script.ends_with("_card.gd"):
			var full_script_path: String = CARD_SCRIPTS_PATH.path_join(script)
			var card_script: GDScript = load(full_script_path)
			if card_script:
				var new_card: Control = creat_new_card(card_script)
				current_deck.append(new_card)
				get_tree().current_scene.add_child.call_deferred(new_card)

func creat_new_card(script: GDScript) -> Control:
	var new_card: Control = card_blueprint.instantiate()
	new_card.set_script(script)
	print(new_card.get_script())
	return new_card
