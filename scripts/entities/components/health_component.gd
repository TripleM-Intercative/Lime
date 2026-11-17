class_name HealthComponent
extends Node

signal died

@export var max_health: float

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

#func _process(delta: float) -> void:
	#pass

func apply_damage(amount: float):
	current_health = clampf(current_health - amount, 0, max_health)
	print("D - New Health: "  + str(current_health))

func apply_heal(amount: float):
	current_health = clampf(current_health + amount, 0, max_health)
	print("H - New Health: " + str(current_health))

func _set_heath(val: float) -> void:
	current_health = val
	if (current_health <= 0):
		died.emit()
