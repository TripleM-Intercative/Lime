@tool
class_name Structs
extends RefCounted

class BaseCardData:
	var image_pc_path: String
	var name_field: LineEdit
	var heat_type: Enums.HeatCost
	var heat_amount: int
	var target_cells: Array[Vector2i]

class DamageCardData:
	var amount: float
	var check: bool

class HealCardData:
	var amount: float

class AuraCardData:
	var amount: float

class BuffCardData:
	var amount: float

class Entity:
	var type: Enums.EntityType
	var pos: Vector2i
	var size: int
	var is_solid: bool
	
	func _init(_type: Enums.EntityType, _pos: Vector2i, _size: int, _is_solid: bool) -> void:
		type = _type
		pos = _pos
		size = _size
		is_solid = _is_solid

class Obstacle:
	var solid_data: Dictionary[int, int] = {}  
	var soft_data: Dictionary[int, int] = {}
	
	func add(type: int, is_solid: bool, amount: int = 1) -> void:
		if is_solid:
			solid_data[type] = solid_data.get(type, 0) + amount
		else:
			soft_data[type] = soft_data.get(type, 0) + amount
	
	func remove(type: int, is_solid: bool, amount: int = 1) -> void:
		var target = solid_data if is_solid else soft_data
		
		if target.has(type):
			target[type] -= amount
			if target[type] <= 0:
				target.erase(type)
	
	func is_any_solid() -> bool:
		return !solid_data.is_empty()
	
	func is_any_soft() -> bool:
		return !soft_data.is_empty()
	
	func is_completely_empty() -> bool:
		return solid_data.is_empty() && soft_data.is_empty()
