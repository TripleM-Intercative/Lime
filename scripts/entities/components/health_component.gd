class_name HealthComponent
extends Node

signal died

const SHIELD_NEGATE_FACTOR: float = 0.2

@export var max_health: float
@export var shield:float = 0
@export var revive_aktiv: bool

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
	var blocked_amount: float = minf(shield, amount)
	shield -= blocked_amount
	return blocked_amount

func calculate_health_damage(amount: float) -> float:
	var blocked: float = damage_shield(amount)
	return (amount - blocked) + (blocked - blocked * SHIELD_NEGATE_FACTOR)

func kill():
	current_health = 0.0
	print("D - New Health: " + str(current_health))

func set_reviving(aktiv: bool):
	revive_aktiv = aktiv

func _set_heath(val: float) -> void:
	current_health = val
	if (current_health <= 0):
		if revive_aktiv:
			revive_aktiv = false
			current_health = max_health
			print("Revived: " + str(m_parent))
		else:
			m_parent.path_manager.unregister_entity(m_parent.path_manager_id)
			m_parent.queue_free()
			died.emit()
