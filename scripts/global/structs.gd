@tool
extends Node

class BaseCardData:
	var image_pc_path: String
	var name_field: LineEdit
	var heat_type: Enums.HeatCost
	var heat_amount: int

class DamageCardData:
	var amount: float
	var check: bool

class HealCardData:
	var amount: float

class AuraCardData:
	var amount: float

class BuffCardData:
	var amount: float
