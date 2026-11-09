extends Node

signal input_changed(new: Array[InputData])

@export var actions: Array[StringName]

@export var hold_duration := 0.4
@export var input_delay_duration := 0.04

var data_array: Array[InputData]

var input_delay := false
var input_delay_timer := 0.0

func _ready() -> void:
	for action in actions:
		data_array.push_back(InputData.new(action, 0.0, false, 0.0))

func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_echo():
		return
		
	for data in data_array:
		if event.is_action_pressed(data.action):
			data.value = 1.0
			
			if !input_delay:
				input_delay = true
				input_delay_timer = 0.0
			
		if event.is_action_released(data.action):
			data.value = 0.0
			data.hold = false
			data.hold_timer = 0.0
			
			if !input_delay:
				input_delay = true
				input_delay_timer = 0.0

func _process(delta: float) -> void:
	
	if input_delay:
		input_delay_timer += delta
		
		if input_delay_timer >= input_delay_duration:
			input_delay = false
			input_delay_timer = 0.0
			
			input_changed.emit(data_array)
	
	var value_changed := false
	for data in data_array:
		if data.value > 0.0 && !data.hold:
			data.hold_timer += delta
			
			if data.hold_timer >= hold_duration:
				data.hold = true
				value_changed = true
				
	if value_changed:
		input_changed.emit(data_array)
