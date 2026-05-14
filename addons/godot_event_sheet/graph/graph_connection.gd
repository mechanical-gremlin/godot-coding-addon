@tool
class_name ESGraphConnection
extends Resource
## Directed edge between two graph nodes.


@export var from_node_id: String = ""
@export var from_port: String = "exec_out"

@export var to_node_id: String = ""
@export var to_port: String = "exec_in"
