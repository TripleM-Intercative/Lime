@tool
class_name CardEffect
extends Resource

var card_type: Enums.CardType = Enums.CardType.None

func apply(_card: CardBase) -> void:
	push_warning("no effect placed")

func get_description() -> String:
	return ""
	
func highlight(value, color: Variant = null) -> String:
	var text_color: Color
	
	if color != null:
		text_color = color
	else:
		text_color = Utils.EFFECT_COLOR_TYPES.get(card_type, Color.WHITE)
	
	var color_as_hex: String = text_color.to_html(false)
	return "[color=#" + color_as_hex + "][b]" + str(value) + "[/b][/color]"
