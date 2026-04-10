@tool
extends ConfirmationDialog
## Dialog for choosing which Godot lifecycle function a new top-level event maps to.
## Students pick one lifecycle hook, then add their conditions and actions as sub-events.
## This mirrors the structure of a GDScript file (_ready, _process, _physics_process).

const _LIFECYCLE_OPTIONS := [
	{
		"label": "🟢  _ready()  —  On game start (runs once)",
		"key": "lifecycle_ready",
		"hint": "Like _ready() in GDScript. Code here runs once when the scene first loads.",
	},
	{
		"label": "🔵  _process(delta)  —  Every frame (continuous)",
		"key": "lifecycle_process",
		"hint": "Like _process(delta) in GDScript. Code here runs every frame — great for input and movement.",
	},
	{
		"label": "🟣  _physics_process(delta)  —  Every physics frame",
		"key": "lifecycle_physics",
		"hint": "Like _physics_process(delta) in GDScript. Code here runs every physics step — use for physics bodies.",
	},
]

var _selected_key: String = ""
var _hint_label: Label


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
	min_size = Vector2i(520, 360)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 12)
	add_child(root)

	var header := Label.new()
	header.text = "Choose a Lifecycle Function"
	header.add_theme_font_size_override("font_size", 16)
	root.add_child(header)

	var description := Label.new()
	description.text = (
		"Every top-level event is a lifecycle block — just like functions in GDScript.\n"
		+ "Add conditions and actions inside the block as sub-events."
	)
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.add_theme_color_override("font_color", Color(0.75, 0.75, 0.75))
	root.add_child(description)

	var sep := HSeparator.new()
	root.add_child(sep)

	var btn_group := ButtonGroup.new()

	for option in _LIFECYCLE_OPTIONS:
		var hbox := HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 8)
		root.add_child(hbox)

		var radio := CheckButton.new()
		radio.button_group = btn_group
		radio.toggle_mode = true
		radio.text = option["label"]
		radio.add_theme_font_size_override("font_size", 13)
		radio.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var key: String = option["key"]
		var hint: String = option["hint"]
		radio.toggled.connect(func(pressed: bool):
			if pressed:
				_selected_key = key
				_hint_label.text = hint
		)
		hbox.add_child(radio)

	var hint_sep := HSeparator.new()
	root.add_child(hint_sep)

	_hint_label = Label.new()
	_hint_label.text = "← Select a lifecycle function above."
	_hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint_label.add_theme_color_override("font_color", Color(0.65, 0.85, 1.0))
	root.add_child(_hint_label)
