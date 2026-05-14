@tool
class_name ESGraphTemplates
extends RefCounted
## Starter graph templates for classroom-friendly game object setups.


const ESVisualGraph := preload("res://addons/godot_event_sheet/graph/visual_graph.gd")
const ESGraphNode := preload("res://addons/godot_event_sheet/graph/graph_node.gd")

const ESInputCondition := preload("res://addons/godot_event_sheet/conditions/input_condition.gd")
const ESLifecycleCondition := preload("res://addons/godot_event_sheet/conditions/lifecycle_condition.gd")
const ESCollisionCondition := preload("res://addons/godot_event_sheet/conditions/collision_condition.gd")
const ESPropertyCondition := preload("res://addons/godot_event_sheet/conditions/property_condition.gd")

const ESMoveAction := preload("res://addons/godot_event_sheet/actions/move_action.gd")
const ESSetPropertyAction := preload("res://addons/godot_event_sheet/actions/set_property_action.gd")
const ESSceneAction := preload("res://addons/godot_event_sheet/actions/scene_action.gd")
const ESPrintAction := preload("res://addons/godot_event_sheet/actions/print_action.gd")
const ESStateAction := preload("res://addons/godot_event_sheet/actions/state_action.gd")


static func create_template(template_key: String) -> ESVisualGraph:
match template_key:
"player_movement":
return create_player_movement_template()
"enemy_chase":
return create_enemy_chase_template()
"switch_door":
return create_switch_door_template()
"pickup_item":
return create_pickup_item_template()
_:
return ESVisualGraph.new()


static func create_player_movement_template() -> ESVisualGraph:
var graph := ESVisualGraph.new()
graph.graph_name = "Starter: Player Movement"

var trigger := _make_process_input_trigger("ui_right")
trigger.node_name = "When Right Held"
trigger.position = Vector2(80, 80)
graph.add_node(trigger)

var move := _make_move_action_node(Vector2(1, 0), 220.0)
move.node_name = "Move Right"
move.position = Vector2(430, 80)
graph.add_node(move)

graph.add_connection(trigger.node_id, move.node_id)
return graph


static func create_enemy_chase_template() -> ESVisualGraph:
var graph := ESVisualGraph.new()
graph.graph_name = "Starter: Enemy Chase"

var trigger := ESGraphNode.new()
trigger.node_name = "When Every Frame"
trigger.role = ESGraphNode.NodeRole.TRIGGER
trigger.position = Vector2(80, 80)
trigger.node_id = "enemy_trigger"
var lifecycle := ESLifecycleCondition.new()
lifecycle.lifecycle_type = ESLifecycleCondition.LifecycleType.PROCESS
trigger.conditions.append(lifecycle)
graph.add_node(trigger)

var chase := ESGraphNode.new()
chase.node_name = "Chase Player"
chase.role = ESGraphNode.NodeRole.ACTION
chase.position = Vector2(420, 80)
chase.node_id = "enemy_chase_action"
var move := ESMoveAction.new()
move.move_type = ESMoveAction.MoveType.MOVE_TOWARD_NODE
move.toward_node_path = NodePath("/root/Main/Player")
move.speed = 180.0
chase.action = move
graph.add_node(chase)

graph.add_connection(trigger.node_id, chase.node_id)
return graph


static func create_switch_door_template() -> ESVisualGraph:
var graph := ESVisualGraph.new()
graph.graph_name = "Starter: Switch Opens Door"

var trigger := ESGraphNode.new()
trigger.node_name = "When Player Overlaps Switch"
trigger.role = ESGraphNode.NodeRole.TRIGGER
trigger.position = Vector2(80, 80)
trigger.node_id = "switch_trigger"
var collision := ESCollisionCondition.new()
collision.collision_type = ESCollisionCondition.CollisionType.IS_OVERLAPPING
collision.filter_group = "player"
trigger.conditions.append(collision)
graph.add_node(trigger)

var hide := ESGraphNode.new()
hide.node_name = "Hide Door"
hide.role = ESGraphNode.NodeRole.ACTION
hide.position = Vector2(430, 80)
hide.node_id = "door_hide"
var action := ESSceneAction.new()
action.operation = ESSceneAction.SceneOp.HIDE
action.destroy_target_path = NodePath("../Door")
hide.action = action
graph.add_node(hide)

graph.add_connection(trigger.node_id, hide.node_id)
return graph


static func create_pickup_item_template() -> ESVisualGraph:
var graph := ESVisualGraph.new()
graph.graph_name = "Starter: Pickup Item"

var trigger := ESGraphNode.new()
trigger.node_name = "When Player Touches Item"
trigger.role = ESGraphNode.NodeRole.TRIGGER
trigger.position = Vector2(80, 80)
trigger.node_id = "pickup_trigger"
var collision := ESCollisionCondition.new()
collision.collision_type = ESCollisionCondition.CollisionType.AREA_ENTERED
collision.filter_group = "player"
trigger.conditions.append(collision)
graph.add_node(trigger)

var add_score := ESGraphNode.new()
add_score.node_name = "Add Score"
add_score.role = ESGraphNode.NodeRole.ACTION
add_score.position = Vector2(420, 40)
add_score.node_id = "score_add"
var prop := ESSetPropertyAction.new()
prop.target_path = NodePath("/root/Main/ScoreManager")
prop.property_name = "score"
prop.value = 1
prop.set_mode = ESSetPropertyAction.SetMode.ADD
add_score.action = prop
graph.add_node(add_score)

var destroy := ESGraphNode.new()
destroy.node_name = "Remove Item"
destroy.role = ESGraphNode.NodeRole.ACTION
destroy.position = Vector2(420, 140)
destroy.node_id = "item_remove"
var destroy_action := ESSceneAction.new()
destroy_action.operation = ESSceneAction.SceneOp.DESTROY
destroy_action.destroy_target_path = NodePath("")
destroy.action = destroy_action
graph.add_node(destroy)

var print_node := ESGraphNode.new()
print_node.node_name = "Print Pickup"
print_node.role = ESGraphNode.NodeRole.ACTION
print_node.position = Vector2(760, 90)
print_node.node_id = "pickup_print"
var print_action := ESPrintAction.new()
print_action.message = "Item picked up!"
print_node.action = print_action
graph.add_node(print_node)

graph.add_connection(trigger.node_id, add_score.node_id)
graph.add_connection(trigger.node_id, destroy.node_id)
graph.add_connection(add_score.node_id, print_node.node_id)
return graph


static func _make_process_input_trigger(action_name: String) -> ESGraphNode:
var trigger := ESGraphNode.new()
trigger.role = ESGraphNode.NodeRole.TRIGGER
trigger.node_id = "trigger_%s" % action_name

var lifecycle := ESLifecycleCondition.new()
lifecycle.lifecycle_type = ESLifecycleCondition.LifecycleType.PROCESS
trigger.conditions.append(lifecycle)

var input := ESInputCondition.new()
input.input_type = ESInputCondition.InputType.IS_HELD
input.action_or_key = action_name
trigger.conditions.append(input)
return trigger


static func _make_move_action_node(direction: Vector2, speed: float) -> ESGraphNode:
var action_node := ESGraphNode.new()
action_node.role = ESGraphNode.NodeRole.ACTION
action_node.node_id = "move_%d_%d" % [int(direction.x), int(direction.y)]
var move := ESMoveAction.new()
move.move_type = ESMoveAction.MoveType.TRANSLATE
move.x = direction.x
move.y = direction.y
move.speed = speed
action_node.action = move
return action_node
