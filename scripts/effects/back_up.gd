@tool
class_name BackUp
extends CardEffect

@export var amount: int

func _init() -> void:
	card_type = Enums.CardType.Utility

func do_deck_operation(_deck: Deck):
	if !_deck:
		return
	_deck.return_cards_from_discard(amount)

func get_description() -> String:
	return "Returns %s cards from the Graveyard." % [highlight(amount)]
