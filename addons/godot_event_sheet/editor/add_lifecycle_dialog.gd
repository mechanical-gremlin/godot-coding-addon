@tool
extends ConfirmationDialog
## Dialog for choosing which Godot lifecycle event a new top-level event maps to.
## Students pick one lifecycle hook, then add their conditions and actions as sub-events.

const _LIFECYCLE_OPTIONS := [
	{
		"label": "🟢  On Start of Scene (runs once)",
		"key": "lifecycle_ready",
		"hint": "Runs once when the scene first loads. Use for setup and initialization.",
	},
	{
		"label": "🔵  Every Frame (continuous)",
		"key": "lifecycle_process",
		"hint": "Runs every frame continuously. Great for input, movement, and game logic.",
	},
	{
		"label": "🟣  Every Physics Step",
		"key": "lifecycle_physics",
		"hint": "Runs at a fixed rate for physics. Use for physics bodies and collisions.",
	},
]

var _selected_key: String = ""
var _hint_label: Label
var _item_list: ItemList
var _item_keys: Array[String] = []


## Create and return a ready-to-show lifecycle dialog.
static func create() -> ConfirmationDialog:
	var dialog := preload("res://addons/godot_event_sheet/editor/add_lifecycle_dialog.gd").new()
	dialog.title = "Add Lifecycle Event"
	dialog.ok_button_text = "Create Lifecycle Block"
	dialog._build_ui()
	return dialog


## Return the key of the selected lifecycle type ("lifecycle_ready", "lifecycle_process",
## or "lifecycle_physics"), or an empty string if none was chosen.
func get_selected_key() -> String:
	return _selected_key


## Build the dialog layout.
func _build_ui() -> void:
	min_size = Vector2i(420, 260)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 8)
	add_child(root)

	var header := Label.new()
	header.text = "Choose a Lifecycle Event"
	header.add_theme_font_size_override("font_size", 16)
	root.add_child(header)

	var sep := HSeparator.new()
	root.add_child(sep)

	_item_list = ItemList.new()
	_item_list.custom_minimum_size = Vector2(0, 100)
	_item_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_item_list.auto_height = true
	_item_list.add_theme_font_size_override("font_size", 14)
	root.add_child(_item_list)

	_item_keys.clear()
	for option in _LIFECYCLE_OPTIONS:
		_item_list.add_item(option["label"])
		_item_keys.append(option["key"])

	_item_list.item_selected.connect(_on_item_selected)

	var hint_sep := HSeparator.new()
	root.add_child(hint_sep)

	_hint_label = Label.new()
	_hint_label.text = "Select a lifecycle event above."
	_hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint_label.add_theme_color_override("font_color", Color(0.65, 0.85, 1.0))
	root.add_child(_hint_label)


func _on_item_selected(index: int) -> void:
	_selected_key = _item_keys[index]
	_hint_label.text = _LIFECYCLE_OPTIONS[index]["hint"]
