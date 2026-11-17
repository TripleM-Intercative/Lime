@tool
class_name UtilityEffect
extends CardEffect

@export var amount: int = 2

func _init() -> void:
	card_type = Enums.CardType.Utility 

func apply(target: LEntity) -> void:
	print("Utility: " + str(amount))

func get_description() -> String:
	return "Draw %s cards." % highlight(amount)
