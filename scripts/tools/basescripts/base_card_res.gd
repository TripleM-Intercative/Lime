class_name BaseCardRes
extends Resource

@export var card_name: String = ""
@export var card_image: Texture2D = null
@export var heat_cost: Enums.HeatCost = Enums.HeatCost.NoCost
@export var heat_cost_amount: int = 0
@export var exhausted_on_use: bool = false
@export var target_cells: Array[Vector2i] = []
@export var effects: Array[CardEffect] = []
