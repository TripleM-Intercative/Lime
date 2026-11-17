@tool
class_name DamageEffect
extends CardEffect

@export var damage_amount: float = 0.0

func _init() -> void:
	card_type = Enums.CardType.Damage

func apply(target: LEntity) -> void:
	if is_instance_valid(target.health_component):
		target.health_component.apply_damage(damage_amount)

func get_description() -> String:
	return "Deal %s damage." % highlight(damage_amount)
