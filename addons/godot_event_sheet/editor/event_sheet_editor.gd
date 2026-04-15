@tool
extends VBoxContainer
## Main Event Sheet editor panel that appears in the Godot editor's bottom panel.
## Provides a visual interface for creating and editing events, conditions, and actions.

var editor_interface: EditorInterface = null
var undo_redo: EditorUndoRedoManager = null

var _current_controller: Node = null
var _current_sheet: ESEventSheet = null

# Rename-tracking state (editor-only).
var _rename_connected_nodes: Array[Node] = []
var _node_path_snapshot: Dictionary = {}  # instance_id (int) -> old path (String)

# UI references.
var _toolbar: HBoxContainer
var _scroll: ScrollContainer
var _events_container: VBoxContainer
var _no_sheet_label: Label
var _sheet_name_edit: LineEdit

const _NO_SHEET_TEXT := "Select an EventController node to edit its Event Sheet.\n\nTo get started:\n1. Add an EventController node as a child of your game object\n2. Click the EventController node to open this editor\n3. Click '+ Add Event Block' to create your first event"

# $collider is a runtime-only synthetic path injected by event_controller.gd during
# collision callbacks; it never resolves as a real scene node, so we skip it.
const _RUNTIME_SYNTHETIC_PATH := "$collider"

# Preloaded dialog scripts.
const ConditionDialog := preload("res://addons/godot_event_sheet/editor/condition_dialog.gd")
const ActionDialog := preload("res://addons/godot_event_sheet/editor/action_dialog.gd")
const AddEventDialog := preload("res://addons/godot_event_sheet/editor/add_event_dialog.gd")
const AddLifecycleDialog := preload("res://addons/godot_event_sheet/editor/add_lifecycle_dialog.gd")
const ESLifecycleCondition := preload("res://addons/godot_event_sheet/conditions/lifecycle_condition.gd")
const ESCollisionCondition := preload("res://addons/godot_event_sheet/conditions/collision_condition.gd")
const ESSignalCondition := preload("res://addons/godot_event_sheet/conditions/signal_condition.gd")
const ESTimerCondition := preload("res://addons/godot_event_sheet/conditions/timer_condition.gd")
const ESButtonCondition := preload("res://addons/godot_event_sheet/conditions/button_condition.gd")


func _ready() -> void:
	_build_ui()
	_refresh()


## Called by the plugin when an EventController is selected.
func edit_controller(controller: Node) -> void:
	if Engine.is_editor_hint():
		_disconnect_rename_signals()
	_current_controller = controller
	if controller and "event_sheet" in controller:
		_current_sheet = controller.get("event_sheet") as ESEventSheet
		# Auto-create an EventSheet if none exists (1-step setup).
		if _current_sheet == null:
			_current_sheet = ESEventSheet.new()
			_current_sheet.sheet_name = controller.name + " Events"
			controller.set("event_sheet", _current_sheet)
			_save_sheet()
			print("EventSheet: Auto-created a new Event Sheet for '%s'. Ready to add events!" % controller.name)
	else:
		_current_sheet = null
	_refresh()
	if Engine.is_editor_hint():
		_connect_rename_signals()
		_snapshot_node_paths()


## Build the entire editor UI programmatically.
func _build_ui() -> void:
	name = "EventSheetEditor"
	custom_minimum_size = Vector2(0, 300)

	# -- Toolbar --
	_toolbar = HBoxContainer.new()
	_toolbar.add_theme_constant_override("separation", 8)
	add_child(_toolbar)

	# Sheet name.
	var name_label := Label.new()
	name_label.text = "Event Sheet:"
	_toolbar.add_child(name_label)

	_sheet_name_edit = LineEdit.new()
	_sheet_name_edit.placeholder_text = "Sheet Name"
	_sheet_name_edit.custom_minimum_size.x = 200
	_sheet_name_edit.text_submitted.connect(_on_sheet_name_changed)
	_toolbar.add_child(_sheet_name_edit)

	# Spacer.
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_toolbar.add_child(spacer)

	# Collapse All button.
	var collapse_all_btn := Button.new()
	collapse_all_btn.text = "▶ Collapse All"
	collapse_all_btn.tooltip_text = "Collapse all events"
	collapse_all_btn.pressed.connect(func():
		if not _current_sheet:
			return
		for evt in _current_sheet.events:
			var item := evt as ESEventItem
			if item:
				item.collapsed = true
		_mark_resource_modified()
		_refresh()
	)
	_toolbar.add_child(collapse_all_btn)

	# Expand All button.
	var expand_all_btn := Button.new()
	expand_all_btn.text = "▼ Expand All"
	expand_all_btn.tooltip_text = "Expand all events"
	expand_all_btn.pressed.connect(func():
		if not _current_sheet:
			return
		for evt in _current_sheet.events:
			var item := evt as ESEventItem
			if item:
				item.collapsed = false
		_mark_resource_modified()
		_refresh()
	)
	_toolbar.add_child(expand_all_btn)

	# Add Event Block button.
	var add_event_btn := Button.new()
	add_event_btn.text = "+ Add Event Block"
	add_event_btn.tooltip_text = "Add a new event block (lifecycle, collision, signal, timer, or UI button)"
	add_event_btn.pressed.connect(_on_add_event)
	_toolbar.add_child(add_event_btn)

	# Separator.
	var sep := HSeparator.new()
	add_child(sep)

	# -- No sheet label --
	_no_sheet_label = Label.new()
	_no_sheet_label.text = _NO_SHEET_TEXT
	_no_sheet_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_no_sheet_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_no_sheet_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_no_sheet_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(_no_sheet_label)

	# -- Scroll container for events --
	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(_scroll)

	_events_container = VBoxContainer.new()
	_events_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_events_container)


## Refresh the editor to reflect the current sheet state.
func _refresh() -> void:
	if not is_inside_tree():
		return

	var has_sheet: bool = _current_sheet != null

	_no_sheet_label.visible = not has_sheet
	_scroll.visible = has_sheet
	_toolbar.visible = has_sheet

	if not has_sheet:
		return

	_sheet_name_edit.text = _current_sheet.sheet_name

	# Clear existing event rows.
	for child in _events_container.get_children():
		child.queue_free()

	# Build event rows.
	if _current_sheet.events.size() == 0:
		var empty_label := Label.new()
		empty_label.text = (
			"No events yet. Click '+ Add Event Block' above to get started!\n"
			+ "Choose a callback function (lifecycle, collision, signal, timer) as the foundation of each block."
		)
		empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		empty_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		_events_container.add_child(empty_label)
	for i in range(_current_sheet.events.size()):
		var event := _current_sheet.events[i] as ESEventItem
		if event:
			var row := _create_event_row(event, i)
			_events_container.add_child(row)

	if Engine.is_editor_hint():
		_connect_rename_signals()
		_snapshot_node_paths()


## Create a visual row for a single event.
func _create_event_row(event: ESEventItem, index: int) -> PanelContainer:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.18, 0.20, 0.25, 1.0) if index % 2 == 0 else Color(0.15, 0.17, 0.22, 1.0)
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 6
	style.content_margin_bottom = 6

	# Detect callback condition type for visual styling.
	var callback_label := ""       # Shown as the function/callback subtitle.
	var callback_color := Color()  # Border + label tint color.
	var callback_icon := ""        # Category icon prefix.
	var is_callback_block := false # True when the block has a recognised callback condition.
	var lifecycle_type := -1       # Kept for backward compat checks; -1 = not lifecycle.

	for cond_res in event.conditions:
		if cond_res is ESLifecycleCondition:
			var lc := cond_res as ESLifecycleCondition
			lifecycle_type = lc.lifecycle_type
			is_callback_block = true
			callback_icon = "⏱"
			match lc.lifecycle_type:
				ESLifecycleCondition.LifecycleType.READY:
					callback_label = "func _ready():"
					callback_color = Color(1.0, 0.65, 0.1)   # orange
				ESLifecycleCondition.LifecycleType.PROCESS:
					callback_label = "func _process(delta):"
					callback_color = Color(0.2, 0.85, 0.4)   # green
				ESLifecycleCondition.LifecycleType.PHYSICS_PROCESS:
					callback_label = "func _physics_process(delta):"
					callback_color = Color(0.6, 0.3, 1.0)    # purple
			break
		elif cond_res is ESCollisionCondition:
			is_callback_block = true
			callback_icon = "💥"
			callback_color = Color(1.0, 0.35, 0.35)  # red
			callback_label = cond_res.get_summary()
			break
		elif cond_res is ESSignalCondition:
			is_callback_block = true
			callback_icon = "📡"
			callback_color = Color(1.0, 0.85, 0.3)   # yellow
			callback_label = cond_res.get_summary()
			break
		elif cond_res is ESTimerCondition:
			is_callback_block = true
			callback_icon = "⏲"
			callback_color = Color(0.3, 0.85, 0.9)   # cyan
			callback_label = cond_res.get_summary()
			break
		elif cond_res is ESButtonCondition:
			is_callback_block = true
			callback_icon = "🎮"
			callback_color = Color(0.9, 0.5, 0.9)    # pink
			callback_label = cond_res.get_summary()
			break

	# Apply a coloured left border based on callback type; fall back to blue for
	# non-callback blocks so old-style events still look reasonable.
	style.border_width_left = 4
	if is_callback_block:
		style.border_color = callback_color
	elif event.is_block:
		style.border_color = Color(0.3, 0.6, 1.0)    # blue fallback for old blocks

	panel.add_theme_stylebox_override("panel", style)

	var main_vbox := VBoxContainer.new()
	panel.add_child(main_vbox)

	# -- Event header --
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	main_vbox.add_child(header)

	# Enable checkbox.
	var enabled_check := CheckBox.new()
	enabled_check.button_pressed = event.enabled
	enabled_check.tooltip_text = "Enable/Disable this event"
	enabled_check.toggled.connect(func(toggled: bool):
		event.enabled = toggled
		_mark_resource_modified()
	)
	header.add_child(enabled_check)

	# Callback subtitle (shown when a callback condition is present on the block).
	if is_callback_block:
		var func_label := Label.new()
		func_label.text = "%s %s" % [callback_icon, callback_label]
		func_label.add_theme_font_size_override("font_size", 13)
		func_label.add_theme_color_override("font_color", callback_color)
		header.add_child(func_label)

	# Event name.
	var name_edit := LineEdit.new()
	name_edit.text = event.event_name
	name_edit.placeholder_text = "Event Name"
	name_edit.custom_minimum_size.x = 200
	name_edit.text_submitted.connect(func(new_text: String):
		event.event_name = new_text
		_mark_resource_modified()
	)
	header.add_child(name_edit)

	# Spacer.
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)

	# Move up button.
	var move_up_btn := Button.new()
	move_up_btn.text = "▲"
	move_up_btn.tooltip_text = "Move event up"
	move_up_btn.disabled = index == 0
	move_up_btn.pressed.connect(func():
		_current_sheet.move_event(index, index - 1)
		_refresh()
	)
	header.add_child(move_up_btn)

	# Move down button.
	var move_down_btn := Button.new()
	move_down_btn.text = "▼"
	move_down_btn.tooltip_text = "Move event down"
	move_down_btn.disabled = index >= _current_sheet.events.size() - 1
	move_down_btn.pressed.connect(func():
		_current_sheet.move_event(index, index + 1)
		_refresh()
	)
	header.add_child(move_down_btn)

	# Collapse toggle button.
	var collapse_btn := Button.new()
	if event.collapsed:
		collapse_btn.text = "▶"
		collapse_btn.tooltip_text = "Expand this event"
	else:
		collapse_btn.text = "▼"
		collapse_btn.tooltip_text = "Collapse this event"
	collapse_btn.pressed.connect(func():
		event.collapsed = not event.collapsed
		_mark_resource_modified()
		_refresh()
	)
	header.add_child(collapse_btn)

	# Block toggle button — hidden for callback-based events (they are always blocks).
	if not is_callback_block:
		var block_btn := Button.new()
		if event.is_block:
			block_btn.text = "⬛ Unblock"
			block_btn.tooltip_text = "Remove block/container mode"
		else:
			block_btn.text = "⬡ Block"
			block_btn.tooltip_text = "Make this event a block/container with sub-events"
		block_btn.pressed.connect(func():
			event.is_block = not event.is_block
			_mark_resource_modified()
			_refresh()
		)
		header.add_child(block_btn)

	# Delete button.
	var delete_btn := Button.new()
	delete_btn.text = "✕"
	delete_btn.tooltip_text = "Delete this event"
	delete_btn.pressed.connect(func():
		_current_sheet.remove_event(index)
		_refresh()
	)
	header.add_child(delete_btn)

	# -- Collapsed summary line (shown instead of body when collapsed) --
	if event.collapsed:
		var cond_count := event.conditions.size()
		var action_count := event.actions.size()
		var summary_parts := []
		if cond_count > 0:
			summary_parts.append("%d condition%s" % [cond_count, "s" if cond_count != 1 else ""])
		if action_count > 0:
			summary_parts.append("%d action%s" % [action_count, "s" if action_count != 1 else ""])
		if event.is_block and event.sub_events.size() > 0:
			var sc := event.sub_events.size()
			summary_parts.append("%d sub-event%s" % [sc, "s" if sc != 1 else ""])
		var summary_label := Label.new()
		summary_label.text = "  (%s)" % (", ".join(summary_parts) if summary_parts.size() > 0 else "empty")
		summary_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		main_vbox.add_child(summary_label)
		return panel

	# -- Conditions & Actions columns --
	# For callback-based events the condition is decorative (driven by Godot
	# callbacks), so we show a compact read-only chip instead of the full
	# conditions column.
	if is_callback_block:
		# Show a slim read-only callback chip instead of the full condition editor.
		var cb_bar := HBoxContainer.new()
		cb_bar.add_theme_constant_override("separation", 6)
		main_vbox.add_child(cb_bar)
		var cb_icon := Label.new()
		cb_icon.text = "%s Callback: " % callback_icon
		cb_icon.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		cb_bar.add_child(cb_icon)
		var cb_val := Label.new()
		cb_val.text = callback_label
		cb_val.add_theme_color_override("font_color", callback_color)
		cb_bar.add_child(cb_val)
	else:
		# Non-callback event: show full condition/action columns (backward compat).
		var columns := HBoxContainer.new()
		columns.add_theme_constant_override("separation", 12)
		main_vbox.add_child(columns)

		var cond_column := _create_conditions_column(event, index)
		cond_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		columns.add_child(cond_column)

		var vsep := VSeparator.new()
		columns.add_child(vsep)

		var action_column := _create_actions_column(event, index)
		action_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		columns.add_child(action_column)

	# -- Sub-events section (only visible when is_block) --
	if event.is_block:
		var sub_sep := HSeparator.new()
		main_vbox.add_child(sub_sep)

		var sub_margin := MarginContainer.new()
		sub_margin.add_theme_constant_override("margin_left", 24)
		main_vbox.add_child(sub_margin)

		var sub_vbox := VBoxContainer.new()
		sub_vbox.add_theme_constant_override("separation", 4)
		sub_margin.add_child(sub_vbox)

		for i in range(event.sub_events.size()):
			var sub_event := event.sub_events[i] as ESEventItem
			if sub_event:
				var sub_row := _create_sub_event_row(sub_event, event, i)
				sub_vbox.add_child(sub_row)

		# Add Sub-Event button.
		var add_sub_btn := Button.new()
		add_sub_btn.text = "↳ + Add Sub-Event"
		add_sub_btn.tooltip_text = "Add a sub-event with conditions and actions inside this event block"
		add_sub_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		add_sub_btn.pressed.connect(func(): _on_add_sub_event(event))
		sub_vbox.add_child(add_sub_btn)

	return panel


## Create a visual row for a sub-event inside a block.
func _create_sub_event_row(sub_event: ESEventItem, parent_event: ESEventItem, sub_index: int) -> PanelContainer:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.20, 0.22, 0.28, 1.0)
	style.corner_radius_top_left = 3
	style.corner_radius_top_right = 3
	style.corner_radius_bottom_left = 3
	style.corner_radius_bottom_right = 3
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 5
	style.content_margin_bottom = 5
	panel.add_theme_stylebox_override("panel", style)

	var main_vbox := VBoxContainer.new()
	panel.add_child(main_vbox)

	# -- Sub-event header --
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	main_vbox.add_child(header)

	# Hierarchy prefix.
	var prefix := Label.new()
	prefix.text = "↳"
	prefix.add_theme_color_override("font_color", Color(0.5, 0.7, 1.0))
	header.add_child(prefix)

	# Enable checkbox.
	var enabled_check := CheckBox.new()
	enabled_check.button_pressed = sub_event.enabled
	enabled_check.tooltip_text = "Enable/Disable this sub-event"
	enabled_check.toggled.connect(func(toggled: bool):
		sub_event.enabled = toggled
		_mark_resource_modified()
	)
	header.add_child(enabled_check)

	# Sub-event name.
	var name_edit := LineEdit.new()
	name_edit.text = sub_event.event_name
	name_edit.placeholder_text = "Sub-Event Name"
	name_edit.custom_minimum_size.x = 150
	name_edit.text_submitted.connect(func(new_text: String):
		sub_event.event_name = new_text
		_mark_resource_modified()
	)
	header.add_child(name_edit)

	# Spacer.
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)

	# Delete button.
	var delete_btn := Button.new()
	delete_btn.text = "✕"
	delete_btn.tooltip_text = "Delete this sub-event"
	delete_btn.pressed.connect(func():
		parent_event.remove_sub_event(sub_index)
		_mark_resource_modified()
		_refresh()
	)
	header.add_child(delete_btn)

	# -- Conditions & Actions columns --
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 12)
	main_vbox.add_child(columns)

	# Conditions column. Pass -1 as event_index: the parameter is unused inside
	# _create_conditions_column and _create_actions_column (it is only present for
	# future extensibility), so -1 is safe for sub-event rows.
	var cond_column := _create_conditions_column(sub_event, -1)
	cond_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.add_child(cond_column)

	# Vertical separator.
	var vsep := VSeparator.new()
	columns.add_child(vsep)

	# Actions column.
	var action_column := _create_actions_column(sub_event, -1)
	action_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.add_child(action_column)

	return panel


## Create the conditions column for an event.
func _create_conditions_column(event: ESEventItem, event_index: int) -> VBoxContainer:
	var vbox := VBoxContainer.new()

	# Header.
	var header := HBoxContainer.new()
	vbox.add_child(header)

	var label := Label.new()
	var logic_text := "ALL" if event.logic_mode == ESEventItem.LogicMode.AND else "ANY"
	label.text = "📋 Conditions (%s must be true)" % logic_text
	label.add_theme_font_size_override("font_size", 13)
	header.add_child(label)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)

	# AND/OR toggle button.
	var logic_btn := Button.new()
	logic_btn.text = "AND" if event.logic_mode == ESEventItem.LogicMode.AND else "OR"
	logic_btn.tooltip_text = "Toggle between AND (all true) and OR (any true) logic"
	logic_btn.pressed.connect(func():
		if event.logic_mode == ESEventItem.LogicMode.AND:
			event.logic_mode = ESEventItem.LogicMode.OR
		else:
			event.logic_mode = ESEventItem.LogicMode.AND
		_mark_resource_modified()
		_refresh()
	)
	header.add_child(logic_btn)

	var add_btn := Button.new()
	add_btn.text = "+ Condition"
	add_btn.pressed.connect(func(): _show_condition_dialog(event))
	header.add_child(add_btn)

	# List conditions.
	for i in range(event.conditions.size()):
		var cond := event.conditions[i] as ESCondition
		if cond:
			var row := _create_condition_row(cond, event, i)
			vbox.add_child(row)

	if event.conditions.size() == 0:
		var empty := Label.new()
		empty.text = "  (no conditions - click + to add)"
		empty.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		vbox.add_child(empty)

	return vbox


## Create a row for a single condition.
func _create_condition_row(cond: ESCondition, event: ESEventItem, cond_index: int) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)

	# Condition icon/type.
	var type_label := Label.new()
	type_label.text = "  ▸ "
	row.add_child(type_label)

	# Summary.
	var summary := Label.new()
	if cond.get_script() and cond.get_script().is_tool():
		var prefix := "NOT " if cond.negated else ""
		summary.text = prefix + cond.get_summary()
		if _has_stale_node_path(cond):
			summary.text += " ⚠"
			summary.add_theme_color_override("font_color", Color(1.0, 0.7, 0.2))
			summary.tooltip_text = "⚠ One or more node paths could not be found. The node may have been renamed or deleted. Open this condition to update the path."
	else:
		summary.text = "(unable to load condition)"
		summary.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4))
	summary.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	summary.clip_text = true
	row.add_child(summary)

	# Edit button.
	var edit_btn := Button.new()
	edit_btn.text = "✎"
	edit_btn.tooltip_text = "Edit condition"
	edit_btn.pressed.connect(func(): _show_condition_edit_dialog(cond, event, cond_index))
	row.add_child(edit_btn)

	# Delete button.
	var del_btn := Button.new()
	del_btn.text = "✕"
	del_btn.tooltip_text = "Remove condition"
	del_btn.pressed.connect(func():
		event.remove_condition(cond_index)
		_refresh()
	)
	row.add_child(del_btn)

	return row


## Create the actions column for an event.
func _create_actions_column(event: ESEventItem, event_index: int) -> VBoxContainer:
	var vbox := VBoxContainer.new()

	# Header.
	var header := HBoxContainer.new()
	vbox.add_child(header)

	var label := Label.new()
	label.text = "⚡ Actions (executed in order)"
	label.add_theme_font_size_override("font_size", 13)
	header.add_child(label)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)

	var add_btn := Button.new()
	add_btn.text = "+ Action"
	add_btn.pressed.connect(func(): _show_action_dialog(event))
	header.add_child(add_btn)

	# List actions.
	for i in range(event.actions.size()):
		var action := event.actions[i] as ESAction
		if action:
			var row := _create_action_row(action, event, i)
			vbox.add_child(row)

	if event.actions.size() == 0:
		var empty := Label.new()
		empty.text = "  (no actions - click + to add)"
		empty.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		vbox.add_child(empty)

	return vbox


## Create a row for a single action.
func _create_action_row(action: ESAction, event: ESEventItem, action_index: int) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)

	# Action icon.
	var type_label := Label.new()
	type_label.text = "  ▸ "
	row.add_child(type_label)

	# Summary.
	var summary := Label.new()
	if action.get_script() and action.get_script().is_tool():
		summary.text = action.get_summary()
		if _has_stale_node_path(action):
			summary.text += " ⚠"
			summary.add_theme_color_override("font_color", Color(1.0, 0.7, 0.2))
			summary.tooltip_text = "⚠ One or more node paths could not be found. The node may have been renamed or deleted. Open this action to update the path."
	else:
		summary.text = "(unable to load action)"
		summary.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4))
	summary.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	summary.clip_text = true
	row.add_child(summary)

	# Edit button.
	var edit_btn := Button.new()
	edit_btn.text = "✎"
	edit_btn.tooltip_text = "Edit action"
	edit_btn.pressed.connect(func(): _show_action_edit_dialog(action, event, action_index))
	row.add_child(edit_btn)

	# Delete button.
	var del_btn := Button.new()
	del_btn.text = "✕"
	del_btn.tooltip_text = "Remove action"
	del_btn.pressed.connect(func():
		event.remove_action(action_index)
		_refresh()
	)
	row.add_child(del_btn)

	return row


# -- Event Management --

## Notify the Godot editor that the resource has been modified and needs saving.
func _mark_resource_modified() -> void:
	if _current_sheet:
		_current_sheet.emit_changed()
		_save_sheet()
		if editor_interface:
			editor_interface.mark_scene_as_unsaved()


## Persist the event sheet to an external .tres file.
## This ensures the sheet survives across editor sessions, even if script
## compilation fails temporarily (the .tres text file remains on disk).
func _save_sheet() -> void:
	if not _current_sheet or not _current_controller:
		return

	# Generate a resource path if the sheet doesn't have one yet.
	if _current_sheet.resource_path.is_empty():
		var dir_path := "res://event_sheets"
		if not DirAccess.dir_exists_absolute(dir_path):
			DirAccess.make_dir_recursive_absolute(dir_path)

		var safe_name := _current_controller.name.to_lower().replace(" ", "_")
		# Prefix with the scene file name for uniqueness (if available).
		if _current_controller.owner:
			var scene_path: String = _current_controller.owner.scene_file_path
			if not scene_path.is_empty():
				var scene_name := scene_path.get_file().get_basename().to_lower()
				safe_name = scene_name + "_" + safe_name

		var path := dir_path.path_join(safe_name + "_events.tres")
		_current_sheet.resource_path = path

	var err := ResourceSaver.save(_current_sheet)
	if err != OK:
		push_warning("EventSheet: Failed to save event sheet to '%s': %s" % [
			_current_sheet.resource_path, error_string(err)])
	elif _current_controller.get_meta("_es_last_save_path", "") != _current_sheet.resource_path:
		_current_controller.set_meta("_es_last_save_path", _current_sheet.resource_path)
		print("EventSheet: Saved event sheet to %s" % _current_sheet.resource_path)


func _on_add_event() -> void:
	if not _current_sheet:
		return

	var dialog := AddLifecycleDialog.create(_current_controller)
	add_child(dialog)
	dialog.popup_centered(Vector2i(620, 420))
	dialog.confirmed.connect(func():
		var key: String = dialog.get_selected_key()
		if key.is_empty():
			return
		# Use the condition created by the dialog (already configured with properties).
		var cond: ESCondition = dialog.get_selected_condition()
		if cond == null:
			return
		var event := _current_sheet.add_event() as ESEventItem
		# Default name based on callback type.
		match key:
			"lifecycle_ready":
				event.event_name = "On Start of Scene"
			"lifecycle_process":
				event.event_name = "Every Frame"
			"lifecycle_physics":
				event.event_name = "Every Physics Step"
			"collision_body_entered":
				event.event_name = "On Body Entered"
			"collision_body_exited":
				event.event_name = "On Body Exited"
			"collision_area_entered":
				event.event_name = "On Area Entered"
			"collision_area_exited":
				event.event_name = "On Area Exited"
			"collision_is_overlapping":
				event.event_name = "While Overlapping"
			"signal_received":
				event.event_name = "On Signal Received"
			"timer_repeat":
				event.event_name = "Timer (repeating)"
			"timer_oneshot":
				event.event_name = "Timer (once)"
			"ui_button_pressed":
				event.event_name = "On Button Pressed"
			_:
				event.event_name = "Event Block"
		event.is_block = true
		event.add_condition(cond)
		_mark_resource_modified()
		_refresh()
	)


func _on_add_sub_event(parent_event: ESEventItem) -> void:
	var dialog := AddEventDialog.create(_current_controller, true)
	add_child(dialog)
	dialog.popup_centered(Vector2i(800, 600))
	dialog.confirmed.connect(func():
		var sub_event := ESEventItem.new()
		sub_event.event_name = "Sub-Event %d" % (parent_event.sub_events.size() + 1)
		var cond: ESCondition = dialog.get_selected_condition()
		var action: ESAction = dialog.get_selected_action()
		if cond:
			sub_event.add_condition(cond)
		if action:
			sub_event.add_action(action)
		parent_event.add_sub_event(sub_event)
		_mark_resource_modified()
		_refresh()
	)


func _on_sheet_name_changed(new_name: String) -> void:
	if _current_sheet:
		_current_sheet.sheet_name = new_name
		_mark_resource_modified()


# -- Condition Dialogs --

func _show_condition_dialog(event: ESEventItem) -> void:
	var dialog := ConditionDialog.create_picker(_current_controller)
	add_child(dialog)
	dialog.popup_centered(Vector2i(750, 500))
	dialog.confirmed.connect(func():
		var cond: ESCondition = dialog.get_selected_condition()
		if cond:
			event.add_condition(cond)
			_mark_resource_modified()
			_refresh()
	)


func _show_condition_edit_dialog(cond: ESCondition, event: ESEventItem, index: int) -> void:
	var dialog := ConditionDialog.create_editor(cond, _current_controller)
	add_child(dialog)
	dialog.popup_centered(Vector2i(750, 500))
	dialog.confirmed.connect(func():
		_mark_resource_modified()
		_refresh()
	)


# -- Action Dialogs --

func _show_action_dialog(event: ESEventItem) -> void:
	var dialog := ActionDialog.create_picker(_current_controller)
	add_child(dialog)
	dialog.popup_centered(Vector2i(750, 500))
	dialog.confirmed.connect(func():
		var action: ESAction = dialog.get_selected_action()
		if action:
			event.add_action(action)
			_mark_resource_modified()
			_refresh()
	)


func _show_action_edit_dialog(action: ESAction, event: ESEventItem, index: int) -> void:
	var dialog := ActionDialog.create_editor(action, _current_controller)
	add_child(dialog)
	dialog.popup_centered(Vector2i(750, 500))
	dialog.confirmed.connect(func():
		_mark_resource_modified()
		_refresh()
	)


# -- Stale Node Path Warning --

## Returns true if any NodePath-typed property on the given resource points
## to a node that cannot be found via _current_controller.
func _has_stale_node_path(resource: Resource) -> bool:
	if not _current_controller or not is_instance_valid(_current_controller):
		return false
	for prop in resource.get_property_list():
		if prop["type"] == TYPE_NODE_PATH:
			var path: NodePath = resource.get(prop["name"])
			if path.is_empty():
				continue
			var path_str := str(path)
			if path_str == _RUNTIME_SYNTHETIC_PATH:
				continue
			var node = _current_controller.get_node_or_null(path)
			if node == null and _current_controller.get_parent():
				node = _current_controller.get_parent().get_node_or_null(path)
			if node == null:
				return true
	return false


# -- Rename Tracking (editor-only) --

func _connect_rename_signals() -> void:
	_disconnect_rename_signals()
	if not _current_controller or not is_instance_valid(_current_controller):
		return
	var scene_root: Node = _current_controller.owner if _current_controller.owner else _current_controller.get_parent()
	if not scene_root:
		return
	_walk_and_connect(scene_root)


func _walk_and_connect(node: Node) -> void:
	if not node.renamed.is_connected(_on_scene_node_renamed):
		node.renamed.connect(_on_scene_node_renamed.bind(node))
		_rename_connected_nodes.append(node)
	for child in node.get_children():
		_walk_and_connect(child)


func _disconnect_rename_signals() -> void:
	for node in _rename_connected_nodes:
		if is_instance_valid(node) and node.renamed.is_connected(_on_scene_node_renamed.bind(node)):
			node.renamed.disconnect(_on_scene_node_renamed.bind(node))
	_rename_connected_nodes.clear()


func _snapshot_node_paths() -> void:
	_node_path_snapshot.clear()
	if not _current_controller or not is_instance_valid(_current_controller):
		return
	var scene_root: Node = _current_controller.owner if _current_controller.owner else _current_controller.get_parent()
	if not scene_root:
		return
	_snapshot_walk(scene_root)


func _snapshot_walk(node: Node) -> void:
	if not is_instance_valid(_current_controller):
		return
	var path_to_node: NodePath = _current_controller.get_path_to(node)
	_node_path_snapshot[node.get_instance_id()] = str(path_to_node)
	for child in node.get_children():
		_snapshot_walk(child)


func _on_scene_node_renamed(node: Node) -> void:
	if not _current_sheet or not _current_controller:
		return
	var instance_id := node.get_instance_id()
	if not _node_path_snapshot.has(instance_id):
		return
	var old_path: String = _node_path_snapshot[instance_id]
	var new_path: String = str(_current_controller.get_path_to(node))
	if old_path == new_path:
		return

	var changed := false
	for event_res in _current_sheet.events:
		var event := event_res as ESEventItem
		if event:
			changed = _migrate_paths_in_event(event, old_path, new_path) or changed

	if changed:
		_mark_resource_modified()
		_refresh()

	# Re-snapshot after rename.
	_snapshot_node_paths()


func _migrate_paths_in_event(event: ESEventItem, old_path: String, new_path: String) -> bool:
	var changed := false
	for cond in event.conditions:
		if _migrate_node_paths(cond, old_path, new_path):
			changed = true
	for action in event.actions:
		if _migrate_node_paths(action, old_path, new_path):
			changed = true
	for sub_res in event.sub_events:
		var sub := sub_res as ESEventItem
		if sub and _migrate_paths_in_event(sub, old_path, new_path):
			changed = true
	return changed


func _migrate_node_paths(resource: Resource, old_path: String, new_path: String) -> bool:
	var changed := false
	for prop in resource.get_property_list():
		if prop["type"] == TYPE_NODE_PATH:
			var current: NodePath = resource.get(prop["name"])
			if str(current) == old_path:
				resource.set(prop["name"], NodePath(new_path))
				changed = true
	return changed
