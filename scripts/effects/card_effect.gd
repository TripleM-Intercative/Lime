@tool
class_name CardEffect
extends Resource

var card_type: Enums.CardType = Enums.CardType.None

func apply(_target: LEntity) -> void:
	pass

func get_description() -> String:
	return ""

func do_deck_operation(_deck: Deck):
	pass

func highlight(value, color: Variant = null) -> String:
	var text_color: Color
	
	if color != null:
		text_color = color
	else:
		text_color = Utils.EFFECT_COLOR_TYPES.get(card_type, Color.WHITE)
	
	var color_as_hex: String = text_color.to_html(false)
	return "[color=#" + color_as_hex + "][b]" + str(value) + "[/b][/color]"

func init_effect(_card: CardBase):
	pass
