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
	var solid: bool
	
	func _init(_type: Enums.EntityType, _pos: Vector2i, _size: int, _solid: bool) -> void:
		type = _type
		pos = _pos
		size = _size
		solid = _solid

class Obstacle:
	var solid_data: Dictionary[int, int] = {}  
	var soft_data: Dictionary[int, int] = {}
	
	func add(type: int, solid: bool, amount: int = 1) -> void:
		if solid:
			solid_data[type] = solid_data.get(type, 0) + amount
		else:
			soft_data[type] = soft_data.get(type, 0) + amount
		
	func remove(type: int, solid: bool, amount: int = 1) -> void:
		var target = solid_data if solid else soft_data
		
		if target.has(type):
			target[type] -= amount
			if target[type] <= 0:
				target.erase(type)
		
	func get_soft_cost(costs: Dictionary) -> float:
		var total := 0.0
		
		for type in soft_data:
			total += soft_data[type] * costs.get(type, 1.0)
		return total
		
	func is_any_solid() -> bool:
		return !solid_data.is_empty()
		
	func is_any_soft() -> bool:
		return !soft_data.is_empty()
		
	func is_completely_empty() -> bool:
		return solid_data.is_empty() && soft_data.is_empty()
		
	func get_type_empty(type: int, solid: bool) -> bool:
		if solid:
			return solid_data.get(type, 0) == 0
		else:
			return soft_data.get(type, 0) == 0
			
	func has_type(type: int, solid: bool) -> bool:
		if solid:
			return solid_data.get(type, 0) > 0
		else:
			return soft_data.get(type, 0) > 0

class CachedPath:
	var target: Vector2i
	var cells: Array[Vector2i] = []
	var complete: bool = false
	var version: int
