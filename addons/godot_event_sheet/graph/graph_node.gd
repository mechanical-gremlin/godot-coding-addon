@tool
class_name ESGraphNode
extends Resource
## A node in the visual scripting graph.


enum NodeRole {
TRIGGER,
LOGIC,
ACTION,
DATA,
SCENE_REFERENCE,
}


enum ConditionLogic {
AND,
OR,
}


@export var node_id: String = ""
@export var node_name: String = "Node"
@export var role: NodeRole = NodeRole.ACTION
@export var position: Vector2 = Vector2.ZERO
@export var enabled: bool = true

# Trigger nodes.
@export var conditions: Array[Resource] = []  # Array[ESCondition]
@export var condition_logic: ConditionLogic = ConditionLogic.AND

# Action nodes.
@export var action: Resource = null  # ESAction

# Logic/Data helper fields.
@export var bool_value: bool = true
@export var data_key: String = ""
@export var data_value: Variant = null

# Scene reference helper field.
@export var scene_node_path: NodePath = NodePath("")


func get_display_title() -> String:
if node_name.is_empty():
return "Node"
return node_name


func get_role_name() -> String:
match role:
NodeRole.TRIGGER:
return "Trigger"
NodeRole.LOGIC:
return "Logic"
NodeRole.ACTION:
return "Action"
NodeRole.DATA:
return "Data"
NodeRole.SCENE_REFERENCE:
return "Scene Ref"
return "Node"


func get_summary() -> String:
match role:
NodeRole.TRIGGER:
if conditions.is_empty():
return "When always"
var summaries: PackedStringArray = PackedStringArray()
for cond_res in conditions:
var cond := cond_res as ESCondition
if cond:
summaries.append(cond.get_summary())
var joiner := " AND " if condition_logic == ConditionLogic.AND else " OR "
return "When " + joiner.join(summaries)
NodeRole.ACTION:
var act := action as ESAction
return act.get_summary() if act else "Do action"
NodeRole.LOGIC:
return "Pass if " + ("True" if bool_value else "False")
NodeRole.DATA:
return "Set %s = %s" % [data_key, str(data_value)]
NodeRole.SCENE_REFERENCE:
return "Scene node: %s" % str(scene_node_path)
return ""
