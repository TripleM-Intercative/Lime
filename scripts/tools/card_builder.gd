@tool
extends EditorScript
class_name CardBuilder

const window_margin: int = 20
const y_padding: int = 20
const EFFECT_BASE_CLASS: String = "CardEffect"
const CARD_SEARCH_PATH: String = "res://resources/"
const NEW_CARD_PATH: String = "res://resources/cards/"

var window: Window
var root: VBoxContainer
var content: VBoxContainer

var card: BaseCardRes
var edit_path: String = ""
var new_image_path: String = "" 
var texture_rect: TextureRect
var effects_list: VBoxContainer

var card_list: ItemList
var found_cards: Array[Dictionary]


func _run():
	window = Window.new()
	window.title = "Card Builder"
	EditorInterface.popup_dialog(window, Rect2(Vector2(100, 100), Vector2(400, 720)))
	window.close_requested.connect(_close)
	
	var margin: MarginContainer = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["margin_left", "margin_top", "margin_right", "margin_bottom"]:
		margin.add_theme_constant_override(side, window_margin)
	window.add_child(margin)
	
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	margin.add_child(scroll)
	
	root = VBoxContainer.new()
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_theme_constant_override("separation", y_padding)
	scroll.add_child(root)
	
	show_start_screen()


func _close():
	window.queue_free()

func clear_content():
	if content:
		root.remove_child(content)
		content.queue_free()
	
	content = VBoxContainer.new()
	content.add_theme_constant_override("separation", y_padding)
	root.add_child(content)

func is_edit_mode() -> bool:
	return edit_path != ""

func _create_button(text: String, callback: Callable) -> Button:
	var button: Button = Button.new()
	button.text = text
	button.pressed.connect(callback)
	return button

func _create_spacer() -> Control:
	var spacer: Control = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return spacer

func show_start_screen():
	clear_content()

	content.add_child(_create_button("Create New Card", func():
		show_card_form(BaseCardRes.new(), "")))
	content.add_child(_create_button("Edit Card", show_card_select))

func show_card_select():
	clear_content()
	load_all_cards()

	var search_field: LineEdit = LineEdit.new()
	search_field.placeholder_text = "Search cards..."
	search_field.clear_button_enabled = true
	search_field.text_changed.connect(fill_card_list)
	content.add_child(search_field)
	
	card_list = ItemList.new()
	card_list.custom_minimum_size = Vector2(0, 450)
	card_list.fixed_icon_size = Vector2i(32, 32)
	card_list.item_activated.connect(open_card)
	content.add_child(card_list)
	
	var button_row: HBoxContainer = HBoxContainer.new()
	button_row.add_child(_create_button("Back", show_start_screen))
	button_row.add_child(_create_spacer())
	button_row.add_child(_create_button("Edit", func():
		var selected: PackedInt32Array = card_list.get_selected_items()
		if not selected.is_empty():
			open_card(selected[0])))
	content.add_child(button_row)
	
	fill_card_list("")
	search_field.grab_focus.call_deferred()

func load_all_cards():
	found_cards.clear()
	for path: String in find_resource_paths(CARD_SEARCH_PATH):
		var res: Resource = load(path)
		if res is BaseCardRes:
			found_cards.append({"path": path, "card": res})
	
	found_cards.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return get_display_name(a).naturalnocasecmp_to(get_display_name(b)) < 0)

func find_resource_paths(folder: String) -> Array[String]:
	var result: Array[String] = []
	if not DirAccess.dir_exists_absolute(folder):
		return result
	
	for file: String in DirAccess.get_files_at(folder):
		if file.get_extension() in ["tres", "res"]:
			result.append(folder.path_join(file))
	for dir: String in DirAccess.get_directories_at(folder):
		result.append_array(find_resource_paths(folder.path_join(dir)))
	return result

func get_display_name(entry: Dictionary) -> String:
	var res: BaseCardRes = entry["card"]
	if res.card_name != "":
		return res.card_name
	return String(entry["path"]).get_file()

func fill_card_list(filter: String):
	card_list.clear()
	for entry: Dictionary in found_cards:
		var display_name: String = get_display_name(entry)
		if filter != "" and display_name.findn(filter) == -1:
			continue
	
		var res: BaseCardRes = entry["card"]
		var index: int = card_list.add_item(display_name, res.card_image)
		card_list.set_item_metadata(index, entry["path"])
		card_list.set_item_tooltip(index, entry["path"])

func open_card(index: int):
	var path: String = card_list.get_item_metadata(index)
	show_card_form(duplicate_card(load(path)), path)

func duplicate_card(src: BaseCardRes) -> BaseCardRes:
	var copy: BaseCardRes = src.duplicate()
	copy.target_cells = src.target_cells.duplicate()
	
	var copied_effects: Array[CardEffect] = []
	for effect: CardEffect in src.effects:
		copied_effects.append(effect.duplicate())
	copy.effects = copied_effects
	return copy

func show_card_form(card_res: BaseCardRes, path: String):
	card = card_res
	edit_path = path
	new_image_path = ""
	
	clear_content()
	create_name_input()
	create_image_input()
	create_heat_input()
	create_grid_selector_input()
	create_effects_input()
	create_form_buttons()

func create_name_input():
	var name_field: LineEdit = LineEdit.new()
	name_field.placeholder_text = "Enter Card Name"
	name_field.text = card.card_name
	
	if is_edit_mode():
		name_field.editable = false
		name_field.tooltip_text = "The card name can't be changed while editing."
	else:
		name_field.text_changed.connect(func(text: String): card.card_name = text)
	
	content.add_child(name_field)

func create_image_input():
	var image_row: HBoxContainer = HBoxContainer.new()
	
	texture_rect = TextureRect.new()
	texture_rect.custom_minimum_size = Vector2(150, 150)
	texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	if card.card_image:
		texture_rect.texture = card.card_image
	else:
		texture_rect.texture = ImageTexture.create_from_image(Image.load_from_file(Utils.DEFAULT_CARD_IMAGE))
	
	var load_image_button: Button = _create_button("Load Image", _on_load_image_button_pressed)
	load_image_button.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	
	image_row.add_child(texture_rect)
	image_row.add_child(load_image_button)
	content.add_child(image_row)

func _on_load_image_button_pressed():
	var file_dialog: FileDialog = FileDialog.new()
	file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	file_dialog.filters = PackedStringArray(["*.png ; PNG Images"])
	file_dialog.file_selected.connect(_on_file_selected)
	window.add_child(file_dialog)
	file_dialog.popup_centered(Vector2i(600, 400))

func _on_file_selected(path: String) -> void:
	var img: Image = Image.load_from_file(path)
	if img:
		new_image_path = path
		texture_rect.texture = ImageTexture.create_from_image(img)
	else:
		print("Error: CardBuilder could not load image")

func create_heat_input():
	var heat_input_container: HBoxContainer = HBoxContainer.new()
	
	var heat_drop_down: VBoxContainer = Utils.create_dropdown_input_with_enum(Enums.HeatCost, "Heat",
		func(value: int): card.heat_cost = value)
	(heat_drop_down.get_child(1) as OptionButton).select(card.heat_cost)
	
	var heat_amount_input: HBoxContainer = Utils.create_int_input_field("Amount",
		func(value: float): card.heat_cost_amount = int(value))
	(heat_amount_input.get_child(1) as SpinBox).value = card.heat_cost_amount
	
	heat_input_container.add_child(heat_drop_down)
	heat_input_container.add_child(heat_amount_input)
	content.add_child(heat_input_container)

func create_grid_selector_input():
	var grid_selector: GridSelector = GridSelector.new()
	if not card.target_cells.is_empty():
		grid_selector.create_new_grid(get_grid_size_for(card.target_cells), card.target_cells)
	grid_selector.set_grid_positions.connect(set_target_cells)
	
	var edit_grid_button: Button = _create_button("Edit Grid", grid_selector.edit_grid)
	content.add_child(edit_grid_button)

func get_grid_size_for(offsets: Array[Vector2i]) -> int:
	var max_offset: int = 0
	for offset: Vector2i in offsets:
		max_offset = maxi(max_offset, maxi(absi(offset.x), absi(offset.y)))
	return maxi(GridSelector.DEFAULT_SIZE, max_offset + 1)

func set_target_cells(positions: Array[Vector2i], origin: Vector2i):
	card.target_cells.clear()
	for pos in positions:
		card.target_cells.append(pos - origin)

func create_effects_input():
	var header: HBoxContainer = HBoxContainer.new()
	var title: Label = Label.new()
	title.text = "Effects"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	var add_button: MenuButton = MenuButton.new()
	add_button.text = "+"
	add_button.flat = false
	fill_effect_menu(add_button.get_popup())
	
	header.add_child(title)
	header.add_child(add_button)
	
	effects_list = VBoxContainer.new()
	content.add_child(header)
	content.add_child(effects_list)
	
	for effect: CardEffect in card.effects:
		create_effect_entry(effect)

func fill_effect_menu(popup: PopupMenu):
	var classes: Array[Dictionary] = get_effect_classes()
	var types: Array[int] = []
	for effect_class: Dictionary in classes:
		var instance: CardEffect = load(effect_class["path"]).new()
		types.append(instance.card_type)

	for type: int in Enums.CardType.values():
		var has_separator: bool = false
		for i: int in classes.size():
			if types[i] != type:
				continue
			if not has_separator:
				popup.add_separator(Enums.CardType.keys()[type])
				has_separator = true
			popup.add_item(String(classes[i]["class"]), i)

	popup.id_pressed.connect(func(id: int):
		var effect: CardEffect = load(classes[id]["path"]).new()
		card.effects.append(effect)
		create_effect_entry(effect))

func get_effect_classes() -> Array[Dictionary]:
	var all_classes: Array[Dictionary] = ProjectSettings.get_global_class_list()
	var base_of: Dictionary = {}
	for c: Dictionary in all_classes:
		base_of[String(c["class"])] = String(c["base"])

	var result: Array[Dictionary] = []
	for c: Dictionary in all_classes:
		var base: String = String(c["base"])
		while base != "":
			if base == EFFECT_BASE_CLASS:
				result.append(c)
				break
			base = base_of.get(base, "")
	return result

func create_effect_entry(effect: CardEffect):
	var entry: VBoxContainer = VBoxContainer.new()
	var separator: HSeparator = HSeparator.new()
	var panel: PanelContainer = PanelContainer.new()
	var box: VBoxContainer = VBoxContainer.new()
	entry.add_child(separator)
	entry.add_child(panel)
	panel.add_child(box)
	
	var header: HBoxContainer = HBoxContainer.new()
	var title: Label = Label.new()
	title.text = "%s (%s)" % [effect.get_script().get_global_name(), Enums.CardType.keys()[effect.card_type]]
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var remove_button: Button = _create_button("X", func():
		card.effects.erase(effect)
		effects_list.remove_child(entry)
		entry.queue_free()
		update_effect_separators())
	header.add_child(title)
	header.add_child(remove_button)
	box.add_child(header)

	for prop: Dictionary in effect.get_property_list():
		if prop["usage"] & PROPERTY_USAGE_SCRIPT_VARIABLE and prop["usage"] & PROPERTY_USAGE_EDITOR:
			var field: Control = create_property_field(effect, prop)
			if field:
				box.add_child(field)

	effects_list.add_child(entry)
	update_effect_separators()

func update_effect_separators():
	for i: int in effects_list.get_child_count():
		var separator: HSeparator = effects_list.get_child(i).get_child(0)
		separator.visible = i > 0

func create_property_field(effect: CardEffect, prop: Dictionary) -> Control:
	var prop_name: String = prop["name"]
	var label: String = prop_name.capitalize()
	var current: Variant = effect.get(prop_name)

	match prop["type"]:
		TYPE_BOOL:
			var bool_field: HBoxContainer = Utils.create_bool_input_field(label,
				func(value: bool): effect.set(prop_name, value))
			bool_field.get_child(1).button_pressed = current
			return bool_field
		TYPE_INT:
			if prop["hint"] == PROPERTY_HINT_ENUM:
				return create_enum_field(effect, prop)
			var int_field: HBoxContainer = Utils.create_int_input_field(label,
				func(value: float): effect.set(prop_name, int(value)))
			int_field.get_child(1).value = current
			return int_field
		TYPE_FLOAT:
			var float_field: HBoxContainer = Utils.create_float_input_field(label,
				func(value: float): effect.set(prop_name, value))
			float_field.get_child(1).value = current
			return float_field

	return null

func create_enum_field(effect: CardEffect, prop: Dictionary) -> Control:
	var prop_name: String = prop["name"]
	var row: HBoxContainer = HBoxContainer.new()
	var label: Label = Label.new()
	label.text = prop_name.capitalize()
	var dropdown: OptionButton = OptionButton.new()

	for entry: String in String(prop["hint_string"]).split(","):
		var parts: PackedStringArray = entry.split(":")
		var value: int = int(parts[1]) if parts.size() > 1 else dropdown.item_count
		dropdown.add_item(parts[0], value)

	dropdown.select(dropdown.get_item_index(effect.get(prop_name)))
	dropdown.item_selected.connect(func(index: int):
		effect.set(prop_name, dropdown.get_item_id(index)))

	row.add_child(label)
	row.add_child(dropdown)
	return row

func create_form_buttons():
	var button_row: HBoxContainer = HBoxContainer.new()
	button_row.add_child(_create_button("Back", show_start_screen))
	button_row.add_child(_create_spacer())
	button_row.add_child(_create_button("Save" if is_edit_mode() else "Create", _on_save_pressed))
	content.add_child(button_row)

func _on_save_pressed():
	var success: bool = save_edited_card() if is_edit_mode() else create_new_card()
	if success:
		_close()

func apply_image():
	card.card_image = load(Utils.safe_image_to_assets(new_image_path, card.card_name))

func create_new_card() -> bool:
	if card.card_name.strip_edges() == "":
		push_warning("CardBuilder: Please enter a card name.")
		return false

	var path: String = NEW_CARD_PATH + card.card_name.to_lower().to_snake_case() + ".tres"
	if FileAccess.file_exists(path):
		push_warning("CardBuilder: A card already exists at " + path)
		return false
	
	apply_image()

	if not DirAccess.dir_exists_absolute(NEW_CARD_PATH):
		DirAccess.make_dir_recursive_absolute(NEW_CARD_PATH)

	if ResourceSaver.save(card, path) != OK:
		push_error("CardBuilder: Failed creating resource for " + card.card_name)
		return false
	
	Utils.create_card_script(card.card_name, path)
	EditorInterface.get_resource_filesystem().update_file(path)
	print("Successfully created resource for " + card.card_name)
	return true

func save_edited_card() -> bool:
	if new_image_path != "":
		apply_image()
	
	card.take_over_path(edit_path)

	if ResourceSaver.save(card, edit_path) != OK:
		push_error("CardBuilder: Failed saving " + edit_path)
		return false

	EditorInterface.get_resource_filesystem().update_file(edit_path)
	print("Successfully saved changes to " + card.card_name)
	return true
