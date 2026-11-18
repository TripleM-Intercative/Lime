class_name HealthComponent
extends Node

signal died

const SHIELD_NEGATE_FACTOR: float = 0.2

@export var max_health: float
@export var shield:float = 0

var is_invincible: bool = false

var current_health: float:
	set = _set_heath

var m_parent: LEntity

func _ready() -> void:
	m_parent = get_parent()
	current_health = max_health
	if !m_parent:
		return
	m_parent.health_component = self
	print(m_parent)

func apply_damage(amount: float):
	if is_invincible:
		return
	current_health = clampf(current_health - calculate_health_damage(amount), 0, max_health)
	print("D - Shield: %s, Health: %s" % [shield, current_health])

func apply_heal(amount: float):
	current_health = clampf(current_health + amount, 0, max_health)
	print("H - New Health: " + str(current_health))

func damage_shield(amount: float) -> float:
	var remaining_shield: float = shield - amount
	shield = clampf(remaining_shield, 0, 999999)
	return remaining_shield

func calculate_health_damage(amount: float) -> float:
	var remaining_shield: float = damage_shield(amount)
	if remaining_shield >= 0:
		return amount - (amount * SHIELD_NEGATE_FACTOR)
	else:
		var flat_damage: float = abs(remaining_shield)
		var shielded_amount: float = amount + remaining_shield
		var blocked_damage: float = shielded_amount - (shielded_amount * SHIELD_NEGATE_FACTOR)
		return flat_damage + blocked_damage

func kill():
	current_health = 0.0
	print("D - New Health: " + str(current_health))

func _set_heath(val: float) -> void:
	current_health = val
	if (current_health <= 0):
		died.emit()
