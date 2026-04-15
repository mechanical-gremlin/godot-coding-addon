@tool
extends ConfirmationDialog
## Dialog for choosing which Godot callback function a new top-level event block maps to.
## Users pick a callback (lifecycle, collision, signal, timer, or UI button),
## configure its properties, then add sub-events with conditions and actions.

# Categorized callback function options available as event block starters.
const _CALLBACK_CATEGORIES := [
	{
		"label": "⏱ Lifecycle",
		"items": [
			{"label": "On Start of Scene (runs once)", "key": "lifecycle_ready",
			 "hint": "Runs once when the scene first loads. Use for setup and initialization."},
			{"label": "Every Frame (continuous)", "key": "lifecycle_process",
			 "hint": "Runs every frame continuously. Great for input, movement, and game logic."},
			{"label": "Every Physics Step", "key": "lifecycle_physics",
			 "hint": "Runs at a fixed rate for physics. Use for physics bodies and collisions."},
		]
	},
	{
		"label": "💥 Collision",
		"items": [
			{"label": "When a body collides (entered)", "key": "collision_body_entered",
			 "hint": "Fires once when a physics body first enters the collision area."},
			{"label": "When a body stops colliding (exited)", "key": "collision_body_exited",
			 "hint": "Fires once when a physics body leaves the collision area."},
			{"label": "When an area is entered", "key": "collision_area_entered",
			 "hint": "Fires once when another Area2D/3D enters this area."},
			{"label": "When an area is exited", "key": "collision_area_exited",
			 "hint": "Fires once when another Area2D/3D exits this area."},
			{"label": "While an object is overlapping", "key": "collision_is_overlapping",
			 "hint": "True every frame while a body or area is overlapping. Great for floor switches."},
		]
	},
	{
		"label": "📡 Signals",
		"items": [
			{"label": "When a signal is received", "key": "signal_received",
			 "hint": "Fires when a custom signal is emitted by a node. Good for health_changed, died, etc."},
		]
	},
	{
		"label": "⏲ Timers",
		"items": [
			{"label": "When a timer fires (repeating)", "key": "timer_repeat",
			 "hint": "Fires at a regular interval. Great for spawning enemies, ticking damage, etc."},
			{"label": "When a timer fires (once)", "key": "timer_oneshot",
			 "hint": "Fires once after a delay. Good for delayed effects or one-time triggers."},
		]
	},
	{
		"label": "🎮 UI Button",
		"items": [
			{"label": "When a UI button is clicked", "key": "ui_button_pressed",
			 "hint": "Fires once when a Button node in the UI is pressed by the player."},
		]
	},
]

var _selected_key: String = ""
var _selected_condition: ESCondition = null
var _hint_label: Label
var _tree: Tree
var _tree_item_to_key: Dictionary = {}
var _tree_item_to_hint: Dictionary = {}
var _props_container: VBoxContainer

## Reference to the current EventController used by node pickers in sub-dialogs.
var _controller: Node = null

# Helper kept alive so its UI callbacks remain valid.
var _cond_helper = null

# Preload scripts for creating conditions.
const ConditionDialog := preload("res://addons/godot_event_sheet/editor/condition_dialog.gd")


## Create and return a ready-to-show event block dialog.
static func create(controller: Node = null) -> ConfirmationDialog:
	var dialog := preload("res://addons/godot_event_sheet/editor/add_lifecycle_dialog.gd").new()
	dialog.title = "Add Event Block"
	dialog.ok_button_text = "Create Event Block"
	dialog._controller = controller
	dialog._build_ui()
	return dialog


## Return the key of the selected callback type, or an empty string if none was chosen.
func get_selected_key() -> String:
	return _selected_key


## Return the configured condition for the selected callback (or null).
func get_selected_condition() -> ESCondition:
	return _selected_condition


## Build the dialog layout.
func _build_ui() -> void:
	min_size = Vector2i(580, 380)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 8)
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(root)

	var header := Label.new()
	header.text = "Choose a Callback Function for this Event Block"
	header.add_theme_font_size_override("font_size", 15)
	root.add_child(header)

	var sep := HSeparator.new()
	root.add_child(sep)

	# Horizontal split: tree on left, properties + hint on right.
	var split := HBoxContainer.new()
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(split)

	# -- Left: categorized callback tree --
	_tree = Tree.new()
	_tree.custom_minimum_size = Vector2(260, 0)
	_tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_tree.hide_root = true
	split.add_child(_tree)

	_tree_item_to_key.clear()
	_tree_item_to_hint.clear()
	var tree_root := _tree.create_item()
	for cat in _CALLBACK_CATEGORIES:
		var cat_item := _tree.create_item(tree_root)
		cat_item.set_text(0, cat["label"])
		cat_item.set_selectable(0, false)
		cat_item.set_custom_bg_color(0, Color(0.15, 0.17, 0.22))
		for entry in cat["items"]:
			var child := _tree.create_item(cat_item)
			child.set_text(0, "  " + entry["label"])
			_tree_item_to_key[child] = entry["key"]
			_tree_item_to_hint[child] = entry["hint"]
	_tree.item_selected.connect(_on_item_selected)

	# Vertical separator.
	var vsep := VSeparator.new()
	split.add_child(vsep)

	# -- Right: hint + properties --
	var right_panel := VBoxContainer.new()
	right_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.add_child(right_panel)

	_hint_label = Label.new()
	_hint_label.text = "← Select a callback function on the left."
	_hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint_label.add_theme_color_override("font_color", Color(0.65, 0.85, 1.0))
	right_panel.add_child(_hint_label)

	var prop_sep := HSeparator.new()
	right_panel.add_child(prop_sep)

	_props_container = VBoxContainer.new()
	_props_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_props_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_panel.add_child(_props_container)


func _on_item_selected() -> void:
	var selected := _tree.get_selected()
	if not selected or not _tree_item_to_key.has(selected):
		return

	_selected_key = _tree_item_to_key[selected]
	_hint_label.text = _tree_item_to_hint[selected]

	# Clear previous property fields.
	for child in _props_container.get_children():
		child.queue_free()

	# Free the previous helper.
	if _cond_helper:
		_cond_helper.queue_free()
		_cond_helper = null

	# Create the condition and build its property fields.
	var helper := ConditionDialog.new()
	helper._controller = _controller
	_selected_condition = helper.create_condition_from_key(_selected_key)
	if _selected_condition:
		# Lifecycle conditions have no user-facing properties, so skip fields for them.
		if not _selected_key.begins_with("lifecycle_"):
			helper.build_property_fields(_props_container, _selected_condition)
	_cond_helper = helper


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		if _cond_helper:
			_cond_helper.queue_free()
			_cond_helper = null
