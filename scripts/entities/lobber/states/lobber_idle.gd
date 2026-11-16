class_name LobberIdle
extends State

@export var idle_time: float = 1.0

# state control vars
var idled_time: float = 0.0

func _enter() -> void:
	idled_time = 0.0
	pass

func _exit() -> void:
	pass

func _update(_delta: float) -> void:
	idled_time += _delta
	if idled_time >= idle_time:
		transitioned.emit(self, "LobberPatrol")
	pass

func _physics_update(_delta: float) -> void:
	pass
