class_name CardVisual
extends Control

signal on_card_gui_input(event: InputEvent)
signal on_card_mouse_entered()
signal on_card_mouse_exited()

var card_res: BaseCardRes
@onready var card_image_rect: TextureRect = $MarginContainer/VBoxContainer/CardImage
@onready var heat_icon_rect: TextureRect = $MarginContainer/VBoxContainer/HeatInfo/HeatIcon
@onready var heat_amount_label: Label = $MarginContainer/VBoxContainer/HeatInfo/HeatAmount

@onready var card_name_label: Label = $MarginContainer/VBoxContainer/CardName
@onready var card_description_label: RichTextLabel = $MarginContainer/VBoxContainer/CardDescription

var base_z_index: int

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func init_card_visual(card_data: BaseCardRes):
	card_res = card_data
	init_card_ui()

func init_card_ui() -> void:
	card_image_rect.texture = card_res.card_image
	card_image_rect.self_modulate = Utils.RARITY_COLOR.get(card_res.rarity, Color.WHITE)
	card_name_label.text = card_res.card_name
	card_description_label.text = create_card_description()
	
	match card_res.heat_cost:
		Enums.HeatCost.NoCost:
			heat_icon_rect.texture = load("res://assets/default_card_image.png")
		Enums.HeatCost.Increase:
			heat_icon_rect.texture = load("res://assets/images/test_heat_icon.png")
		Enums.HeatCost.Cooldown:
			heat_icon_rect.texture = load("res://assets/images/test_cooldown_icon.png")
	
	heat_amount_label.text = str(card_res.heat_cost_amount)
	base_z_index = self.z_index

func create_card_description() -> String:
	var lines: PackedStringArray = []
	for effect: CardEffect in card_res.effects:
		var text: String = effect.get_description()
		if text != "":
			lines.append(text)
	return "\n".join(lines)

func _on_gui_input(event: InputEvent) -> void:
	on_card_gui_input.emit(event)


func _on_mouse_entered() -> void:
	on_card_mouse_entered.emit()


func _on_mouse_exited() -> void:
	on_card_mouse_exited.emit()
