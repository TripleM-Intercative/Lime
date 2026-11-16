@tool
class_name HealEffect
extends CardEffect

@export var amount: float = 0.0

func _init() -> void:
	card_type = Enums.CardType.Heal

func apply(_card: CardBase) -> void:
	print("Heal: " + str(amount))

func get_description() -> String:
	return "Heal %s HP." % highlight(amount)
