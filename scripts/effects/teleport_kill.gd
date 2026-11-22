@tool
class_name TeleportKill
extends CardEffect

var path_manager: PathManager

func _init() -> void:
	card_type = Enums.CardType.Utility

func apply(_target: LEntity) -> void:
	pass

func get_description() -> String:
	return "Teleports to a target position and destroys the entity currently occupying that position."
