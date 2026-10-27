@tool
class_name CardBuilder
extends EditorScript

const window_margin: int = 20
const y_padding: int = 20
const EFFECT_BASE_CLASS: String = "CardEffect"

var window: Window
var root: VBoxContainer
var content: VBoxContainer
var texture_rect: TextureRect
var effects_list: VBoxContainer
var base_card_data: Structs.BaseCardData = Structs.BaseCardData.new()
var effects: Array[CardEffect] = []


func _run():
	window = Window.new()
	EditorInterface.popup_dialog(window, Rect2(Vector2(100, 100), Vector2(400, 720)))
	
	window.close_requested.connect(func():
		window.queue_free())
	
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
	
	build_layout()


func _on_close_requested():
	window.queue_free()

func build_layout():
	clear_content()
	create_name_input_layout()
	create_image_input_layout()
	create_heat_input()
	create_grid_selector_input()
	create_effects_input()
	create_create_button()

func create_image_input_layout():
	var image_row: HBoxContainer = HBoxContainer.new()
	
	texture_rect = TextureRect.new()
	texture_rect.custom_minimum_size = Vector2(150, 150)
	texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var img: Image = Image.load_from_file("res://assets/default_card_image.png")
	var texture: ImageTexture = ImageTexture.create_from_image(img)
	texture_rect.texture = texture
	
	var load_image_button: Button = Button.new()
	load_image_button.text = "Load Image"
	load_image_button.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	load_image_button.pressed.connect(_on_load_image_button_pressed)
	
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
	base_card_data.image_pc_path = path
	print(base_card_data.image_pc_path)
	
	if img:
		var texture: ImageTexture = ImageTexture.create_from_image(img)
		texture_rect.texture = texture
	else:
		print("Error: CardBuilder could not load image")

func create_heat_input():
	var heat_input_container: HBoxContainer = HBoxContainer.new()
	
	var heat_drop_down: VBoxContainer = Utils.create_dropdown_input_with_enum(Enums.HeatCost, "Heat", 
		func(value: Enums.HeatCost): base_card_data.heat_type = value)
	
	var heat_amount_input: HBoxContainer = Utils.create_int_input_field("Amount",
		func(value: int): base_card_data.heat_amount = value)
		
	heat_input_container.add_child(heat_drop_down)
	heat_input_container.add_child(heat_amount_input)
	
	content.add_child(heat_input_container)

func create_name_input_layout():
	var name_input_field: LineEdit = LineEdit.new()
	name_input_field.placeholder_text = "Enter Card Name"
	
	base_card_data.name_field = name_input_field
	content.add_child(name_input_field)

func create_create_button():
	var create_button: Button = Button.new()
	create_button.text = "Create"
	create_button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	create_button.pressed.connect(_on_create_button_pressed)
	
	content.add_child(create_button)

func _on_create_button_pressed():
	var new_resource_path: String = create_card_resource()
	Utils.create_card_script(base_card_data.name_field.text, new_resource_path)
	_on_close_requested()

func clear_content():
	if content:
		root.remove_child(content)
		content.queue_free()
	
	content = VBoxContainer.new()
	content.add_theme_constant_override("separation", y_padding)
	root.add_child(content)
	
	base_card_data.image_pc_path = ""
	base_card_data.target_cells.clear()
	effects.clear()

func create_card_resource() -> String:
	var card_res: BaseCardRes = BaseCardRes.new()
	
	card_res.card_name = base_card_data.name_field.text
	card_res.heat_cost = base_card_data.heat_type
	card_res.heat_cost_amount = base_card_data.heat_amount
	card_res.target_cells = base_card_data.target_cells.duplicate()
	card_res.effects = effects.duplicate()
	
	var card_image_path: String = Utils.safe_image_to_assets(base_card_data.image_pc_path, card_res.card_name)
	
	if card_image_path != "":
		card_res.card_image = load(card_image_path)
	var folder_path: String = "res://resources/cards/"
	var file_name: String = card_res.card_name.to_lower().to_snake_case() + ".tres"
	var full_res_path: String = folder_path + file_name
	
	if not DirAccess.dir_exists_absolute(folder_path):
		DirAccess.make_dir_recursive_absolute(folder_path)
	
	if ResourceSaver.save(card_res, full_res_path) == OK:
		print("Successfully created resource for " + card_res.card_name)
	else:
		print("Failed creating resource for " + card_res.card_name)
	
	return full_res_path

func set_target_cells(positions: Array[Vector2], origin: Vector2):
	base_card_data.target_cells.clear()
	for pos in positions:
		base_card_data.target_cells.append(pos - origin)

func create_grid_selector_input():
	var grid_selector: GridSelector = GridSelector.new()
	grid_selector.set_grid_positions.connect(set_target_cells)
	var edit_grid_button: Button = Button.new()
	edit_grid_button.text = "Edit Grid"
	edit_grid_button.pressed.connect(grid_selector.edit_grid)
	content.add_child(edit_grid_button)

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
		add_effect(load(classes[id]["path"]).new()))

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

func add_effect(effect: CardEffect):
	effects.append(effect)
	
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
	var remove_button: Button = Button.new()
	remove_button.text = "?"
	remove_button.pressed.connect(func():
		effects.erase(effect)
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
