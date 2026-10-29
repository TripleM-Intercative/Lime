@tool
class_name GuardianEffect
extends CardEffect

@export var amount: float = 0.0

func _init() -> void:
	card_type = Enums.CardType.Guardian

func apply(_card: CardBase) -> void:
	print("Buff: " + str(amount))
