@tool
class_name UtilityEffect
extends CardEffect

@export var amount: float = 0.0

func _init() -> void:
	card_type = Enums.CardType.Utility 

func apply(_card: CardBase) -> void:
	print("Utility: " + str(amount))
