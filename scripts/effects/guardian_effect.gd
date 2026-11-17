@tool
class_name GuardianEffect
extends CardEffect

@export var amount: float = 0.0

func _init() -> void:
	card_type = Enums.CardType.Guardian

func apply(target: LEntity) -> void:
	print("Buff: " + str(amount))

func get_description() -> String:
	return "Spawn Guardian."
