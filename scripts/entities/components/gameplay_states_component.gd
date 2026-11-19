class_name GameplayStates
extends Node

var m_parent: LEntity

var invincibility_timer: Timer = Timer.new()
var stun_timer: Timer = Timer.new()

func _ready() -> void:
	m_parent = get_parent()
	if !m_parent:
		return
	m_parent.gameplay_states = self
	print(m_parent)
	_init_timers()

func _init_timers():
	_init_invincibility_timer()
	_init_stun_timer()


func recalculate_timer(timer: Timer, new_time: float):
	if timer.time_left < new_time:
		timer.wait_time = new_time
		timer.start()

func apply_Invincibility(duration: float):
	m_parent.health_component.is_invincible = true
	recalculate_timer(invincibility_timer, duration)
	print("Start invincibility")

func _init_invincibility_timer():
	invincibility_timer.one_shot = true
	invincibility_timer.timeout.connect(_end_invincibility)
	add_child(invincibility_timer)

func _end_invincibility():
	m_parent.health_component.is_invincible = false
	print("End invincibility")

func apply_stun(duration: float):
	m_parent.is_stunned = true
	recalculate_timer(stun_timer, duration)
	print("Start Stun")

func _init_stun_timer():
	stun_timer.one_shot = true
	stun_timer.timeout.connect(_end_stun)
	add_child(stun_timer)

func _end_stun():
	m_parent.is_stunned = false
	print("End Stun")
