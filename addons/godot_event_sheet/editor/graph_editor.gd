@tool
extends VBoxContainer
## Graph-first editor panel with legacy Event Sheet compatibility.


const ESVisualGraph := preload("res://addons/godot_event_sheet/graph/visual_graph.gd")
const ESGraphNode := preload("res://addons/godot_event_sheet/graph/graph_node.gd")
const ESGraphConnection := preload("res://addons/godot_event_sheet/graph/graph_connection.gd")
const ESGraphTemplates := preload("res://addons/godot_event_sheet/graph/graph_templates.gd")
const ESEventSheetGraphConverter := preload("res://addons/godot_event_sheet/graph/graph_converter.gd")

const ConditionDialog := preload("res://addons/godot_event_sheet/editor/condition_dialog.gd")
const ActionDialog := preload("res://addons/godot_event_sheet/editor/action_dialog.gd")
const LegacyEventSheetEditor := preload("res://addons/godot_event_sheet/editor/legacy_event_sheet_editor.gd")


var editor_interface: EditorInterface = null
var undo_redo: EditorUndoRedoManager = null

var _current_controller: Node = null
var _current_graph: ESVisualGraph = null
var _selected_graph_node_id: String = ""

var _tabs: TabContainer
var _graph_name_edit: LineEdit
var _graph_edit: GraphEdit
var _node_details: VBoxContainer
var _template_picker: OptionButton
var _legacy_editor: Control


func _ready() -> void:
    _build_ui()
    _refresh_graph_ui()


func edit_controller(controller: Node) -> void:
    _current_controller = controller
    if controller and "visual_graph" in controller:
        _current_graph = controller.get("visual_graph") as ESVisualGraph
        if _current_graph == null:
            _current_graph = ESVisualGraph.new()
            _current_graph.graph_name = "%s Graph" % controller.name
            controller.set("visual_graph", _current_graph)
            _mark_resource_modified()
    else:
        _current_graph = null

    if _legacy_editor and _legacy_editor.has_method("edit_controller"):
        _legacy_editor.call("edit_controller", controller)

    _refresh_graph_ui()


func _build_ui() -> void:
    name = "GraphEditor"
    custom_minimum_size = Vector2(0, 320)

    _tabs = TabContainer.new()
    _tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
    add_child(_tabs)

    var graph_tab := VBoxContainer.new()
    graph_tab.name = "Visual Graph"
    _tabs.add_child(graph_tab)

    var toolbar := HBoxContainer.new()
    toolbar.add_theme_constant_override("separation", 8)
    graph_tab.add_child(toolbar)

    var title_label := Label.new()
    title_label.text = "Graph:"
    toolbar.add_child(title_label)

    _graph_name_edit = LineEdit.new()
    _graph_name_edit.placeholder_text = "Graph Name"
    _graph_name_edit.custom_minimum_size = Vector2(220, 0)
    _graph_name_edit.text_submitted.connect(_on_graph_name_submitted)
    toolbar.add_child(_graph_name_edit)

    var spacer := Control.new()
    spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    toolbar.add_child(spacer)

    var add_trigger := Button.new()
    add_trigger.text = "+ Trigger"
    add_trigger.pressed.connect(func(): _add_graph_node(ESGraphNode.NodeRole.TRIGGER))
    toolbar.add_child(add_trigger)

    var add_action := Button.new()
    add_action.text = "+ Action"
    add_action.pressed.connect(func(): _add_graph_node(ESGraphNode.NodeRole.ACTION))
    toolbar.add_child(add_action)

    var add_logic := Button.new()
    add_logic.text = "+ Logic"
    add_logic.pressed.connect(func(): _add_graph_node(ESGraphNode.NodeRole.LOGIC))
    toolbar.add_child(add_logic)

    var add_data := Button.new()
    add_data.text = "+ Data"
    add_data.pressed.connect(func(): _add_graph_node(ESGraphNode.NodeRole.DATA))
    toolbar.add_child(add_data)

    var add_scene_ref := Button.new()
    add_scene_ref.text = "+ Scene Ref"
    add_scene_ref.pressed.connect(func(): _add_graph_node(ESGraphNode.NodeRole.SCENE_REFERENCE))
    toolbar.add_child(add_scene_ref)

    var tools_row := HBoxContainer.new()
    tools_row.add_theme_constant_override("separation", 8)
    graph_tab.add_child(tools_row)

    _template_picker = OptionButton.new()
    _template_picker.add_item("Starter Template…", 0)
    _template_picker.add_item("Player Movement", 1)
    _template_picker.add_item("Enemy Chase", 2)
    _template_picker.add_item("Switch → Door", 3)
    _template_picker.add_item("Pickup Item", 4)
    tools_row.add_child(_template_picker)

    var apply_template := Button.new()
    apply_template.text = "Apply Template"
    apply_template.pressed.connect(_on_apply_template)
    tools_row.add_child(apply_template)

    var convert_btn := Button.new()
    convert_btn.text = "Convert Legacy Sheet"
    convert_btn.tooltip_text = "Create a graph from the assigned Event Sheet (one-way copy)."
    convert_btn.pressed.connect(_on_convert_legacy_sheet)
    tools_row.add_child(convert_btn)

    var split := HSplitContainer.new()
    split.size_flags_vertical = Control.SIZE_EXPAND_FILL
    graph_tab.add_child(split)

    _graph_edit = GraphEdit.new()
    _graph_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _graph_edit.size_flags_vertical = Control.SIZE_EXPAND_FILL
    _graph_edit.connection_request.connect(_on_connection_request)
    _graph_edit.disconnection_request.connect(_on_disconnection_request)
    if _graph_edit.has_signal("node_selected"):
        _graph_edit.node_selected.connect(_on_graph_node_selected)
    split.add_child(_graph_edit)

    _node_details = VBoxContainer.new()
    _node_details.custom_minimum_size = Vector2(300, 0)
    _node_details.size_flags_vertical = Control.SIZE_EXPAND_FILL
    split.add_child(_node_details)

    _legacy_editor = LegacyEventSheetEditor.new()
    _legacy_editor.set("editor_interface", editor_interface)
    _legacy_editor.set("undo_redo", undo_redo)
    _legacy_editor.name = "Legacy Event Sheet"
    _tabs.add_child(_legacy_editor)


func _refresh_graph_ui() -> void:
    if not is_inside_tree():
        return

    _graph_edit.clear_connections()
    for child in _graph_edit.get_children():
        child.queue_free()

    for child in _node_details.get_children():
        child.queue_free()

    if _current_graph == null:
        _graph_name_edit.text = ""
        var empty := Label.new()
        empty.text = "Select an EventController node to edit its Visual Graph."
        empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        _node_details.add_child(empty)
        return

    _graph_name_edit.text = _current_graph.graph_name

    for node_res in _current_graph.nodes:
        var node := node_res as ESGraphNode
        if not node:
            continue
        var graph_node := _create_graph_node_widget(node)
        _graph_edit.add_child(graph_node)

    for conn_res in _current_graph.connections:
        var conn := conn_res as ESGraphConnection
        if not conn:
            continue
        if _current_graph.get_node_by_id(conn.from_node_id) and _current_graph.get_node_by_id(conn.to_node_id):
            _graph_edit.connect_node(conn.from_node_id, 0, conn.to_node_id, 0)

    _build_selected_node_panel()


func _create_graph_node_widget(node: ESGraphNode) -> GraphNode:
    var widget := GraphNode.new()
    widget.name = node.node_id
    widget.title = "%s — %s" % [node.get_role_name(), node.get_display_title()]
    widget.position_offset = node.position
    widget.resizable = false
    widget.selectable = true

    var label := Label.new()
    label.text = node.get_summary()
    label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    label.custom_minimum_size = Vector2(220, 46)
    widget.add_child(label)

    var select_btn := Button.new()
    select_btn.text = "Select"
    select_btn.pressed.connect(func():
        _selected_graph_node_id = node.node_id
        _build_selected_node_panel()
    )
    widget.add_child(select_btn)

    var has_input := node.role != ESGraphNode.NodeRole.TRIGGER
    var has_output := true
    widget.set_slot(0, has_input, 0, Color.WHITE, has_output, 0, Color.WHITE)

    return widget


func _build_selected_node_panel() -> void:
    for child in _node_details.get_children():
        child.queue_free()

    var node := _get_selected_graph_node()
    if node == null:
        var label := Label.new()
        label.text = "Select a graph node to edit details."
        label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        _node_details.add_child(label)
        return

    var title := Label.new()
    title.text = "Selected: %s" % node.get_display_title()
    title.add_theme_font_size_override("font_size", 14)
    _node_details.add_child(title)

    var name_edit := LineEdit.new()
    name_edit.text = node.node_name
    name_edit.placeholder_text = "Node Name"
    name_edit.text_submitted.connect(func(new_text: String):
        node.node_name = new_text
        _mark_resource_modified()
        _refresh_graph_ui()
    )
    _node_details.add_child(name_edit)

    var summary := Label.new()
    summary.text = node.get_summary()
    summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    _node_details.add_child(summary)

    match node.role:
        ESGraphNode.NodeRole.TRIGGER:
            _build_trigger_controls(node)
        ESGraphNode.NodeRole.ACTION:
            _build_action_controls(node)
        ESGraphNode.NodeRole.DATA:
            _build_data_controls(node)
        ESGraphNode.NodeRole.LOGIC:
            _build_logic_controls(node)
        ESGraphNode.NodeRole.SCENE_REFERENCE:
            _build_scene_ref_controls(node)

    var delete_btn := Button.new()
    delete_btn.text = "Delete Node"
    delete_btn.pressed.connect(func():
        _current_graph.remove_node(node.node_id)
        _selected_graph_node_id = ""
        _mark_resource_modified()
        _refresh_graph_ui()
    )
    _node_details.add_child(delete_btn)


func _build_trigger_controls(node: ESGraphNode) -> void:
    var logic_btn := Button.new()
    logic_btn.text = "Logic: %s" % ("AND" if node.condition_logic == ESGraphNode.ConditionLogic.AND else "OR")
    logic_btn.pressed.connect(func():
        node.condition_logic = ESGraphNode.ConditionLogic.OR if node.condition_logic == ESGraphNode.ConditionLogic.AND else ESGraphNode.ConditionLogic.AND
        _mark_resource_modified()
        _build_selected_node_panel()
        _refresh_graph_ui()
    )
    _node_details.add_child(logic_btn)

    for idx in range(node.conditions.size()):
        var cond := node.conditions[idx] as ESCondition
        if not cond:
            continue
        var row := HBoxContainer.new()
        var label := Label.new()
        label.text = cond.get_summary()
        label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        row.add_child(label)

        var edit_btn := Button.new()
        edit_btn.text = "✎"
        edit_btn.pressed.connect(func():
            var dlg := ConditionDialog.create_editor(cond, _current_controller)
            add_child(dlg)
            dlg.confirmed.connect(func():
                _mark_resource_modified()
                _refresh_graph_ui()
                dlg.queue_free()
            )
            dlg.canceled.connect(func(): dlg.queue_free())
            dlg.popup_centered_ratio(0.75)
        )
        row.add_child(edit_btn)

        var del_btn := Button.new()
        del_btn.text = "✕"
        del_btn.pressed.connect(func():
            node.conditions.remove_at(idx)
            _mark_resource_modified()
            _refresh_graph_ui()
        )
        row.add_child(del_btn)
        _node_details.add_child(row)

    var add_btn := Button.new()
    add_btn.text = "+ Condition"
    add_btn.pressed.connect(func():
        var dlg := ConditionDialog.create_picker(_current_controller)
        add_child(dlg)
        dlg.confirmed.connect(func():
            var selected := dlg.get_selected_condition()
            if selected:
                node.conditions.append(selected)
                _mark_resource_modified()
                _refresh_graph_ui()
            dlg.queue_free()
        )
        dlg.canceled.connect(func(): dlg.queue_free())
        dlg.popup_centered_ratio(0.75)
    )
    _node_details.add_child(add_btn)


func _build_action_controls(node: ESGraphNode) -> void:
    var current := node.action as ESAction
    var label := Label.new()
    label.text = current.get_summary() if current else "No action assigned"
    label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    _node_details.add_child(label)

    var pick_btn := Button.new()
    pick_btn.text = "Choose Action"
    pick_btn.pressed.connect(func():
        var dlg := ActionDialog.create_picker(_current_controller)
        add_child(dlg)
        dlg.confirmed.connect(func():
            var selected := dlg.get_selected_action()
            if selected:
                node.action = selected
                _mark_resource_modified()
                _refresh_graph_ui()
            dlg.queue_free()
        )
        dlg.canceled.connect(func(): dlg.queue_free())
        dlg.popup_centered_ratio(0.75)
    )
    _node_details.add_child(pick_btn)

    if current:
        var edit_btn := Button.new()
        edit_btn.text = "Edit Action"
        edit_btn.pressed.connect(func():
            var dlg := ActionDialog.create_editor(current, _current_controller)
            add_child(dlg)
            dlg.confirmed.connect(func():
                _mark_resource_modified()
                _refresh_graph_ui()
                dlg.queue_free()
            )
            dlg.canceled.connect(func(): dlg.queue_free())
            dlg.popup_centered_ratio(0.75)
        )
        _node_details.add_child(edit_btn)


func _build_logic_controls(node: ESGraphNode) -> void:
    var check := CheckBox.new()
    check.text = "Pass Through"
    check.button_pressed = node.bool_value
    check.toggled.connect(func(v: bool):
        node.bool_value = v
        _mark_resource_modified()
        _refresh_graph_ui()
    )
    _node_details.add_child(check)


func _build_data_controls(node: ESGraphNode) -> void:
    var key_edit := LineEdit.new()
    key_edit.placeholder_text = "Variable Name"
    key_edit.text = node.data_key
    key_edit.text_submitted.connect(func(v: String):
        node.data_key = v
        _mark_resource_modified()
        _refresh_graph_ui()
    )
    _node_details.add_child(key_edit)

    var value_edit := LineEdit.new()
    value_edit.placeholder_text = "Value"
    value_edit.text = str(node.data_value)
    value_edit.text_submitted.connect(func(v: String):
        node.data_value = v
        _mark_resource_modified()
        _refresh_graph_ui()
    )
    _node_details.add_child(value_edit)


func _build_scene_ref_controls(node: ESGraphNode) -> void:
    var picker := OptionButton.new()
    picker.add_item("Select node path", 0)
    picker.set_item_metadata(0, NodePath(""))

    var selected_index := 0
    var idx := 1
    for path in _list_scene_paths():
        picker.add_item(path, idx)
        picker.set_item_metadata(idx, NodePath(path))
        if NodePath(path) == node.scene_node_path:
            selected_index = idx
        idx += 1
    picker.selected = selected_index
    picker.item_selected.connect(func(i: int):
        node.scene_node_path = picker.get_item_metadata(i)
        _mark_resource_modified()
        _refresh_graph_ui()
    )
    _node_details.add_child(picker)


func _list_scene_paths() -> PackedStringArray:
    var paths := PackedStringArray()
    if not _current_controller:
        return paths
    var root := _current_controller.get_parent()
    if not root:
        return paths
    _collect_paths_recursive(root, root, paths)
    return paths


func _collect_paths_recursive(root: Node, node: Node, out_paths: PackedStringArray) -> void:
    if node != root:
        out_paths.append(str(root.get_path_to(node)))
    for child in node.get_children():
        if child is Node:
            _collect_paths_recursive(root, child, out_paths)


func _add_graph_node(role: int) -> void:
    if not _current_graph:
        return
    var base_name := "Node"
    match role:
        ESGraphNode.NodeRole.TRIGGER:
            base_name = "Trigger"
        ESGraphNode.NodeRole.ACTION:
            base_name = "Action"
        ESGraphNode.NodeRole.LOGIC:
            base_name = "Logic"
        ESGraphNode.NodeRole.DATA:
            base_name = "Data"
        ESGraphNode.NodeRole.SCENE_REFERENCE:
            base_name = "Scene Ref"
    var node := _current_graph.create_node(role, "%s %d" % [base_name, _current_graph.nodes.size() + 1], Vector2(80 + (_current_graph.nodes.size() * 20), 80 + (_current_graph.nodes.size() * 16)))
    _selected_graph_node_id = node.node_id
    _mark_resource_modified()
    _refresh_graph_ui()


func _on_graph_name_submitted(new_name: String) -> void:
    if not _current_graph:
        return
    _current_graph.graph_name = new_name
    _mark_resource_modified()


func _on_connection_request(from_name: StringName, from_port: int, to_name: StringName, to_port: int) -> void:
    if not _current_graph:
        return
    _current_graph.add_connection(str(from_name), str(to_name), "exec_out_%d" % from_port, "exec_in_%d" % to_port)
    _mark_resource_modified()
    _refresh_graph_ui()


func _on_graph_node_selected(node_name: StringName) -> void:
    _selected_graph_node_id = str(node_name)
    _build_selected_node_panel()


func _on_disconnection_request(from_name: StringName, from_port: int, to_name: StringName, to_port: int) -> void:
    if not _current_graph:
        return
    _current_graph.remove_connection(str(from_name), str(to_name), "exec_out_%d" % from_port, "exec_in_%d" % to_port)
    _mark_resource_modified()
    _refresh_graph_ui()


func _on_apply_template() -> void:
    if not _current_controller:
        return
    var key := ""
    match _template_picker.selected:
        1:
            key = "player_movement"
        2:
            key = "enemy_chase"
        3:
            key = "switch_door"
        4:
            key = "pickup_item"
    if key.is_empty():
        return
    _current_graph = ESGraphTemplates.create_template(key)
    _current_controller.set("visual_graph", _current_graph)
    _mark_resource_modified()
    _refresh_graph_ui()


func _on_convert_legacy_sheet() -> void:
    if not _current_controller:
        return
    if not ("event_sheet" in _current_controller):
        return
    var sheet := _current_controller.get("event_sheet") as ESEventSheet
    if not sheet:
        return
    _current_graph = ESEventSheetGraphConverter.convert_event_sheet(sheet)
    _current_controller.set("visual_graph", _current_graph)
    _mark_resource_modified()
    _refresh_graph_ui()


func _get_selected_graph_node() -> ESGraphNode:
    if not _current_graph:
        return null
    if _selected_graph_node_id.is_empty():
        return null
    return _current_graph.get_node_by_id(_selected_graph_node_id)


func _mark_resource_modified() -> void:
    if _current_graph:
        _current_graph.emit_changed()
    if _current_controller:
        _current_controller.set("visual_graph", _current_graph)
