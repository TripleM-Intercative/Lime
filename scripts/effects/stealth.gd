@tool
class_name Stealth
extends CardEffect

@export var duration: float = 0.0

func _init() -> void:
	card_type = Enums.CardType.Defense

func apply(target: LEntity) -> void:
	if !is_instance_valid(target.gameplay_states):
		return
	if target.faction_id == 0:
		target.gameplay_states.apply_Invincibility(duration)

func get_description() -> String:
	return "Target is invincible for %ss." % [highlight(duration)]
