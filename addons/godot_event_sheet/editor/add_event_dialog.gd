@tool
extends ConfirmationDialog
## Combined "When → Then" dialog for adding events to the event sheet.
## Presents a simple cause-and-effect model: pick a trigger and a reaction
## in a single step, so students see the full event at once.

# Categorized trigger types.
const TRIGGER_CATEGORIES := [
	{
		"label": "🎮 Input",
		"items": [
			{"label": "When a key/button is pressed", "key": "input_pressed"},
			{"label": "When a key/button is released", "key": "input_released"},
			{"label": "While a key/button is held down", "key": "input_held"},
			{"label": "When any key is pressed", "key": "input_any_pressed"},
			{"label": "When any key is released", "key": "input_any_released"},
			{"label": "When a UI button is clicked", "key": "ui_button_pressed"},
			{"label": "When a joypad stick is pushed", "key": "joypad_axis"},
			{"label": "When a joypad button is pressed", "key": "joypad_button_pressed"},
			{"label": "When a joypad button is released", "key": "joypad_button_released"},
			{"label": "While a joypad button is held", "key": "joypad_button_held"},
			{"label": "When a joypad is connected", "key": "joypad_connected"},
		]
	},
	{
		"label": "⏱ Lifecycle",
		"items": [
			{"label": "Every Frame (continuous)", "key": "lifecycle_process"},
			{"label": "Every Physics Step", "key": "lifecycle_physics"},
			{"label": "On Start of Scene (once)", "key": "lifecycle_ready"},
		]
	},
	{
		"label": "💥 Collision",
		"items": [
			{"label": "When a body collides (entered)", "key": "collision_body_entered"},
			{"label": "When a body stops colliding (exited)", "key": "collision_body_exited"},
			{"label": "When an area is entered", "key": "collision_area_entered"},
			{"label": "When an area is exited", "key": "collision_area_exited"},
			{"label": "While an object is overlapping (floor switch)", "key": "collision_is_overlapping"},
		]
	},
	{
		"label": "🏃 Physics",
		"items": [
			{"label": "When the player is on the floor", "key": "physics_on_floor"},
			{"label": "When the player is on a wall", "key": "physics_on_wall"},
			{"label": "When the player is on a ceiling", "key": "physics_on_ceiling"},
			{"label": "When the player is moving", "key": "physics_is_moving"},
			{"label": "When the player is stopped", "key": "physics_is_stopped"},
			{"label": "When the player is falling", "key": "physics_is_falling"},
		]
	},
	{
		"label": "📡 Signals",
		"items": [
			{"label": "When a signal is received", "key": "signal_received"},
		]
	},
	{
		"label": "📦 Properties",
		"items": [
			{"label": "When a property matches a value", "key": "property_compare"},
		]
	},
	{
		"label": "⏲ Timers",
		"items": [
			{"label": "When a timer fires (repeating)", "key": "timer_repeat"},
			{"label": "When a timer fires (once)", "key": "timer_oneshot"},
		]
	},
	{
		"label": "🎲 Utility",
		"items": [
			{"label": "When a random chance succeeds", "key": "random_chance"},
			{"label": "When the distance between nodes matches", "key": "distance_check"},
			{"label": "When a node is in a group", "key": "group_check"},
			{"label": "When the count of nodes in a group matches", "key": "node_count"},
		]
	},
	{
		"label": "🔀 Game State (Phases)",
		"items": [
			{"label": "When the game state matches a value", "key": "state_check"},
		]
	},
	{
		"label": "📊 Counters & Flags",
		"items": [
			{"label": "When a variable matches a value", "key": "variable_compare"},
			{"label": "When an array variable contains a value", "key": "variable_contains"},
		]
	},
	{
		"label": "🖱 Hover & Click",
		"items": [
			{"label": "When the mouse enters an object", "key": "hover_mouse_entered"},
			{"label": "When the mouse leaves an object", "key": "hover_mouse_exited"},
			{"label": "While the mouse is over an object", "key": "hover_is_hovered"},
			{"label": "When a game object is clicked", "key": "click_object"},
			{"label": "When a game object click is released", "key": "click_object_released"},
		]
	},
	{
		"label": "🎬 Animation",
		"items": [
			{"label": "When an animation finishes", "key": "animation_finished"},
		]
	},
	{
		"label": "👁 Visibility",
		"items": [
			{"label": "When an object appears on screen", "key": "visibility_screen_entered"},
			{"label": "When an object leaves the screen", "key": "visibility_screen_exited"},
			{"label": "While an object is on screen", "key": "visibility_is_on_screen"},
		]
	},
	{
		"label": "🌳 Scene Tree",
		"items": [
			{"label": "When an object is added to the scene", "key": "tree_enter"},
			{"label": "When an object is removed from the scene", "key": "tree_exit"},
			{"label": "When a child object is added", "key": "tree_child_entered"},
			{"label": "When a child object is removed", "key": "tree_child_exiting"},
		]
	},
]

# Categorized reaction types.
const REACTION_CATEGORIES := [
	{
		"label": "🏃 Movement",
		"items": [
			{"label": "Move the object", "key": "move_translate"},
			{"label": "Set the object's position", "key": "move_set_position"},
			{"label": "Move toward a point", "key": "move_toward"},
			{"label": "Move toward another object (chase)", "key": "move_toward_node"},
			{"label": "Set velocity (physics movement)", "key": "move_velocity"},
			{"label": "Apply gravity (platformer physics)", "key": "gravity"},
			{"label": "Knock back an object", "key": "knockback"},
			{"label": "Rotate / aim the object", "key": "rotate"},
			{"label": "Pathfind toward a target (A*)", "key": "pathfind"},
		]
	},
	{
		"label": "📦 Properties",
		"items": [
			{"label": "Set a property", "key": "prop_set"},
			{"label": "Add to a property", "key": "prop_add"},
			{"label": "Subtract from a property", "key": "prop_subtract"},
			{"label": "Multiply a property", "key": "prop_multiply"},
			{"label": "Divide a property", "key": "prop_divide"},
			{"label": "Toggle a property (on/off)", "key": "prop_toggle"},
			{"label": "Clamp a property (min/max)", "key": "prop_clamp"},
		]
	},
	{
		"label": "🎬 Animation & Audio",
		"items": [
			{"label": "Play an animation", "key": "anim_play"},
			{"label": "Stop an animation", "key": "anim_stop"},
			{"label": "Play a sound", "key": "sound_play"},
			{"label": "Stop a sound", "key": "sound_stop"},
		]
	},
	{
		"label": "🎭 Scene",
		"items": [
			{"label": "Create (spawn) a scene", "key": "scene_create"},
			{"label": "Destroy a node", "key": "scene_destroy"},
			{"label": "Change to a different scene", "key": "scene_change"},
			{"label": "Show a node", "key": "scene_show"},
			{"label": "Hide a node", "key": "scene_hide"},
			{"label": "Pause the game (tree)", "key": "scene_pause"},
			{"label": "Unpause the game (tree)", "key": "scene_unpause"},
		]
	},
	{
		"label": "📡 Signals",
		"items": [
			{"label": "Emit a signal", "key": "emit_signal"},
		]
	},
	{
		"label": "🔧 Methods",
		"items": [
			{"label": "Call a method on a node", "key": "call_method"},
		]
	},
	{
		"label": "🐛 Debug",
		"items": [
			{"label": "Print a debug message", "key": "debug_print"},
		]
	},
	{
		"label": "🔀 Game State (Phases)",
		"items": [
			{"label": "Set a game state", "key": "state_set"},
			{"label": "Clear a game state", "key": "state_clear"},
		]
	},
	{
		"label": "⏲ Timing",
		"items": [
			{"label": "Wait (delay) before next actions", "key": "wait"},
			{"label": "Repeat actions N times", "key": "repeat"},
		]
	},
	{
		"label": "📊 Counters & Flags",
		"items": [
			{"label": "Set a variable", "key": "var_set"},
			{"label": "Add to a variable", "key": "var_add"},
			{"label": "Subtract from a variable", "key": "var_subtract"},
			{"label": "Multiply a variable", "key": "var_multiply"},
			{"label": "Divide a variable", "key": "var_divide"},
			{"label": "Toggle a variable (on/off)", "key": "var_toggle"},
			{"label": "Append to a variable array", "key": "var_append"},
			{"label": "Remove from a variable array", "key": "var_remove"},
			{"label": "Clear a variable array", "key": "var_clear_array"},
		]
	},
	{
		"label": "📷 Camera",
		"items": [
			{"label": "Camera: Follow a target", "key": "camera_follow"},
			{"label": "Camera: Set zoom level", "key": "camera_zoom"},
			{"label": "Camera: Shake the camera", "key": "camera_shake"},
		]
	},
	{
		"label": "🎲 Utility",
		"items": [
			{"label": "Set a random value", "key": "random_float"},
			{"label": "Add a node to a group", "key": "group_add"},
			{"label": "Remove a node from a group", "key": "group_remove"},
		]
	},
]

var _trigger_list: Tree
var _reaction_list: Tree
var _trigger_item_to_key: Dictionary = {}
var _reaction_item_to_key: Dictionary = {}
var _trigger_props: VBoxContainer
var _reaction_props: VBoxContainer

var _selected_condition: ESCondition = null
var _selected_action: ESAction = null

## Reference to the current EventController used by node pickers in sub-dialogs.
var _controller: Node = null

## When true, the Lifecycle trigger category is hidden (lifecycle events must be top-level).
var _is_sub_event: bool = false

# Helpers kept alive so their UI callbacks (which may reference self) remain valid.
var _cond_helper = null
var _action_helper = null

# Preload scripts for creating conditions and actions.
const ConditionDialog := preload("res://addons/godot_event_sheet/editor/condition_dialog.gd")
const ActionDialog := preload("res://addons/godot_event_sheet/editor/action_dialog.gd")


## Create and return a new "Add Event" dialog ready to show.
## Pass is_sub_event=true when adding sub-events so lifecycle triggers are hidden.
static func create(controller: Node = null, is_sub_event: bool = false) -> ConfirmationDialog:
	var dialog := preload("res://addons/godot_event_sheet/editor/add_event_dialog.gd").new()
	dialog.title = "Add Sub-Event" if is_sub_event else "Add New Event"
	dialog._controller = controller
	dialog._is_sub_event = is_sub_event
	dialog.ok_button_text = "Create Event"
	dialog._build_ui()
	return dialog


## Return the condition selected by the user (or null).
func get_selected_condition() -> ESCondition:
	return _selected_condition


## Return the action selected by the user (or null).
func get_selected_action() -> ESAction:
	return _selected_action


## Build the full dialog layout.
func _build_ui() -> void:
	min_size = Vector2i(800, 500)
	max_size = Vector2i(900, 650)

	var root := VBoxContainer.new()
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(root)

	# ===== TRIGGER SECTION =====
	var trigger_header := Label.new()
	trigger_header.text = "📋  WHEN this happens (trigger):"
	trigger_header.add_theme_font_size_override("font_size", 15)
	root.add_child(trigger_header)

	var trigger_split := HBoxContainer.new()
	trigger_split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(trigger_split)

	_trigger_list = Tree.new()
	_trigger_list.custom_minimum_size = Vector2(280, 0)
	_trigger_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_trigger_list.hide_root = true
	trigger_split.add_child(_trigger_list)

	_trigger_props = VBoxContainer.new()
	_trigger_props.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_trigger_props.size_flags_vertical = Control.SIZE_EXPAND_FILL
	trigger_split.add_child(_trigger_props)

	# Build trigger tree.
	_trigger_item_to_key.clear()
	var trigger_root := _trigger_list.create_item()
	for cat in TRIGGER_CATEGORIES:
		# Callback-based triggers (those driven by their own Godot function/signal)
		# are only valid as top-level starting events — hide them in sub-events.
		if _is_sub_event and cat["label"] in [
			"⏱ Lifecycle", "💥 Collision", "📡 Signals", "⏲ Timers",
			"🖱 Hover & Click", "🎬 Animation", "👁 Visibility", "🌳 Scene Tree"]:
			continue
		var cat_item := _trigger_list.create_item(trigger_root)
		cat_item.set_text(0, cat["label"])
		cat_item.set_selectable(0, false)
		cat_item.set_custom_bg_color(0, Color(0.15, 0.17, 0.22))
		# Collapse categories by default so the dialog fits on screen.
		cat_item.collapsed = true
		for entry in cat["items"]:
			var child := _trigger_list.create_item(cat_item)
			child.set_text(0, "  " + entry["label"])
			_trigger_item_to_key[child] = entry["key"]
	_trigger_list.item_selected.connect(_on_trigger_selected)

	# Separator between sections.
	var sep := HSeparator.new()
	root.add_child(sep)

	# ===== REACTION SECTION =====
	var reaction_header := Label.new()
	reaction_header.text = "⚡  THEN do this (reaction):"
	reaction_header.add_theme_font_size_override("font_size", 15)
	root.add_child(reaction_header)

	var reaction_split := HBoxContainer.new()
	reaction_split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(reaction_split)

	_reaction_list = Tree.new()
	_reaction_list.custom_minimum_size = Vector2(280, 0)
	_reaction_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_reaction_list.hide_root = true
	reaction_split.add_child(_reaction_list)

	_reaction_props = VBoxContainer.new()
	_reaction_props.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_reaction_props.size_flags_vertical = Control.SIZE_EXPAND_FILL
	reaction_split.add_child(_reaction_props)

	# Build reaction tree.
	_reaction_item_to_key.clear()
	var reaction_root := _reaction_list.create_item()
	for cat in REACTION_CATEGORIES:
		var cat_item := _reaction_list.create_item(reaction_root)
		cat_item.set_text(0, cat["label"])
		cat_item.set_selectable(0, false)
		cat_item.set_custom_bg_color(0, Color(0.15, 0.17, 0.22))
		# Collapse categories by default so the dialog fits on screen.
		cat_item.collapsed = true
		for entry in cat["items"]:
			var child := _reaction_list.create_item(cat_item)
			child.set_text(0, "  " + entry["label"])
			_reaction_item_to_key[child] = entry["key"]
	_reaction_list.item_selected.connect(_on_reaction_selected)


## When a trigger type is selected, create the condition and show its property editors.
func _on_trigger_selected() -> void:
	var selected := _trigger_list.get_selected()
	if not selected or not _trigger_item_to_key.has(selected):
		return  # Category header selected — ignore.

	var key: String = _trigger_item_to_key[selected]

	for child in _trigger_props.get_children():
		child.queue_free()

	# Free the previous helper now that its UI children are being removed.
	if _cond_helper:
		_cond_helper.queue_free()
		_cond_helper = null

	# Use condition_dialog factory to create the condition and build its UI.
	var helper := ConditionDialog.new()
	helper._controller = _controller
	_selected_condition = helper.create_condition_from_key(key)
	if _selected_condition:
		helper.build_property_fields(_trigger_props, _selected_condition)
	# Keep the helper alive while its UI callbacks may reference it.
	_cond_helper = helper


## When a reaction type is selected, create the action and show its property editors.
func _on_reaction_selected() -> void:
	var selected := _reaction_list.get_selected()
	if not selected or not _reaction_item_to_key.has(selected):
		return  # Category header selected — ignore.

	var key: String = _reaction_item_to_key[selected]

	for child in _reaction_props.get_children():
		child.queue_free()

	# Free the previous helper now that its UI children are being removed.
	if _action_helper:
		_action_helper.queue_free()
		_action_helper = null

	# Use action_dialog factory to create the action and build its UI.
	var helper := ActionDialog.new()
	helper._controller = _controller
	_selected_action = helper.create_action_from_key(key)
	if _selected_action:
		helper.build_property_fields(_reaction_props, _selected_action)
	# Keep the helper alive while its UI callbacks may reference it.
	_action_helper = helper


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		if _cond_helper:
			_cond_helper.queue_free()
			_cond_helper = null
		if _action_helper:
			_action_helper.queue_free()
			_action_helper = null
