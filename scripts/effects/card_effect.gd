@tool
class_name CardEffect
extends Resource

var card_type: Enums.CardType = Enums.CardType.None

func apply(_card: CardBase) -> void:
	push_warning("no effect placed")
