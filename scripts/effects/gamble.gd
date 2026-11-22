@tool
class_name Gamble
extends CardEffect

func _init() -> void:
	card_type = Enums.CardType.Utility

func apply(_target: LEntity) -> void:
	pass

func get_description() -> String:
	return "This card has a 50% chance to be replayed for free or not played at all."

func init_effect(_card: CardBase):
	_card.gamble_active = true
