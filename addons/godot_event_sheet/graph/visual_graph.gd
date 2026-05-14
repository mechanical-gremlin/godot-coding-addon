@tool
class_name ESVisualGraph
extends Resource
## Main visual scripting graph resource.


const ESGraphNode := preload("res://addons/godot_event_sheet/graph/graph_node.gd")
const ESGraphConnection := preload("res://addons/godot_event_sheet/graph/graph_connection.gd")


@export var graph_name: String = "New Visual Graph"
@export var enabled: bool = true
@export var nodes: Array[Resource] = []  # Array[ESGraphNode]
@export var connections: Array[Resource] = []  # Array[ESGraphConnection]
@export var variables: Array[Resource] = []  # Array[ESGraphVariable]


func create_node(role: ESGraphNode.NodeRole, display_name: String, pos: Vector2 = Vector2.ZERO) -> ESGraphNode:
var node := ESGraphNode.new()
node.node_id = _generate_node_id(role)
node.node_name = display_name
node.role = role
node.position = pos
nodes.append(node)
emit_changed()
return node


func add_node(node: ESGraphNode) -> void:
if not node:
return
if node.node_id.is_empty():
node.node_id = _generate_node_id(node.role)
nodes.append(node)
emit_changed()


func remove_node(node_id: String) -> void:
for i in range(nodes.size() - 1, -1, -1):
var node := nodes[i] as ESGraphNode
if node and node.node_id == node_id:
nodes.remove_at(i)
for i in range(connections.size() - 1, -1, -1):
var c := connections[i] as ESGraphConnection
if c and (c.from_node_id == node_id or c.to_node_id == node_id):
connections.remove_at(i)
emit_changed()


func add_connection(from_node_id: String, to_node_id: String, from_port: String = "exec_out_0", to_port: String = "exec_in_0") -> void:
if from_node_id.is_empty() or to_node_id.is_empty() or from_node_id == to_node_id:
return
for c_res in connections:
var c_existing := c_res as ESGraphConnection
if c_existing and c_existing.from_node_id == from_node_id and c_existing.to_node_id == to_node_id and c_existing.from_port == from_port and c_existing.to_port == to_port:
return
var c := ESGraphConnection.new()
c.from_node_id = from_node_id
c.to_node_id = to_node_id
c.from_port = from_port
c.to_port = to_port
connections.append(c)
emit_changed()


func remove_connection(from_node_id: String, to_node_id: String, from_port: String = "exec_out_0", to_port: String = "exec_in_0") -> void:
	var removed := false
	for i in range(connections.size() - 1, -1, -1):
		var c := connections[i] as ESGraphConnection
		if c and c.from_node_id == from_node_id and c.to_node_id == to_node_id and c.from_port == from_port and c.to_port == to_port:
			connections.remove_at(i)
			removed = true
	if not removed:
		for i in range(connections.size() - 1, -1, -1):
			var c2 := connections[i] as ESGraphConnection
			if c2 and c2.from_node_id == from_node_id and c2.to_node_id == to_node_id:
				connections.remove_at(i)
	emit_changed()


func get_node_by_id(node_id: String) -> ESGraphNode:
for node_res in nodes:
var node := node_res as ESGraphNode
if node and node.node_id == node_id:
return node
return null


func get_outgoing(node_id: String) -> Array[ESGraphConnection]:
var result: Array[ESGraphConnection] = []
for c_res in connections:
var c := c_res as ESGraphConnection
if c and c.from_node_id == node_id:
result.append(c)
return result


func get_trigger_nodes() -> Array[ESGraphNode]:
var result: Array[ESGraphNode] = []
for node_res in nodes:
var node := node_res as ESGraphNode
if node and node.enabled and node.role == ESGraphNode.NodeRole.TRIGGER:
result.append(node)
return result


func _generate_node_id(role: int) -> String:
var role_name := "n"
match role:
ESGraphNode.NodeRole.TRIGGER:
role_name = "trigger"
ESGraphNode.NodeRole.LOGIC:
role_name = "logic"
ESGraphNode.NodeRole.ACTION:
role_name = "action"
ESGraphNode.NodeRole.DATA:
role_name = "data"
ESGraphNode.NodeRole.SCENE_REFERENCE:
role_name = "scene"
return "%s_%d_%d" % [role_name, Time.get_ticks_msec(), randi() % 100000]
