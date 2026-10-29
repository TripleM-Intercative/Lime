@tool
class_name Utils
extends RefCounted

const INT_MAX: int = 9223372036854775807
const CARD_IMAGE_FOLDER_PATH: String = "res://assets/images/cards/"
const DEFAULT_CARD_IMAGE: String = "res://assets/default_card_image.png"
const CARD_SCRIPT_PATH: String = "res://scripts/cards/"

static func safe_image_to_assets(source: String, save_name: String) -> String:
	var full_path: String = CARD_IMAGE_FOLDER_PATH + save_name.to_lower().to_snake_case() + "_tex.png"
	
	if not FileAccess.file_exists(source):
		print("Error: Source file not found at: ", source)
		return DEFAULT_CARD_IMAGE
		
	if not DirAccess.dir_exists_absolute(CARD_IMAGE_FOLDER_PATH):
		DirAccess.make_dir_recursive_absolute(CARD_IMAGE_FOLDER_PATH)
		
	var error = DirAccess.copy_absolute(source, full_path)
	
	if error == OK:
		
		if Engine.is_editor_hint():
			var fs: EditorFileSystem = EditorInterface.get_resource_filesystem()
			fs.update_file(full_path)
			fs.reimport_files(PackedStringArray([full_path]))
		
		return full_path
	else:
		print("Failed to copy file. Error code: ", error)
		return DEFAULT_CARD_IMAGE

static func create_card_script(card_name: String, resource_path: String) -> String:
	var full_path: String = CARD_SCRIPT_PATH + card_name.to_snake_case() + "_card.gd"

	if not DirAccess.dir_exists_absolute(CARD_SCRIPT_PATH):
		DirAccess.make_dir_recursive_absolute(CARD_SCRIPT_PATH)

	var file: FileAccess = FileAccess.open(full_path, FileAccess.WRITE)
	if file == null:
		print("Failed to create card script. Error code: ", FileAccess.get_open_error())
		return ""
	
	var parent_card_class: String = "CardBase"
	
	var new_script_class_name: String = card_name.to_pascal_case()

	file.store_string("extends " + parent_card_class + "\nclass_name " + new_script_class_name + "\n\nfunc _init() -> void:\n\tcard_data = preload(\"%s\")\n" % resource_path)
	file.close()

	if Engine.is_editor_hint():
		EditorInterface.get_resource_filesystem().update_file(full_path)

	return full_path

static func create_float_input_field(text: String, on_value_changed: Callable) -> HBoxContainer:
	var container: HBoxContainer = HBoxContainer.new()
	var input_text: Label = Label.new()
	var input_field: SpinBox = SpinBox.new()
	
	input_text.text = text
	input_field.min_value = 0
	input_field.max_value = INT_MAX
	input_field.step = 0.1
	
	input_field.value_changed.connect(on_value_changed)
	
	container.add_child(input_text)
	container.add_child(input_field)
	
	return container

static func create_bool_input_field(text: String, on_value_changed: Callable) -> HBoxContainer:
	var container: HBoxContainer = HBoxContainer.new()
	var checkbox: CheckBox = CheckBox.new()
	var input_text: Label = Label.new()
	
	input_text.text = text
	checkbox.toggled.connect(on_value_changed)
	
	container.add_child(input_text)
	container.add_child(checkbox)
	
	return container
	
	
static func create_dropdown_input_with_enum(options, text: String, on_value_changed: Callable) -> VBoxContainer:
	var container: VBoxContainer = VBoxContainer.new()
	var dropdown: OptionButton = OptionButton.new()
	var input_text: Label = Label.new()
	
	input_text.text = text
	dropdown.item_selected.connect(on_value_changed)
	
	for option in options.keys():
		dropdown.add_item(option)
	
	container.add_child(input_text)
	container.add_child(dropdown)
	
	return container
	
static func create_int_input_field(text: String, on_value_changed: Callable) -> HBoxContainer:
	var container: HBoxContainer = HBoxContainer.new()
	var input_text: Label = Label.new()
	var input_field: SpinBox = SpinBox.new()
	
	input_text.text = text
	input_field.min_value = 0
	input_field.max_value = INT_MAX
	input_field.step = 1
	
	input_field.value_changed.connect(on_value_changed)
	
	container.add_child(input_text)
	container.add_child(input_field)
	
	return container
	
	
	
	
	
	
	
