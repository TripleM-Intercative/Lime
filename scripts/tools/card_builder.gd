@tool
class_name CardBuilder
extends EditorScript

const window_margin: int = 20
const y_padding: int = 20
var window: Window
var root: VBoxContainer
var content: VBoxContainer
var texture_rect: TextureRect
var card_type_dropdown: OptionButton
var card_type: Enums.CardType
var base_card_data: Structs.BaseCardData = Structs.BaseCardData.new()
var damage_card_data: Structs.DamageCardData = Structs.DamageCardData.new()
var heal_card_data: Structs.HealCardData = Structs.HealCardData.new()
var aura_card_data: Structs.AuraCardData = Structs.AuraCardData.new()
var buff_card_data: Structs.BuffCardData = Structs.BuffCardData.new()


func _run():
	window = Window.new()
	EditorInterface.popup_dialog(window, Rect2(Vector2(100, 100), Vector2(350, 720)))
	
	window.close_requested.connect(func():
		window.queue_free())
	
	var margin: MarginContainer = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["margin_left", "margin_top", "margin_right", "margin_bottom"]:
		margin.add_theme_constant_override(side, window_margin)
	window.add_child(margin)
	
	root = VBoxContainer.new()
	root.add_theme_constant_override("separation", y_padding)
	margin.add_child(root)
	
	card_type_dropdown = create_card_type_dropdown()
	root.add_child(card_type_dropdown)


func _on_close_requested():
	window.queue_free()

func create_card_type_dropdown() -> OptionButton:
	var new_dropdown: OptionButton = OptionButton.new()
	
	new_dropdown.add_item("None", 0)
	new_dropdown.add_item("Damage Card", 1)
	new_dropdown.add_item("Heal Card", 2)
	new_dropdown.add_item("Aura Card", 3)
	new_dropdown.add_item("Buff Card", 4)
	
	new_dropdown.item_selected.connect(_on_card_type_selected)
	
	return new_dropdown

func _on_card_type_selected(type: int):
	card_type = type as Enums.CardType
	clear_content()
	create_name_input_layout()
	create_image_input_layout()
	create_heat_input()
	
	match card_type:
		Enums.CardType.None:
			return
		Enums.CardType.Damage:
			create_damage_input_layout()
		Enums.CardType.Heal:
			create_heal_input_layout()
		Enums.CardType.Aura:
			create_aura_input_layout()
		Enums.CardType.Buff:
			create_buff_input_layout()
	
	create_create_button()
	

func create_image_input_layout():
	var image_row: HBoxContainer = HBoxContainer.new()
	
	texture_rect = TextureRect.new()
	texture_rect.custom_minimum_size = Vector2(150, 150)
	texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var img = Image.load_from_file("res://assets/default_card_image.png")
	var texture = ImageTexture.create_from_image(img)
	texture_rect.texture = texture
	
	var load_image_button: Button = Button.new()
	load_image_button.text = "Load Image"
	load_image_button.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	load_image_button.pressed.connect(_on_load_image_button_pressed)
	
	image_row.add_child(texture_rect)
	image_row.add_child(load_image_button)
	content.add_child(image_row)
	

func _on_load_image_button_pressed():
	var file_dialog: FileDialog
	
	file_dialog = FileDialog.new()
	file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	file_dialog.filters = PackedStringArray(["*.png ; PNG Images"])
	
	file_dialog.file_selected.connect(_on_file_selected)
	window.add_child(file_dialog)
	
	file_dialog.popup_centered(Vector2i(600, 400))

func _on_file_selected(path: String) -> void:
	var img = Image.load_from_file(path)
	base_card_data.image_pc_path = path
	print(base_card_data.image_pc_path)
	
	if img:
		var texture = ImageTexture.create_from_image(img)
		
		texture_rect.texture = texture
	else:
		print("Error: CardBuilder could not load image")

func create_heat_input():
	var heat_input_container: HBoxContainer = HBoxContainer.new()
	
	var heat_drop_down = Utils.create_dropdown_input_with_enum(Enums.HeatCost, "Heat", 
		func(value: Enums.HeatCost): base_card_data.heat_type = value)
	
	var heat_amount_input = Utils.create_int_input_field("Amount",
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
	Utils.create_card_script(base_card_data.name_field.text, new_resource_path, card_type)
	_on_close_requested()
	
func clear_content():
	if content:
		root.remove_child(content)
		content.queue_free()
	
	content = VBoxContainer.new()
	content.add_theme_constant_override("separation", y_padding)
	root.add_child(content)
	
	base_card_data.image_pc_path = ""
	damage_card_data.amount = 0
	
func create_card_resource() -> String:
	var card_res: BaseCardRes
	
	match card_type:
		Enums.CardType.None:
			return ""
		Enums.CardType.Damage:
			card_res = set_up_damage_card_res()
		Enums.CardType.Heal:
			card_res = set_up_heal_card_res()
		Enums.CardType.Aura:
			card_res = set_up_aura_card_res()
		Enums.CardType.Buff:
			card_res = set_up_buff_card_res()
	
	card_res.card_name = base_card_data.name_field.text
	card_res.heat_cost = base_card_data.heat_type
	card_res.heat_cost_amount = base_card_data.heat_amount
	
	var card_image_path: String 
	card_image_path = Utils.safe_image_to_assets(base_card_data.image_pc_path, card_res.card_name)
	
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
	
func set_up_damage_card_res() -> BaseCardRes:
	var damage_res: DamageCardRes = DamageCardRes.new()
	damage_res.damage_amount = damage_card_data.amount
	damage_res.damage_check = damage_card_data.check
	return damage_res
	
func set_up_heal_card_res() -> BaseCardRes:
	var heal_res: HealCardRes = HealCardRes.new()
	heal_res.heal_amount = heal_card_data.amount
	return heal_res
	
func set_up_aura_card_res() -> BaseCardRes:
	var aura_res: AuraCardRes = AuraCardRes.new()
	aura_res.aura = aura_card_data.amount
	return aura_res
	
func set_up_buff_card_res() -> BaseCardRes:
	var buff_res: BuffCardRes = BuffCardRes.new()
	buff_res.buff = buff_card_data.amount
	return buff_res
	
func create_damage_input_layout():
	var damage_amount_input: HBoxContainer = Utils.create_float_input_field("Damage amount:",
		func(value: float): damage_card_data.amount = value)
	var damage_checkbox_input: HBoxContainer = Utils.create_bool_input_field("Checkbox",
		func(value: bool): damage_card_data.check = value)
	var grid_selector: GridSelector = GridSelector.new()
	grid_selector.set_grid_positions.connect(set_target_cells)
	var edit_grid_button: Button = Button.new()
	edit_grid_button.text = "Edit Grid"
	edit_grid_button.pressed.connect(grid_selector.edit_grid)
	content.add_child(damage_amount_input)
	content.add_child(damage_checkbox_input)
	content.add_child(edit_grid_button)

func create_heal_input_layout():
	var damage_amount_input: HBoxContainer = Utils.create_float_input_field("Heal amount:",
		func(value: float): heal_card_data.amount = value)
	content.add_child(damage_amount_input)

func create_aura_input_layout():
	var damage_amount_input: HBoxContainer = Utils.create_float_input_field("Aura amount:",
		func(value: float): aura_card_data.amount = value)
	content.add_child(damage_amount_input)

func create_buff_input_layout():
	var damage_amount_input: HBoxContainer = Utils.create_float_input_field("Buff amount:",
		func(value: float): buff_card_data.amount = value)
	content.add_child(damage_amount_input)
	
func set_target_cells(positions: Array[Vector2], origin: Vector2):
	base_card_data.target_cells.clear()
	for pos in positions:
		base_card_data.target_cells.append(pos - origin)
	print(positions)
	print(base_card_data.target_cells)
	
	
	
	
	
	
	
	
	
	
	
