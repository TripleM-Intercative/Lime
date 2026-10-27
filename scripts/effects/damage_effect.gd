@tool
class_name DamageEffect
extends CardEffect

@export var amount: float = 0.0
@export var check: bool = false

func _init() -> void:
	card_type = Enums.CardType.Damage

func apply(_card: CardBase) -> void:
	print("Damage: " + str(amount))
