@tool
class_name BeaconEffect
extends CardEffect

@export var amount: float = 0.0
@export var range: float = 0.0

func _init() -> void:
	card_type = Enums.CardType.Beacon

func apply(_card: CardBase) -> void:
	print("Aura: " + str(amount))

func get_description() -> String:
	return "Applies aura of strength %s in range %s." % [highlight(amount), highlight(range, Color.WHITE)]
