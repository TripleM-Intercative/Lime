class_name InputData
extends RefCounted

var action: StringName
var value: float
var hold: bool
var hold_timer: float

func _init(_action: StringName, _value: float, _hold: bool, _hold_timer: float) -> void:
	action = _action
	value = _value
	hold = _hold
	hold_timer = _hold_timer
