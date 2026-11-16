@tool
class_name DamageEffect
extends CardEffect

@export var damage_amount: float = 0.0

func _init() -> void:
	card_type = Enums.CardType.Damage

func apply(_card: CardBase) -> void:
	print("Damage: " + str(damage_amount))

func get_description() -> String:
	return "Deal %s damage." % highlight(damage_amount)
