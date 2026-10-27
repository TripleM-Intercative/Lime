@tool
class_name ToolEffect
extends CardEffect

@export var amount: float = 0.0

func _init() -> void:
	card_type = Enums.CardType.Tool

func apply(_card: CardBase) -> void:
	print("Tool: " + str(amount))
