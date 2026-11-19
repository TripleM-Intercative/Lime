@tool
class_name Stun
extends CardEffect

@export var duration: float = 0.0

func _init() -> void:
	card_type = Enums.CardType.Defense

func apply(target: LEntity) -> void:
	if is_instance_valid(target.gameplay_states):
		target.gameplay_states.apply_stun(duration)

func get_description() -> String:
	return "Stuns for %ss." % highlight(duration)
