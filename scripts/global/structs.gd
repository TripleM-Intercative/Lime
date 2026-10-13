@tool
extends Node

class BaseCardData:
	var image_pc_path: String
	var name_field: LineEdit

class DamageCardData:
	var amount: float
	var check: bool

class HealCardData:
	var amount: float

class AuraCardData:
	var amount: float

class BuffCardData:
	var amount: float
