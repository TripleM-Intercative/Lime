extends CanvasLayer

var _tabs: TabContainer
var _sections := {}

func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	var panel := PanelContainer.new()
	panel.position = Vector2(10, 10)
	add_child(panel)
	_tabs = TabContainer.new()
	_tabs.custom_minimum_size = Vector2(260, 0)
	panel.add_child(_tabs)
	visible = false
	if !OS.is_debug_build():
		set_process_unhandled_input(false)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey && event.pressed && !event.echo && event.keycode == KEY_F3:
		visible = !visible

# Optionaler Parameter group: leer = automatisch aus der Klasse von owner_node
func add_button(text: String, action: Callable, owner_node: Node = null, group := "") -> void:
	var b := Button.new()
	b.text = text
	b.pressed.connect(action)
	_add(b, owner_node, group)

func add_toggle(text: String, value: bool, on_change: Callable, owner_node: Node = null, group := "") -> void:
	var c := CheckBox.new()
	c.text = text
	c.button_pressed = value
	c.toggled.connect(on_change)
	_add(c, owner_node, group)

func add_slider(text: String, min_v: float, max_v: float, value: float, on_change: Callable, owner_node: Node = null, group := "") -> void:
	var row := VBoxContainer.new()
	var label := Label.new()
	label.text = "%s: %.2f" % [text, value]
	var s := HSlider.new()
	s.min_value = min_v
	s.max_value = max_v
	s.step = 0.01
	s.value = value
	s.custom_minimum_size.x = 200
	s.value_changed.connect(func(v):
		label.text = "%s: %.2f" % [text, v]
		on_change.call(v))
	row.add_child(label)
	row.add_child(s)
	_add(row, owner_node, group)

func _group_name(owner_node: Node) -> String:
	if owner_node == null:
		return "Allgemein"
	var script: Script = owner_node.get_script()
	if script:
		var global_name := script.get_global_name()
		if global_name != &"":
			return global_name
		return script.resource_path.get_file().get_basename()
	return owner_node.get_class()

func _get_section(group: String) -> VBoxContainer:
	if !_sections.has(group):
		var box := VBoxContainer.new()
		box.name = group 
		_tabs.add_child(box)
		_sections[group] = box
	return _sections[group]

func _add(c: Control, owner_node: Node, group: String) -> void:
	if group == "":
		group = _group_name(owner_node)
	_get_section(group).add_child(c)
	if owner_node:
		owner_node.tree_exiting.connect(func():
			if is_instance_valid(c):
				c.queue_free()
			_cleanup.call_deferred(group), CONNECT_ONE_SHOT)

func _cleanup(group: String) -> void:
	var box: VBoxContainer = _sections.get(group)
	if box && box.get_children().all(func(ch): return ch.is_queued_for_deletion()):
		box.queue_free()
		_sections.erase(group)
