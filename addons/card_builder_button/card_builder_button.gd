@tool
extends EditorPlugin

var button: Button
var card_builder: CardBuilder


func _enter_tree() -> void:
	button = Button.new()
	button.text = "Card Builder"
	button.tooltip_text = "Opden Card Builder"
	button.pressed.connect(_on_pressed)
	add_control_to_container(CONTAINER_TOOLBAR, button)

func _exit_tree() -> void:
	if card_builder && is_instance_valid(card_builder.window):
		card_builder.window.queue_free()
	card_builder = null
	if button:
		remove_control_from_container(CONTAINER_TOOLBAR, button)
		button.queue_free()


func _on_pressed() -> void:
	if card_builder && is_instance_valid(card_builder.window):
		card_builder.window.grab_focus()
		return
	card_builder = CardBuilder.new()
	card_builder._run()
	card_builder.window.tree_exited.connect(func(): card_builder = null)
