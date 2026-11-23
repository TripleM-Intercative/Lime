@tool
class_name CardDraw
extends CardEffect

@export var draw_amount: int = 0

func _init() -> void:
	card_type = Enums.CardType.Utility

func do_deck_operation(_deck: Deck):
	if !_deck:
		return
	_deck.draw_cards(draw_amount)

func get_description() -> String:
	return "Draw %s cards." % [highlight(draw_amount)]
