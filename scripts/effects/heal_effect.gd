@tool
class_name HealEffect
extends CardEffect

@export var heal_amount: float = 0.0

func _init() -> void:
	card_type = Enums.CardType.Defense

func apply(target: LEntity) -> void:
	if is_instance_valid(target.health_component):
		target.health_component.apply_heal(heal_amount)

func get_description() -> String:
	return "Heal %s HP." % highlight(heal_amount)
