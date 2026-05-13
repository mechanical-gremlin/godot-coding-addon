@tool
class_name ESEventSheetGraphConverter
extends RefCounted
## Converts legacy EventSheet resources to VisualGraph resources.


const ESVisualGraph := preload("res://addons/godot_event_sheet/graph/visual_graph.gd")
const ESGraphNode := preload("res://addons/godot_event_sheet/graph/graph_node.gd")


static func convert_event_sheet(sheet: ESEventSheet) -> ESVisualGraph:
var graph := ESVisualGraph.new()
if not sheet:
graph.graph_name = "Converted Graph"
return graph

graph.graph_name = "%s (Converted)" % sheet.sheet_name

var y := 80.0
for event_res in sheet.events:
var event := event_res as ESEventItem
if not event:
continue
y = _convert_event_into_graph(event, graph, y, "")
y += 120.0
return graph


static func _convert_event_into_graph(event: ESEventItem, graph: ESVisualGraph, y: float, prefix: String) -> float:
var base_name := event.event_name if not event.event_name.is_empty() else "Event"
var trigger := ESGraphNode.new()
trigger.role = ESGraphNode.NodeRole.TRIGGER
trigger.node_name = "%s%s" % [prefix, base_name]
trigger.position = Vector2(80, y)
trigger.enabled = event.enabled
trigger.condition_logic = ESGraphNode.ConditionLogic.OR if event.logic_mode == ESEventItem.LogicMode.OR else ESGraphNode.ConditionLogic.AND
for cond_res in event.conditions:
trigger.conditions.append(cond_res.duplicate(true))
graph.add_node(trigger)

var previous_id := trigger.node_id
var action_y := y
for action_res in event.actions:
var act := action_res as ESAction
if not act:
continue
var node := ESGraphNode.new()
node.role = ESGraphNode.NodeRole.ACTION
node.node_name = act.get_summary()
node.position = Vector2(440, action_y)
node.action = act.duplicate(true)
graph.add_node(node)
graph.add_connection(previous_id, node.node_id)
previous_id = node.node_id
action_y += 80.0

# Flatten sub-events by converting them as their own trigger/action chains.
var next_y := max(y + 100.0, action_y)
for sub_res in event.sub_events:
var sub_event := sub_res as ESEventItem
if not sub_event:
continue
next_y = _convert_event_into_graph(sub_event, graph, next_y, "%s ↳ " % base_name)
next_y += 80.0

return next_y
