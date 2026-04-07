@tool
class_name ESStateCondition
extends ESCondition
## Condition that checks the current game state stored as metadata on a node.
## Pairs with the State action (state_action.gd) which sets states.
##
## Common patterns:
##   - Only allow player input when state is "player_turn".
##   - Trigger boss phase‑2 behavior when state is "phase_2".
##   - Show game-over UI when state is "game_over".
##   - Enable power-up effects only while state is "powered_up".

enum StateCompare {
	EQUAL,     ## State == value.
	NOT_EQUAL, ## State != value.
}

## Path to the node whose state to check.
## Leave empty for the EventController's parent node.
@export var node_path: NodePath = NodePath("")

## The metadata key used to store the state (must match the State action's
## state_name).
@export var state_name: String = "state"

## The comparison operator to use.
@export var compare_op: StateCompare = StateCompare.EQUAL

## The value to compare the current state against.
@export var compare_value: String = ""


func get_summary() -> String:
	var target := str(node_path) if not node_path.is_empty() else "parent"
	var op_str := "==" if compare_op == StateCompare.EQUAL else "!="
	return "State '%s' on %s %s \"%s\"" % [state_name, target, op_str, compare_value]


func get_category() -> String:
	return "State"


func evaluate(controller: Node, _delta: float) -> bool:
	var target := _resolve_target(controller)
	if not target:
		return false

	var meta_key := &"_es_state_%s" % state_name
	var current_value: String = ""
	if target.has_meta(meta_key):
		current_value = str(target.get_meta(meta_key))

	match compare_op:
		StateCompare.EQUAL:
			return current_value == compare_value
		StateCompare.NOT_EQUAL:
			return current_value != compare_value
	return false


func _resolve_target(controller: Node) -> Node:
	if node_path.is_empty():
		return controller.get_parent()
	var path_str := str(node_path)
	if path_str == "$collider":
		var meta_val = controller.get_meta(&"_es_last_collided_node", null)
		return meta_val if meta_val is Node else null
	var target := controller.get_node_or_null(node_path)
	if target:
		return target
	var parent := controller.get_parent()
	if parent:
		target = parent.get_node_or_null(node_path)
		if target:
			return target
	return null
