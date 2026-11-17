class_name GameplayStates
extends Node

var m_parent: LEntity

var invincibility_timer: Timer = Timer.new()

func _ready() -> void:
	m_parent = get_parent()
	if !m_parent:
		return
	m_parent.gameplay_states = self
	print(m_parent)
	_init_timers()

func apply_Invincibility(duration: float):
	m_parent.health_component.is_invincible = true
	recalculate_timer(invincibility_timer, duration)
	print("Start invincibility")

func recalculate_timer(timer: Timer, new_time: float):
	if timer.time_left < new_time:
		timer.wait_time = new_time
		timer.start()

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	pass

func _init_timers():
	_init_invincibility_timer()

func _init_invincibility_timer():
	invincibility_timer.one_shot = true
	invincibility_timer.timeout.connect(_end_invincibility)
	add_child(invincibility_timer)

func _end_invincibility():
	m_parent.health_component.is_invincible = false
	print("End invincibility")
