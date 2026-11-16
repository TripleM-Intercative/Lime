class_name State
extends Node

# DO NOT USE
# func _ready() -> void:
# 	pass # Replace with function body.
# func _process(delta: float) -> void:
# 	pass

signal transitioned(old: State, new: State)

func _enter() -> void:
	pass

func _exit() -> void:
	pass

func _update(_delta: float) -> void:
	pass

func _physics_update(_delta: float) -> void:
	pass

func _characer_cell_changed(old: Vector2i, new: Vector2i) -> void:
	pass
