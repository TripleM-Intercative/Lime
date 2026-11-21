@tool
class_name ShutDown
extends CardEffect

func _init() -> void:
	card_type = Enums.CardType.Damage

func apply(target: LEntity) -> void:
	if !is_instance_valid(target.health_component):
		return
	target.health_component.kill()

func get_description() -> String:
	return "Kills target instantly"
