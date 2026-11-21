@tool
class_name Reboot
extends CardEffect

func _init() -> void:
	card_type = Enums.CardType.Defense

func apply(target: LEntity) -> void:
	if is_instance_valid(target.health_component):
		target.health_component.set_reviving(true)

func get_description() -> String:
	return "Target is revived upon their next death."
