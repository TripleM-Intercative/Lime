## Used for building finite statemachines for state controlled units
class_name StateMachine
extends Node

@export var initial_state: State

var parent: LEntity

var m_states: Array[State]
var m_current_state: State

func _ready() -> void:
	for child in get_children():
		if child is State:
			m_states.append(child)
			child.transitioned.connect(_on_lobber_state_changed)

	parent = get_parent() as LEntity
	assert(parent, "StateMachine is not a direct child of an entity")

	_set_initial.call_deferred()

func _process(delta: float) -> void:
	if m_current_state:
		m_current_state._update(delta)

func _physics_process(delta: float) -> void:
	if m_current_state:
		m_current_state._physics_update(delta)

func _on_lobber_state_changed(old: State, new: StringName) -> void:
	if old != m_current_state:
		return

	old._exit()
	m_current_state = find_child(new)
	m_current_state._enter()

func _set_initial() -> void:
	parent.path_manager.entity_cell_changed.connect(_on_character_cell_changed)

	m_current_state = initial_state
	m_current_state._enter()

func _on_character_cell_changed(_type: LEntity, _old: Vector2i, _new: Vector2i) -> void:
	pass
